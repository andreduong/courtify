/**
 * Courtify Tennis Widget Worker
 *
 * Fetches live scores + ATP/WTA top-20 rankings from the Tennis API
 * (tennis-api-atp-wta-itf on RapidAPI), caches a lightweight payload in KV,
 * and serves it at GET /api/widget-data.
 */

const API_HOST = "tennis-api-atp-wta-itf.p.rapidapi.com";
const API_BASE = `https://${API_HOST}`;
const KV_KEY = "widget-data";
const KV_META_KEY = "widget-data-meta";
const CACHE_MAX_AGE_SECONDS = 3600; // 1 hour — clients read KV, not RapidAPI
const MIN_REFRESH_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours between RapidAPI refreshes
const REQUEST_DELAY_MS = 250;
const MAX_RETRIES = 1; // Retries multiply quota usage on BASIC plans

const ENDPOINTS = {
  // Equivalent to fixtures?live=all on this API
  liveEvents: "/tennis/v2/extend/api/events/live",
  atpRankings: "/tennis/v2/atp/ranking/singles?pageSize=20",
  wtaRankings: "/tennis/v2/wta/ranking/singles?pageSize=20",
  atpFixtures: "/tennis/v2/atp/fixtures?pageSize=100&filter=PlayerGroup:singles",
  wtaFixtures: "/tennis/v2/wta/fixtures?pageSize=100&filter=PlayerGroup:singles",
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method === "GET" && url.pathname === "/api/widget-data") {
      return serveWidgetData(env);
    }

    return jsonResponse({ error: "Not found" }, 404);
  },
};

async function serveWidgetData(env) {
  try {
    const cached = await env.TENNIS_DATA.get(KV_KEY);
    const stale = await isCacheStale(env, cached);

    if (!cached || stale) {
      console.log(`[api] ${cached ? "Stale cache" : "KV miss"} — refreshing on widget request`);
      await refreshWidgetData(env);
    }

    const data = await env.TENNIS_DATA.get(KV_KEY);
    if (!data) {
      return jsonResponse(
        {
          error: "Data not ready yet",
          message: "Could not load tennis data. Try again later.",
        },
        503,
        { "Retry-After": "3600" },
      );
    }

    console.log("[api] Serving widget data from KV");
    return new Response(normalizeCachedPayload(data), {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": `public, max-age=${CACHE_MAX_AGE_SECONDS}`,
      },
    });
  } catch (error) {
    console.error("[api] Failed to read KV:", error);
    return jsonResponse({ error: "Failed to read cached data" }, 500);
  }
}

/// Re-normalizes ranking points on the way out so payloads cached before a
/// parser fix (e.g. WTA points scaled x100) are corrected without an extra
/// RapidAPI refresh.
function normalizeCachedPayload(data) {
  try {
    const payload = JSON.parse(data);
    for (const tourKey of ["atp", "wta"]) {
      const entries = payload?.rankings?.[tourKey];
      if (!Array.isArray(entries)) continue;
      for (const entry of entries) {
        entry.points = normalizeRankingPoints(entry.points);
      }
    }
    return JSON.stringify(payload);
  } catch {
    return data;
  }
}

async function isCacheStale(env, cached) {
  if (!cached) return true;
  const metaRaw = await env.TENNIS_DATA.get(KV_META_KEY);
  if (!metaRaw) return true;
  try {
    const meta = JSON.parse(metaRaw);
    return Date.now() - (meta.lastRefresh ?? 0) >= MIN_REFRESH_INTERVAL_MS;
  } catch {
    return true;
  }
}

async function refreshWidgetData(env, { force = false } = {}) {
  if (!env.RAPID_API_KEY) {
    console.error("[cron] RAPID_API_KEY secret is not configured");
    return;
  }

  if (!force) {
    const metaRaw = await env.TENNIS_DATA.get(KV_META_KEY);
    if (metaRaw) {
      try {
        const meta = JSON.parse(metaRaw);
        const elapsed = Date.now() - (meta.lastRefresh ?? 0);
        if (elapsed < MIN_REFRESH_INTERVAL_MS) {
          console.log(`[cron] Skipping refresh — last run ${Math.round(elapsed / 60000)}m ago`);
          return;
        }
      } catch {
        // ignore corrupt meta
      }
    }
  }

  console.log("[cron] Starting tennis data refresh");

  try {
    // 3 RapidAPI calls per refresh (was 5–7 every 15 min — burned BASIC quota in hours)
    const [liveResult, atpRankingsResult, wtaRankingsResult, atpFixturesResult] = await fetchSequentially(env, [
      { label: "live-events", path: ENDPOINTS.liveEvents },
      { label: "atp-rankings", path: ENDPOINTS.atpRankings },
      { label: "wta-rankings", path: ENDPOINTS.wtaRankings },
      { label: "atp-fixtures", path: ENDPOINTS.atpFixtures },
    ]);

    let liveMatches = [];
    let upcomingMatches = [];

    if (liveResult.ok) {
      liveMatches = parseLiveEvents(liveResult.data);
      console.log(`[cron] Live events endpoint returned ${liveMatches.length} matches`);
    }

    if (atpFixturesResult.ok) {
      if (liveMatches.length === 0) {
        liveMatches = parseLiveFixtures(atpFixturesResult.data, "atp");
        console.log(`[cron] Fixtures fallback returned ${liveMatches.length} live matches`);
      }
      upcomingMatches = parseUpcomingFixtures(atpFixturesResult.data, "atp").slice(0, 20);
    } else {
      console.warn(`[cron] ATP fixtures failed: ${atpFixturesResult.status}`);
    }

    const payload = {
      updatedAt: new Date().toISOString(),
      liveMatches,
      upcomingMatches,
      rankings: {
        atp: atpRankingsResult.ok ? parseRankings(atpRankingsResult.data, "atp") : [],
        wta: wtaRankingsResult.ok ? parseRankings(wtaRankingsResult.data, "wta") : [],
      },
      meta: {
        sources: {
          live: liveResult.ok ? "events/live" : "fixtures-filter",
          atpRankings: atpRankingsResult.ok ? "ok" : `error:${atpRankingsResult.status}`,
          wtaRankings: wtaRankingsResult.ok ? "ok" : `error:${wtaRankingsResult.status}`,
          upcoming: upcomingMatches.length > 0 ? "ok" : "empty",
        },
      },
    };

    await env.TENNIS_DATA.put(KV_KEY, JSON.stringify(payload));
    await env.TENNIS_DATA.put(
      KV_META_KEY,
      JSON.stringify({ lastRefresh: Date.now(), apiCalls: 4 }),
    );
    console.log(
      `[cron] Cached widget data — ${liveMatches.length} live, ` +
        `${payload.rankings.atp.length} ATP rankings, ${upcomingMatches.length} upcoming`,
    );
  } catch (error) {
    console.error("[cron] Refresh failed:", error);
  }
}

async function fetchSequentially(env, requests) {
  const results = [];

  for (const req of requests) {
    const result = await fetchWithRetry(env, req.path, req.label);
    results.push(result);
    await sleep(REQUEST_DELAY_MS);
  }

  return results;
}

async function fetchWithRetry(env, path, label) {
  let attempt = 0;

  while (attempt < MAX_RETRIES) {
    attempt += 1;
    console.log(`[fetch] ${label} attempt ${attempt}: ${path}`);

    const response = await fetch(`${API_BASE}${path}`, {
      method: "GET",
      headers: buildHeaders(env.RAPID_API_KEY),
    });

    if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get("Retry-After") || "5", 10);
      const backoffMs = Math.max(retryAfter, attempt) * 1000;
      console.warn(`[fetch] ${label} rate limited (429) — waiting ${backoffMs}ms`);
      await sleep(backoffMs);
      continue;
    }

    if (response.status >= 500) {
      const backoffMs = attempt * 1500;
      console.warn(`[fetch] ${label} server error ${response.status} — retrying in ${backoffMs}ms`);
      await sleep(backoffMs);
      continue;
    }

    if (!response.ok) {
      const body = await response.text();
      console.error(`[fetch] ${label} failed ${response.status}: ${body.slice(0, 200)}`);
      return { ok: false, status: response.status, data: null };
    }

    const data = await response.json();
    console.log(`[fetch] ${label} success (${response.status})`);
    return { ok: true, status: response.status, data };
  }

  console.error(`[fetch] ${label} exhausted retries`);
  return { ok: false, status: 429, data: null };
}

function buildHeaders(apiKey) {
  return {
    "Content-Type": "application/json",
    "x-rapidapi-key": apiKey,
    "x-rapidapi-host": API_HOST,
  };
}

function playerImageUrl(tour, playerId) {
  if (!playerId) return null;
  const paddedId = String(playerId).padStart(5, "0");
  return `${API_BASE}/tennis/v2/ms-api/uploads/Photo/${tour.toLowerCase()}/${paddedId}.jpg`;
}

function parsePlayer(player, tour, fallbackId) {
  if (typeof player === "string") {
    return {
      id: fallbackId ?? null,
      name: player,
      country: null,
      imageUrl: playerImageUrl(tour, fallbackId),
    };
  }

  const id = player?.id ?? player?.playerId ?? fallbackId ?? null;
  const name = player?.name ?? player?.playerName ?? "Unknown";
  const country = player?.countryAcr ?? player?.country?.acronym ?? player?.country ?? null;

  return {
    id,
    name,
    country,
    imageUrl: player?.imageUrl ?? player?.image ?? playerImageUrl(tour, id),
  };
}

function parseMatchPlayerIds(matchId) {
  if (!matchId) return [null, null];
  const parts = String(matchId).split("-");
  const player1Id = parts[0] ? Number(parts[0]) : null;
  const player2Id = parts[1] ? Number(parts[1]) : null;
  return [Number.isFinite(player1Id) ? player1Id : null, Number.isFinite(player2Id) ? player2Id : null];
}

function parseIndicatorServer(indicator) {
  if (!indicator || typeof indicator !== "string") return null;
  const parts = indicator.split(",").map((part) => part.trim());
  if (parts[0] === "1") return 1;
  if (parts[1] === "1") return 2;
  return null;
}

function parseServerIndicator(event, player1Id, player2Id) {
  const raw =
    event?.server ??
    event?.currentServer ??
    event?.servingPlayer ??
    event?.serve ??
    event?.firstToServe ??
    event?.indicator ??
    null;

  const indicatorServer = parseIndicatorServer(event?.indicator);
  if (indicatorServer) return indicatorServer;

  if (raw === 1 || raw === "1" || raw === player1Id) return 1;
  if (raw === 2 || raw === "2" || raw === player2Id) return 2;
  if (typeof raw === "string") {
    const lower = raw.toLowerCase();
    if (lower.includes("player1") || lower.includes("home")) return 1;
    if (lower.includes("player2") || lower.includes("away")) return 2;
  }
  return null;
}

function parseNumericId(value) {
  if (value == null) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (/^\d+$/.test(trimmed)) return Number(trimmed);
  }
  return null;
}

function parseLiveEvents(data) {
  const events = extractArray(data, ["data", "events", "matches", "liveEvents", "results"]);

  return events.map((event) => {
    const tour = (event?.tourType ?? event?.type ?? event?.tour ?? event?.sportType ?? "atp")
      .toString()
      .toLowerCase();
    const [matchPlayer1Id, matchPlayer2Id] = parseMatchPlayerIds(event?.matchId);
    const player1Raw =
      event?.player1 ?? event?.homePlayer ?? event?.homeTeam ?? event?.playerA ?? event?.participant1;
    const player2Raw =
      event?.player2 ?? event?.awayPlayer ?? event?.awayTeam ?? event?.playerB ?? event?.participant2;
    const player1Id = event?.player1Id ?? player1Raw?.id ?? matchPlayer1Id ?? null;
    const player2Id = event?.player2Id ?? player2Raw?.id ?? matchPlayer2Id ?? null;

    return {
      id: parseNumericId(event?.id ?? event?.eventId ?? event?.matchId),
      tour: tour.toUpperCase(),
      tournament:
        event?.tournament?.name ??
        event?.tournamentName ??
        event?.tournament ??
        event?.league ??
        null,
      court: event?.court?.name ?? event?.courtName ?? event?.court ?? null,
      status: event?.status ?? (event?.live ? "LIVE" : null),
      score:
        event?.live ??
        event?.score ??
        event?.liveScore ??
        event?.result ??
        formatStructuredScore(event),
      gameScore: event?.gameScore ?? event?.currentGameScore ?? event?.points ?? null,
      server: parseServerIndicator(event, player1Id, player2Id),
      player1: parsePlayer(player1Raw, tour, player1Id),
      player2: parsePlayer(player2Raw, tour, player2Id),
    };
  });
}

function parseLiveFixtures(data, tour) {
  const fixtures = extractArray(data, ["data.data", "data", "fixtures", "results"]);

  return fixtures
    .filter((fixture) => fixture?.live != null && fixture.live !== "")
    .map((fixture) => ({
      id: parseNumericId(fixture.id),
      tour: tour.toUpperCase(),
      tournament: fixture?.tournament?.name ?? null,
      court: fixture?.court?.name ?? fixture?.courtName ?? fixture?.court ?? null,
      status: "LIVE",
      score: fixture.live,
      gameScore: null,
      server: null, // fixtures endpoint does not expose server — use live events when available
      player1: parsePlayer(fixture.player1, tour, fixture.player1Id),
      player2: parsePlayer(fixture.player2, tour, fixture.player2Id),
    }));
}

function parseUpcomingFixtures(data, tour) {
  const fixtures = extractArray(data, ["data.data", "data", "fixtures", "results"]);
  const now = Date.now();

  return fixtures
    .filter((fixture) => fixture?.live == null || fixture.live === "")
    .map((fixture) => {
      const startRaw =
        fixture?.startDate ??
        fixture?.startTime ??
        fixture?.date ??
        fixture?.scheduledStart ??
        null;
      const startTime = startRaw ? new Date(startRaw).toISOString() : null;
      const startMs = startTime ? Date.parse(startTime) : null;

      return {
        id: parseNumericId(fixture.id),
        tour: tour.toUpperCase(),
        tournament: fixture?.tournament?.name ?? null,
        court: fixture?.court?.name ?? fixture?.courtName ?? fixture?.court ?? null,
        round: fixture?.round?.name ?? fixture?.roundName ?? fixture?.round ?? null,
        startTime,
        _startMs: startMs,
        player1: parsePlayer(fixture.player1, tour, fixture.player1Id),
        player2: parsePlayer(fixture.player2, tour, fixture.player2Id),
      };
    })
    .filter((fixture) => fixture._startMs == null || fixture._startMs >= now - 3_600_000)
    .map(({ _startMs, ...fixture }) => fixture);
}

function parseRankings(data, tour) {
  const rows = extractArray(data, ["data", "rankings", "results"]);

  return rows
    .slice(0, 20)
    .map((row) => {
      const player = row.player ?? row;
      const playerId = player?.id ?? row?.id ?? null;

      return {
        rank: row.position ?? row.racePosition ?? row.rank ?? null,
        points: normalizeRankingPoints(
          row.rankingPoints ?? row.point ?? row.racePoints ?? row.points ?? null
        ),
        player: {
          id: playerId,
          name: player?.name ?? row?.name ?? "Unknown",
          country: player?.countryAcr ?? player?.country?.acronym ?? row?.countryAcr ?? null,
          imageUrl: player?.image ?? playerImageUrl(tour, playerId),
        },
      };
    })
    .filter((entry) => entry.rank != null);
}

// The WTA feed reports points scaled x100 (e.g. 855000 for 8,550 — a decimal
// serialized without the point). No real ranking exceeds ~15,000 points, so
// anything above 30,000 that divides evenly by 100 is scaled back down.
function normalizeRankingPoints(value) {
  const numeric = typeof value === "string" ? Number.parseFloat(value) : value;
  if (typeof numeric !== "number" || !Number.isFinite(numeric)) return null;
  const rounded = Math.round(numeric);
  if (rounded > 30_000 && rounded % 100 === 0) return rounded / 100;
  return rounded;
}

function formatStructuredScore(event) {
  const sets = event?.sets ?? event?.setScores ?? event?.periodScores;
  if (!Array.isArray(sets) || sets.length === 0) return null;
  return sets.map((set) => `${set.player1 ?? set.home ?? 0}-${set.player2 ?? set.away ?? 0}`).join(" ");
}

function extractArray(data, keys) {
  if (Array.isArray(data)) return data;

  for (const key of keys) {
    const value = key.includes(".") ? getNestedValue(data, key) : data?.[key];
    if (Array.isArray(value)) return value;
    if (value?.data && Array.isArray(value.data)) return value.data;
  }

  return [];
}

function getNestedValue(obj, path) {
  return path.split(".").reduce((current, key) => current?.[key], obj);
}

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
