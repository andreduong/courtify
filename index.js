/**
 * Courtify Tennis Widget Worker
 *
 * Fetches live scores + ATP/WTA top-20 rankings from the Tennis API
 * (tennis-api-atp-wta-itf on RapidAPI), caches a lightweight payload in KV,
 * and serves it at GET /api/widget-data.
 *
 * Plan assumption: RapidAPI Matchstat **Pro** ($29/mo, 150k req/mo).
 * Free Basic (50 req/day) is insufficient for custom photos + season W/L.
 */

const API_HOST = "tennis-api-atp-wta-itf.p.rapidapi.com";
const API_BASE = `https://${API_HOST}`;
const KV_KEY = "widget-data";
const KV_META_KEY = "widget-data-meta";
const KV_QUOTA_KEY = "rapidapi-quota";
const CACHE_MAX_AGE_SECONDS = 3600; // 1 hour — clients read KV, not RapidAPI
const PHOTO_CACHE_MAX_AGE_SECONDS = 60 * 60 * 24 * 30; // 30 days at Cloudflare edge
const SEASON_RECORD_TTL_SECONDS = 60 * 60 * 24; // 24 hours in KV
const MIN_REFRESH_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours between RapidAPI refreshes
const REQUEST_DELAY_MS = 250;
const MAX_RETRIES = 1; // Retries multiply quota usage — keep low
const QUOTA_RESERVE_PRO = 100; // Skip upstream when remaining RapidAPI quota is below this (Pro+)
const QUOTA_RESERVE_BASIC = 5; // Basic is 50/day — a 100 reserve would lock the Worker forever

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
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method === "GET" && url.pathname === "/api/widget-data") {
      return serveWidgetData(env);
    }

    if (request.method === "GET" && url.pathname === "/api/player-photo") {
      return servePlayerPhoto(url, env, ctx);
    }

    if (request.method === "GET" && url.pathname === "/api/player-lookup") {
      return servePlayerLookup(url, env);
    }

    if (request.method === "GET" && url.pathname === "/api/player-season-record") {
      return servePlayerSeasonRecord(url, env);
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

  if (await isQuotaTooLow(env)) {
    console.warn("[cron] Skipping refresh — RapidAPI quota reserve exhausted; serving stale KV");
    return;
  }

  console.log("[cron] Starting tennis data refresh");

  try {
    // 5 RapidAPI calls per refresh (ATP + WTA fixtures). Shared payload stays top-20.
    const [
      liveResult,
      atpRankingsResult,
      wtaRankingsResult,
      atpFixturesResult,
      wtaFixturesResult,
    ] = await fetchSequentially(env, [
      { label: "live-events", path: ENDPOINTS.liveEvents },
      { label: "atp-rankings", path: ENDPOINTS.atpRankings },
      { label: "wta-rankings", path: ENDPOINTS.wtaRankings },
      { label: "atp-fixtures", path: ENDPOINTS.atpFixtures },
      { label: "wta-fixtures", path: ENDPOINTS.wtaFixtures },
    ]);

    let liveMatches = [];
    let upcomingMatches = [];

    if (liveResult.ok) {
      liveMatches = parseLiveEvents(liveResult.data);
      console.log(`[cron] Live events endpoint returned ${liveMatches.length} matches`);
    }

    if (atpFixturesResult.ok) {
      upcomingMatches = upcomingMatches.concat(
        parseUpcomingFixtures(atpFixturesResult.data, "atp"),
      );
    } else {
      console.warn(`[cron] ATP fixtures failed: ${atpFixturesResult.status}`);
    }

    if (wtaFixturesResult.ok) {
      upcomingMatches = upcomingMatches.concat(
        parseUpcomingFixtures(wtaFixturesResult.data, "wta"),
      );
    } else {
      console.warn(`[cron] WTA fixtures failed: ${wtaFixturesResult.status}`);
    }

    // Live-events preferred; otherwise merge ATP + WTA fixtures where live != null.
    if (!liveResult.ok || liveMatches.length === 0) {
      const fromAtp = atpFixturesResult.ok
        ? parseLiveFixtures(atpFixturesResult.data, "atp")
        : [];
      const fromWta = wtaFixturesResult.ok
        ? parseLiveFixtures(wtaFixturesResult.data, "wta")
        : [];
      liveMatches = fromAtp.concat(fromWta);
      console.log(`[cron] Fixtures fallback returned ${liveMatches.length} live matches`);
    }

    upcomingMatches = sortUpcomingByStart(upcomingMatches).slice(0, 20);

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
          upcoming:
            upcomingMatches.length > 0
              ? atpFixturesResult.ok && wtaFixturesResult.ok
                ? "ok"
                : atpFixturesResult.ok
                  ? "atp-only"
                  : wtaFixturesResult.ok
                    ? "wta-only"
                    : "empty"
              : "empty",
        },
      },
    };

    await env.TENNIS_DATA.put(KV_KEY, JSON.stringify(payload));
    await env.TENNIS_DATA.put(
      KV_META_KEY,
      JSON.stringify({ lastRefresh: Date.now(), apiCalls: 5 }),
    );
    console.log(
      `[cron] Cached widget data — ${liveMatches.length} live, ` +
        `${payload.rankings.atp.length} ATP / ${payload.rankings.wta.length} WTA rankings, ` +
        `${upcomingMatches.length} upcoming`,
    );
  } catch (error) {
    console.error("[cron] Refresh failed:", error);
  }
}

function sortUpcomingByStart(matches) {
  return matches.slice().sort((a, b) => {
    const aMs = a.startTime ? Date.parse(a.startTime) : Number.POSITIVE_INFINITY;
    const bMs = b.startTime ? Date.parse(b.startTime) : Number.POSITIVE_INFINITY;
    return aMs - bMs;
  });
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

async function isQuotaTooLow(env) {
  try {
    const raw = await env.TENNIS_DATA.get(KV_QUOTA_KEY);
    if (!raw) return false;
    const meta = JSON.parse(raw);
    if (typeof meta.remaining !== "number") return false;
    const limit = typeof meta.limit === "number" ? meta.limit : null;
    // Missing limit (legacy KV) or small daily caps → Basic-style reserve.
    // Pro+ monthly allotments report large limits (e.g. 150000).
    const reserve =
      limit == null || limit <= 100 ? QUOTA_RESERVE_BASIC : QUOTA_RESERVE_PRO;

    // After upgrading Basic → Pro, KV can still hold {remaining:4, limit:50} and
    // permanently gate photos. Allow a probe once the Basic snapshot is stale so
    // recordQuotaFromResponse can rewrite Pro limits.
    const ageMs =
      typeof meta.updatedAt === "number" ? Date.now() - meta.updatedAt : Infinity;
    if (
      meta.remaining < reserve &&
      limit != null &&
      limit <= 100 &&
      ageMs > 60_000
    ) {
      console.warn(
        `[quota] Ignoring stale Basic snapshot (remaining=${meta.remaining}, limit=${limit}, ageMs=${ageMs}) — probing Pro`,
      );
      return false;
    }

    return meta.remaining < reserve;
  } catch {
    return false;
  }
}

async function recordQuotaFromResponse(env, response) {
  const remainingRaw =
    response.headers.get("x-ratelimit-requests-remaining") ||
    response.headers.get("X-RateLimit-Requests-Remaining");
  const limitRaw =
    response.headers.get("x-ratelimit-requests-limit") ||
    response.headers.get("X-RateLimit-Requests-Limit");
  if (remainingRaw == null) return;

  const remaining = Number.parseInt(remainingRaw, 10);
  if (!Number.isFinite(remaining)) return;
  const limit = limitRaw != null ? Number.parseInt(limitRaw, 10) : null;

  try {
    await env.TENNIS_DATA.put(
      KV_QUOTA_KEY,
      JSON.stringify({
        remaining,
        limit: Number.isFinite(limit) ? limit : null,
        updatedAt: Date.now(),
      }),
      { expirationTtl: 60 * 60 * 48 },
    );
  } catch (error) {
    console.warn("[quota] Failed to persist remaining:", error);
  }
}

async function fetchWithRetry(env, path, label, maxRetries = MAX_RETRIES, options = {}) {
  const noRetryOn429 = options.noRetryOn429 === true;
  let attempt = 0;

  if (await isQuotaTooLow(env)) {
    console.warn(`[fetch] ${label} skipped — RapidAPI quota reserve low`);
    return { ok: false, status: 429, data: null };
  }

  while (attempt < maxRetries) {
    attempt += 1;
    console.log(`[fetch] ${label} attempt ${attempt}: ${path}`);

    const response = await fetch(`${API_BASE}${path}`, {
      method: "GET",
      headers: buildHeaders(env.RAPID_API_KEY),
    });

    await recordQuotaFromResponse(env, response);

    if (response.status === 429) {
      console.warn(`[fetch] ${label} rate limited (429)`);
      if (noRetryOn429) {
        return { ok: false, status: 429, data: null };
      }
      const retryAfter = parseInt(response.headers.get("Retry-After") || "5", 10);
      const backoffMs = Math.max(retryAfter, attempt) * 1000;
      console.warn(`[fetch] ${label} waiting ${backoffMs}ms before retry`);
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

/** Name-slug photo (works for inactive players outside rankings top-100). */
function playerNameImageUrl(tour, name) {
  if (!name) return null;
  const slug = foldPlayerName(name).replace(/\s+/g, "_");
  if (!slug) return null;
  return `${API_BASE}/tennis/v2/ms-api/uploads/Photo/${tour.toLowerCase()}_name/${slug}.jpg`;
}

/**
 * Sparse offline meta for fan-favorite inactive / unranked players.
 * Only include verified Matchstat/RapidAPI numeric ids — never guess.
 * Photos still go through /api/player-photo (edge-cached); never expands widget-data.
 * Inactive names without an id still resolve via playerNameImageUrl in servePlayerPhoto.
 */
const PLAYER_META_OVERRIDES = {
  // Example once verified: "atp:nick kyrgios": { id: "#####", name: "Nick Kyrgios", rank: null },
};

function playerMetaOverride(tour, name) {
  const key = `${String(tour).toLowerCase()}:${foldPlayerName(name)}`;
  return PLAYER_META_OVERRIDES[key] ?? null;
}

function foldPlayerName(name) {
  return String(name)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function lastNameOf(name) {
  const parts = foldPlayerName(name).split(/\s+/);
  return parts.length ? parts[parts.length - 1] : "";
}

async function lookupPlayerMeta(env, tour, name) {
  if (!name) return null;

  const cacheKey = `player-meta:${tour}:${foldPlayerName(name)}`;
  const cached = await env.TENNIS_DATA?.get?.(cacheKey);
  if (cached) {
    try {
      return JSON.parse(cached);
    } catch {
      // Ignore corrupt cache entries.
    }
  }

  const override = playerMetaOverride(tour, name);
  if (override?.id) {
    const meta = {
      id: String(override.id),
      rank: override.rank ?? null,
      name: override.name ?? name,
      source: "override",
    };
    await cachePlayerMeta(env, cacheKey, meta);
    return meta;
  }

  // Legacy cache from earlier builds.
  const legacyId = await env.TENNIS_DATA?.get?.(`player-id:${tour}:${foldPlayerName(name)}`);
  if (legacyId) {
    const meta = { id: String(legacyId), rank: null, name };
    await cachePlayerMeta(env, cacheKey, meta);
    return meta;
  }

  if (!env.RAPID_API_KEY) return null;

  let meta = await fetchPlayerMetaFromRankings(env, tour, name);
  if (!meta) return null;

  await cachePlayerMeta(env, cacheKey, meta);
  return meta;
}

async function cachePlayerMeta(env, cacheKey, meta) {
  if (!env.TENNIS_DATA) return;
  await env.TENNIS_DATA.put(cacheKey, JSON.stringify(meta), {
    expirationTtl: 60 * 60 * 24 * 30,
  });
}

/// One RapidAPI call (top-100 rankings) per uncached player name; KV caches for 30 days.
async function fetchPlayerMetaFromRankings(env, tour, name) {
  const path = `/tennis/v2/${tour}/ranking/singles?pageSize=100`;
  const result = await fetchWithRetry(env, path, `rankings-meta-${tour}`, 1, { noRetryOn429: true });
  if (!result.ok) return null;
  return findPlayerInRankingsRows(
    extractArray(result.data, ["data", "rankings", "results"]),
    name,
  );
}

function findPlayerInRankingsRows(rows, name) {
  const match = rows.find((row) => {
    const player = row.player ?? row;
    const rowName = player?.name ?? row?.name ?? row?.player_name ?? "";
    return namesMatch(rowName, name);
  });
  if (!match) return null;

  const player = match.player ?? match;
  const playerId = player?.id ?? match?.id ?? match?.player_id ?? null;
  const rank = match.position ?? match.racePosition ?? match.rank ?? null;
  const playerName = player?.name ?? match?.name ?? name;
  if (!playerId) return null;

  return {
    id: String(playerId),
    rank: rank != null ? Number(rank) : null,
    name: playerName,
  };
}

function normalizeFoldedName(name) {
  return foldPlayerName(name).replace(/-/g, " ").replace(/\s+/g, " ").trim();
}

function namesMatch(candidate, target) {
  const foldedCandidate = normalizeFoldedName(candidate);
  const foldedTarget = normalizeFoldedName(target);
  if (foldedCandidate === foldedTarget) return true;

  const candidateParts = foldedCandidate.split(/\s+/);
  const targetParts = foldedTarget.split(/\s+/);
  const candidateLast = candidateParts[candidateParts.length - 1] ?? "";
  const targetLast = targetParts[targetParts.length - 1] ?? "";
  if (candidateLast.length === 0 || candidateLast !== targetLast) return false;

  if (candidateParts.length > 1 && targetParts.length > 1) {
    return candidateParts[0][0] === targetParts[0][0];
  }
  return true;
}

function isImageBuffer(buffer) {
  if (!buffer || buffer.byteLength < 4) return false;
  const bytes = new Uint8Array(buffer.slice(0, 4));
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return true;
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return true;
  return false;
}

async function servePlayerLookup(url, env) {
  const tour = (url.searchParams.get("tour") || "atp").toLowerCase();
  const name = url.searchParams.get("name");
  if (!name) return jsonResponse({ error: "Missing name" }, 400);

  const meta = await lookupPlayerMeta(env, tour, name);
  if (!meta?.id) {
    // Name-only photo path may still succeed — surface 404 for rank/id callers.
    return jsonResponse({ error: "Player not found" }, 404);
  }

  return jsonResponse({
    id: Number(meta.id),
    rank: meta.rank ?? null,
    name: meta.name ?? name,
    source: meta.source ?? (meta.rank != null ? "rankings-top-100" : "kv"),
  });
}

async function servePlayerSeasonRecord(url, env) {
  const tour = (url.searchParams.get("tour") || "atp").toLowerCase();
  const apiId = url.searchParams.get("apiId");
  if (!apiId) return jsonResponse({ error: "Missing apiId" }, 400);
  if (tour !== "atp" && tour !== "wta") {
    return jsonResponse({ error: "Invalid tour" }, 400);
  }

  if (!env.RAPID_API_KEY) {
    return jsonResponse({ error: "Service unavailable" }, 503);
  }

  const cacheKey = `player-season:${tour}:${apiId}`;
  const cached = await env.TENNIS_DATA.get(cacheKey);
  if (cached) {
    return new Response(cached, {
      status: 200,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "public, max-age=3600",
        "X-Courtify-Cache": "kv",
      },
    });
  }

  const seasonYear = new Date().getUTCFullYear();
  const path = `/tennis/v2/ms-api/${tour}/player/surface-summary/${apiId}`;
  const result = await fetchWithRetry(env, path, `surface-summary-${tour}-${apiId}`, 1, {
    noRetryOn429: true,
  });

  if (!result.ok) {
    if (result.status === 429) {
      return jsonResponse(
        { error: "Season record unavailable", status: 429 },
        429,
        { "Retry-After": "3600" },
      );
    }
    // 404 from RapidAPI often means plan/endpoint gap (surface-summary needs Pro+) or unknown id.
    const status = result.status === 404 ? 404 : 502;
    return jsonResponse(
      { error: "Season record unavailable", status: result.status || status },
      status,
    );
  }

  const parsed = parseSeasonRecord(result.data, seasonYear);
  if (!parsed) {
    return jsonResponse({ error: "Season record empty" }, 404);
  }

  const body = JSON.stringify({
    wins: parsed.wins,
    losses: parsed.losses,
    season: parsed.season,
    source: "surface-summary",
  });

  await env.TENNIS_DATA.put(cacheKey, body, { expirationTtl: SEASON_RECORD_TTL_SECONDS });

  return new Response(body, {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
      "X-Courtify-Cache": "miss",
    },
  });
}

function parseSeasonRecord(data, preferredYear) {
  const rows = extractArray(data, ["data", "results"]);
  if (!Array.isArray(rows) || rows.length === 0) return null;

  const yearStr = String(preferredYear);
  let yearRow =
    rows.find((row) => String(row?.year) === yearStr) ??
    rows.find((row) => String(row?.year) === String(preferredYear - 1)) ??
    rows[0];

  const surfaces = yearRow?.surfaces;
  if (!Array.isArray(surfaces)) return null;

  let wins = 0;
  let losses = 0;
  for (const surface of surfaces) {
    wins += Number.parseInt(surface?.courtWins ?? surface?.wins ?? 0, 10) || 0;
    losses += Number.parseInt(surface?.courtLosses ?? surface?.losses ?? 0, 10) || 0;
  }

  if (wins === 0 && losses === 0) return null;

  return {
    wins,
    losses,
    season: Number.parseInt(String(yearRow?.year), 10) || preferredYear,
  };
}

async function servePlayerPhoto(url, env, ctx) {
  const tour = (url.searchParams.get("tour") || "atp").toLowerCase();
  const apiId = url.searchParams.get("apiId");
  const name = url.searchParams.get("name");
  const code = url.searchParams.get("code");
  // RapidAPI Photo/{id}.jpg is identical for head+hero — share one edge entry.
  const variant = url.searchParams.get("variant") || "head";

  let resolvedId = apiId || null;
  if (!resolvedId && name) {
    const meta = await lookupPlayerMeta(env, tour, name);
    resolvedId = meta?.id ?? null;
  }

  // Stable edge key MUST include apiId or code or name-slug — never bare tour+variant
  // (that collided across players and cached 403s for everyone).
  const cacheUrl = new URL(url.toString());
  cacheUrl.searchParams.delete("name");
  cacheUrl.searchParams.delete("code");
  cacheUrl.searchParams.delete("variant");
  cacheUrl.searchParams.set("tour", tour);
  if (resolvedId) {
    cacheUrl.searchParams.set("apiId", String(resolvedId));
    cacheUrl.searchParams.set("src", "rapid");
  } else if (name) {
    cacheUrl.searchParams.set("slug", foldPlayerName(name).replace(/\s+/g, "_"));
    cacheUrl.searchParams.set("src", "name");
  } else if (code && tour === "atp") {
    cacheUrl.searchParams.set("code", code);
    cacheUrl.searchParams.set("variant", variant);
    cacheUrl.searchParams.set("src", "cdn");
  } else {
    return jsonResponse({ error: "Missing apiId, name, or code" }, 400);
  }

  const cacheRequest = new Request(cacheUrl.toString(), { method: "GET" });
  const cache = caches.default;
  const cached = await cache.match(cacheRequest);
  if (cached && cached.ok) {
    const headers = new Headers(cached.headers);
    headers.set("X-Courtify-Cache", "edge");
    return new Response(cached.body, { status: cached.status, headers });
  }

  const cdnHeaders = {
    Accept: "image/*",
    Referer: "https://www.atptour.com/",
    Origin: "https://www.atptour.com",
    "User-Agent":
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  };

  /** @type {{ url: string, headers: Record<string, string>, rapid: boolean }[]} */
  const candidates = [];
  let rapidBlockedByQuota = false;

  // Prefer name-slug RapidAPI when available (sometimes higher-res than Photo/{id}.jpg),
  // then numeric id, then ATP CDN (often Cloudflare-blocked).
  if (resolvedId || name) {
    if (!env.RAPID_API_KEY) {
      // Fall through to CDN-only below.
    } else if (await isQuotaTooLow(env)) {
      rapidBlockedByQuota = true;
    } else {
      const rapidHeaders = buildHeaders(env.RAPID_API_KEY);
      if (name) {
        const named = playerNameImageUrl(tour, name);
        if (named) {
          candidates.push({ url: named, headers: rapidHeaders, rapid: true });
        }
      }
      if (resolvedId) {
        candidates.push({
          url: playerImageUrl(tour, resolvedId),
          headers: rapidHeaders,
          rapid: true,
        });
      }
    }
  }

  if (code && tour === "atp") {
    const alias =
      variant === "hero"
        ? `player-bodyshot/${code}`
        : `player-gladiator-headshot/${code}`;
    candidates.push({
      url: `https://www.atptour.com/-/media/alias/${alias}`,
      headers: cdnHeaders,
      rapid: false,
    });
  }

  if (!candidates.length) {
    if (rapidBlockedByQuota) {
      return jsonResponse({ error: "Photo proxy quota exhausted" }, 429, {
        "Retry-After": "3600",
      });
    }
    return jsonResponse({ error: "Missing apiId, name, or code" }, 400);
  }

  let buffer = null;
  let contentType = "image/jpeg";
  let lastStatus = 404;

  for (const candidate of candidates) {
    if (!candidate.url) continue;
    const upstreamResponse = await fetch(candidate.url, { headers: candidate.headers });
    if (candidate.rapid) {
      await recordQuotaFromResponse(env, upstreamResponse);
    }
    if (!upstreamResponse.ok) {
      lastStatus = upstreamResponse.status;
      continue;
    }
    const nextBuffer = await upstreamResponse.arrayBuffer();
    if (!isImageBuffer(nextBuffer)) {
      lastStatus = 502;
      continue;
    }
    buffer = nextBuffer;
    contentType = upstreamResponse.headers.get("Content-Type") || "image/jpeg";
    break;
  }

  if (!buffer) {
    // If RapidAPI was the real path but quota blocked it, don't misreport CDN 403 as "not found".
    if (rapidBlockedByQuota) {
      return jsonResponse({ error: "Photo proxy quota exhausted" }, 429, {
        "Retry-After": "3600",
      });
    }
    // Normalize "no usable photo" to 404 — ATP CDN often 403s via Cloudflare, which
    // should not surface as a hard upstream failure for inactive/unranked players.
    const status =
      lastStatus === 429 || lastStatus === 503 ? lastStatus : 404;
    return jsonResponse({ error: "Upstream photo unavailable" }, status);
  }

  const responseHeaders = {
    ...CORS_HEADERS,
    "Content-Type": contentType,
    "Cache-Control": `public, max-age=${PHOTO_CACHE_MAX_AGE_SECONDS}`,
    "X-Courtify-Cache": "miss",
  };

  const response = new Response(buffer, {
    status: 200,
    headers: responseHeaders,
  });

  const storeRequest = new Request(cacheUrl.toString(), { method: "GET" });
  if (ctx?.waitUntil) {
    ctx.waitUntil(cache.put(storeRequest, response.clone()));
  } else {
    await cache.put(storeRequest, response.clone());
  }

  return response;
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
