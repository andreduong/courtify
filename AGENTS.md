# Courtify — Agent Context

## Project overview

**Courtify** is an iOS app (SwiftUI) for tennis fans, with plans for home-screen widgets showing live scores and rankings.

This repo has two parts:

| Area | Path | Status |
|------|------|--------|
| iOS app | `Courtify/` | Onboarding, paywall (RevenueCat), Home / Schedule / Rankings / Widgets tabs — wired to Worker via `WidgetDataStore` |
| Widget extension | `CourtifyWidget/` | `PlayerTrackerWidget` + `OrderOfPlayWidget` (Pro-gated via `widgetAccessEnabled`) |
| Cloudflare Worker | `index.js`, `wrangler.toml` | **Deployed** — `https://courtify-tennis-worker.courtify.workers.dev/api/widget-data` |

---

## Agent quick start (read before changing anything)

**Build on what exists — do not re-invent:**

| Area | Source of truth | Do not… |
|------|-----------------|---------|
| Full-bleed layouts | `Courtify/Shared/CourtifyLayout.swift` | Hand-roll `ignoresSafeArea` on a `GeometryReader`; offset hero backgrounds inside a `ScrollView` |
| Live tennis data | `WidgetDataStore` + Worker KV cache | Add on-appear `refresh()`, timers, or per-screen fetch logic |
| Tournament calendar | `TournamentCalendar` (bundled 2026) | Hit RapidAPI for schedule / slam dates |
| Player photos (in-app) | `player-{id}-hero` assets + `PlayerTorsoPhotoView` / `TennisPlayerPhotoView` | Use `placeholder-male` / `placeholder-female` letter assets for custom players |
| Custom favorite rank/photo/W/L | `FavoritePlayerCatalog` + `PlayerRankCache` + `PlayerRemoteLookup` + `PlayerSeasonRecordCache` | Expand `/api/widget-data` to top 100 on every refresh; show unverified cache; fetch W/L inside shared refresh |
| Paywall / splash backdrop | `CourtifyMarqueeBackground` | Per-player paywall photos or silhouettes on paywall |
| Grand Slam logos | `AssetCatalogImage` in pickers | `CachedBundledImage` for slam assets (in-memory cache goes stale) |
| Settings favorite cards | Equal-width `FavoriteCard` + `FavoriteSlamLogoBadge` (circular) + `PlayerTorsoPhotoView` | `FavoritePlayerHeroImage`; oversized silhouette with gradient wash; rectangular slam logos |
| Widget content inset | `WidgetTheme.contentInset` (16pt) on all small/medium widget copy | Per-widget ad-hoc `.padding(14)` that drifts left/right |
| Widget atmosphere | `WidgetAtmosphere` + hatch + surface accent bars (no muddy slam logos as bg) | Flat single-color fills; faded tournament logos behind copy |
| Widget colors (Premium) | `WidgetColorStyle` + `WidgetColorPickerSheet` (app group) | Recoloring tournament widgets (`next-*`, `countdown`, `calendar`) |
| Tab chrome | `ProfileIconButton`, `TourPillToggle`, `LastUpdatedLabel`, `CourtifyTileDivider` | Duplicate profile/settings entry points or introduce new haptic/animation curves |
| Settings / favorites | `SettingsView` + `AppGroupConstants` | Write prefs outside app group (widgets won't see them) |
| Simulator screenshots | `UITestLaunchArgs` + `simctl launch` flags | Install tap/scroll automation (none available) |

**UI language:** F1-app dark mode — `midnightGreen` base, `emeraldGreen`→`midnightGreen` gradient heroes, white rounded type, `opticYellow` highlights, `courtGreen` tile subtitles, hairline dividers. Motion/haptics only via `CourtifyMotion` + `.courtifyButton(...)`.

**API cost rule:** RapidAPI Matchstat **Pro ($29/mo)** is required — Basic 50/day is insufficient. Worker data refreshes on **user pull-to-refresh** (Rankings, Widgets) or the **one-time onboarding exception**. Custom lookup / photo / season-record only on favorite **pick**. Everything else reads cache or bundled data. Deploy Worker after `index.js` changes: `npx wrangler deploy`.

**Verify your work:** build → `simctl install` → `simctl launch … -UITestHome [-UITestTab …]` → wait ~7s (bootstrap spinner) → screenshot. See [Simulator testing](#simulator-testing-for-agents) below.

---

## Cloudflare Worker (backend for widgets)

### Purpose

An on-demand Worker that:

1. Serves **`GET /api/widget-data`** from KV with CORS + `Cache-Control: public, max-age=3600`
2. Refreshes from RapidAPI at most every **6 hours** when a client request finds stale cache (`MIN_REFRESH_INTERVAL_MS`)
3. Calls the **Tennis API - ATP WTA ITF** on RapidAPI (rankings, live, ATP+WTA fixtures)
4. Writes a lightweight JSON payload to **KV** (`TENNIS_DATA` binding, key `widget-data`)
5. Proxies **custom favorite** lookup / photos / season W/L with KV + Cloudflare edge caching

There is **no cron** (see `wrangler.toml`). iOS pull-to-refresh and the one-time onboarding fetch hit this endpoint; free-tier surfaces must not poll it automatically.

### RapidAPI plan (required)

Courtify uses Matchstat’s umbrella product **[Tennis API - ATP WTA ITF](https://rapidapi.com/jjrm365-kIFr3Nx_odV/api/tennis-api-atp-wta-itf/pricing)**.

| Plan | Price | Quota | Verdict |
|------|-------|-------|---------|
| **Basic (Free)** | $0 | **50 req/day** hard limit | **Insufficient** — custom photo + season W/L burns this instantly |
| **Pro (required)** | **$29/mo** | 150,000 req/mo (~5k/day), 10 req/sec | **Canonical Courtify plan** |
| Ultra | $59/mo | 1.2M req/mo | Only if live/odds/PBP needed beyond Pro |
| Mega | $99/mo | 3.8M + WebSocket | Overkill for Courtify |

**Do not migrate vendors** (API-Sports, Sportmonks, Sportradar) for cost: Pro keeps native hero/torso photo IDs and surface-summary W/L without rewriting Worker mappers. Hybrid scraping of ATP/WTA CDNs for WTA heroes is brittle — silhouette fallback is OK when photos fail, not as the primary path.

**Expected burn under Courtify refresh model (~Pro):**

- Shared widget-data refresh ≤ every 6h × **5** upstream calls (live + ATP rank + WTA rank + ATP fixtures + WTA fixtures) ≈ **20 req/day**
- Sparse custom picks: lookup + 2 photos + 1 season-record ≈ **4 req/pick** (then KV/edge cached)
- Stay well under 10% of Pro daily quota at indie scale

### Files

- `index.js` — fetch handler + KV read/write + RapidAPI mapping + photo edge cache + season-record
- `wrangler.toml` — Worker config, KV binding

### External API

- **Provider**: [Tennis API - ATP WTA ITF](https://rapidapi.com/jjrm365-kIFr3Nx_odV/api/tennis-api-atp-wta-itf)
- **Docs**: [tennisapidoc.matchstat.com](https://tennisapidoc.matchstat.com/)
- **Base URL**: `https://tennis-api-atp-wta-itf.p.rapidapi.com`
- **Auth**: `RAPID_API_KEY` secret (Wrangler) — passed as `x-rapidapi-key` header
- **Host header**: `x-rapidapi-host: tennis-api-atp-wta-itf.p.rapidapi.com`

> **Note**: The original task referenced API-Sports-style paths (`/fixtures?live=all`, `/rankings`). This API uses different paths. The Worker maps them as follows:

| Intent | Endpoint used |
|--------|---------------|
| Live matches | `GET /tennis/v2/extend/api/events/live` |
| Live fallback | `GET /tennis/v2/{atp\|wta}/fixtures` — filter rows where `live` is non-null |
| ATP top 20 | `GET /tennis/v2/atp/ranking/singles?pageSize=20` |
| WTA top 20 | `GET /tennis/v2/wta/ranking/singles?pageSize=20` |
| ATP upcoming | `GET /tennis/v2/atp/fixtures?pageSize=100&filter=PlayerGroup:singles` |
| WTA upcoming | `GET /tennis/v2/wta/fixtures?pageSize=100&filter=PlayerGroup:singles` |
| Season W/L | `GET /tennis/v2/ms-api/{atp\|wta}/player/surface-summary/{playerId}` |

Player headshots are constructed as:

```
https://tennis-api-atp-wta-itf.p.rapidapi.com/tennis/v2/ms-api/uploads/Photo/{atp|wta}/{paddedId}.jpg
```

(`paddedId` = 5-digit zero-padded player ID, e.g. `05992`)

### On-demand player lookup, photos & season W/L (quota-sensitive)

Additional endpoints for **custom favorites** outside the bundled top-10 catalog:

| Endpoint | Purpose | RapidAPI cost |
|----------|---------|---------------|
| `GET /api/player-lookup?tour=atp\|wta&name=…` | Rank + API id from top-100 rankings | **One** rankings call per uncached name; KV `player-meta:{tour}:{name}` TTL 30 days |
| `GET /api/player-photo?tour=…&apiId=…&variant=head\|hero` | Proxy player JPEG from RapidAPI | One image fetch per variant **on miss**; Cloudflare `caches.default` + `Cache-Control: max-age=30d` |
| `GET /api/player-season-record?tour=atp\|wta&apiId=…` | Current-season wins/losses | **One** `surface-summary` call per uncached player; KV `player-season:{tour}:{apiId}` TTL **24h** |

**Season record response:**

```json
{ "wins": 22, "losses": 14, "season": 2026, "source": "surface-summary" }
```

Worker sums `courtWins` / `courtLosses` across all surfaces for the current UTC year (falls back to prior year / first row if needed).

**Quota rules (learned the hard way):**

- Do **not** expand `/api/widget-data` refresh to `pageSize=100` — keep top 20 for the shared payload.
- Do **not** fetch season W/L inside the shared widget-data refresh (would be N players × refresh).
- `lookupPlayerMeta` uses a **single** `/ranking/singles?pageSize=100` call; no search/fixtures/ms-api chains.
- Lookup / season-record fetches pass `noRetryOn429: true` — do not burn retries when quota is exhausted.
- Worker tracks `x-ratelimit-requests-remaining` (and limit); when remaining is below a reserve (**5** on Basic-sized limits, **100** on Pro+), skip RapidAPI and serve stale KV / return 429 on photo/season.
- Photos: always via Worker proxy (never put `x-rapidapi-key` in iOS). Edge cache means thousands of clients = one RapidAPI hit per image/month.
- **Deploy Worker only when quota allows**; test lookup/photo/season paths sparingly on Basic; prefer Pro.

iOS only calls lookup / photo / season-record when the user **picks** a custom favorite (`FavoritePlayerEnricher`). Display surfaces + WidgetKit read app-group cache only.


```json
{
  "updatedAt": "ISO-8601",
  "liveMatches": [ ... ],
  "upcomingMatches": [ ... ],
  "rankings": {
    "atp": [{ "rank": 1, "points": 14700, "player": { "id", "name", "country", "imageUrl" } }],
    "wta": [{ ... }]
  },
  "meta": {
    "sources": {
      "live": "events/live | fixtures-filter",
      "atpRankings": "ok | error:STATUS",
      "wtaRankings": "ok | error:STATUS",
      "upcoming": "ok | atp-only | wta-only | empty"
    }
  }
}
```

- `server`: `1` = player1 serving, `2` = player2 serving, `null` if unknown (fixtures fallback has no server data)
- Rate limits: Worker retries on 429/5xx with backoff (except `noRetryOn429` paths); 250ms delay between sequential API calls
- **Points normalization**: the WTA feed reports points scaled ×100 (e.g. `855000` for 8,550). `normalizeRankingPoints` fixes this at parse time *and* at serve time (`normalizeCachedPayload`), so stale KV payloads are corrected without extra RapidAPI calls.
- Refresh model is **on-demand**: `/api/widget-data` refreshes from RapidAPI at most every 6 h when a request finds the KV cache stale. No scheduled cron.
- Shared refresh is **5** RapidAPI calls (adds WTA fixtures vs earlier ATP-only upcoming).

### Explicit do-nots (API cost)

- Do **not** poll live every minute (or any timer) from iOS or Worker cron.
- Do **not** expand shared rankings to top-100 on every refresh.
- Do **not** fetch photos or season W/L on every WidgetKit timeline tick — widgets read app-group only.
- Do **not** migrate TournamentCalendar to the network — keep bundled.
- Do **not** expose RapidAPI keys in the Swift client.
- Do **not** stay on RapidAPI Basic (50/day) if custom favorites / photos / W/L are product requirements.

### Deployment checklist (user action required)

These steps are **not done** until the user completes them:

1. **Upgrade RapidAPI to Pro ($29/mo)** on [Tennis API - ATP WTA ITF pricing](https://rapidapi.com/jjrm365-kIFr3Nx_odV/api/tennis-api-atp-wta-itf/pricing) — Basic is not viable
2. **Rotate RapidAPI key** if it was ever pasted in chat; update Wrangler secret
3. **Create KV namespaces** (if not already):
   ```bash
   wrangler kv namespace create TENNIS_DATA
   wrangler kv namespace create TENNIS_DATA --preview
   ```
4. **Update `wrangler.toml`** — replace placeholder KV namespace IDs if still present
5. **Set secret**:
   ```bash
   wrangler secret put RAPID_API_KEY
   ```
6. **Deploy** after `index.js` changes:
   ```bash
   npx wrangler deploy   # wrangler CLI may not be on PATH; npx works
   ```
7. **Verify**:
   ```bash
   npx wrangler tail
   curl -s https://courtify-tennis-worker.courtify.workers.dev/api/widget-data | head -c 400
   curl -s "https://courtify-tennis-worker.courtify.workers.dev/api/player-season-record?tour=atp&apiId=68074"
   ```

### Known limitations

- **Live events endpoint** may require a higher RapidAPI plan (Ultra/Mega for some live features). If it fails, the Worker falls back to fixtures filtering (ATP + WTA).
- **Player images** require RapidAPI headers upstream — always use Worker `/api/player-photo` (edge-cached). ATP Tour public CDN remains a fallback when `code` is supplied without `apiId`.
- **KV placeholder IDs** in `wrangler.toml` will block deploy until replaced.
- Season W/L for **featured top-10** remains bundled in `TennisPlayer.seasonRecord`; live Worker W/L is for **custom** favorites via `PlayerSeasonRecordCache`.

---

## iOS app

### Current state

- SwiftUI app with onboarding flow, theme, RevenueCat paywall, four main tabs
- Live rankings (top 20 per tour), live scores, and order of play from `WidgetDataStore` → Worker
- `TennisPlayer.topPlayers` remains the **bundled avatar/hero catalog** (10 featured players); onboarding maps API names onto these assets when possible
- Home-screen widgets in `CourtifyWidget/`; free users get bundled-only Favorite player in the in-app gallery

### Shared data layer

| Type | Class / file | Role |
|------|-------------|------|
| Fetch + cache | `WidgetDataStore` | Single `@MainActor` store; KV cache key `widgetDataPayloadCache` in app group; quota alert on 429/503 |
| Models | `WidgetDataModels.swift` | Codable types matching Worker JSON |
| API URL | `WidgetAPIService` | `widgetDataURL`, `playerLookupURL`, `playerPhotoURL`, `playerSeasonRecordURL` |
| Prefs | `AppGroupConstants` | `favoritePlayerID`, `favoritePlayerRevision`, `favoritePlayerWidgetIntentID`, `playerRankCache`, etc. |
| Favorites | `FavoritePlayerCatalog` | Resolve custom IDs, search, display rank |

When changing the JSON schema, update `index.js`, `WidgetDataModels.swift`, and any widget preview code together.

### iOS conventions in this repo

- SwiftUI, `@AppStorage` for onboarding preferences
- `ThemeManager` for light/dark theming
- `RevenueCatManager` for subscriptions
- Models in `Courtify/Models/OnboardingModels.swift`

### Full-bleed top layouts (IMPORTANT)

Two separate traps have shipped bugs — both are solved in `CourtifyLayout.swift`:

| Trap | Symptom | Wrong approach | Correct approach |
|------|---------|----------------|------------------|
| **GeometryReader safe area** | Status bar overlaps chrome; `safeTop` is ~8pt not ~59pt | `.ignoresSafeArea(edges: .top)` on a view that *contains* the `GeometryReader` | Use a shared container that measures inset first, then extends content |
| **ScrollView clipping** | Dark band under status bar on Schedule/Rankings | Offset hero background up by `safeTop` inside a `ScrollView` (clips at bounds) | Apply `.ignoresSafeArea(edges: .top)` on the `ScrollView`; pad hero *content* with `safeTop` |

**Containers** (`Courtify/Shared/CourtifyLayout.swift`):

| Container | Use for |
|-----------|---------|
| `CourtifyFullBleedScreen` | Non-scrolling full-bleed (Home). Passes `(safeTop, size)` to content; grows height by `safeTop` and offsets up. |
| `CourtifyHeroScrollScreen` | Scrolling gradient hero → dark tile list (Schedule, Rankings). Hero fades into `midnightGreen` via bottom gradient behind content. List rows wrapped in one `VStack` so modifiers don't apply per-`ForEach` element. |
| `CourtifyPlainScrollScreen` | Plain scrolling (Widgets). |

If a new screen needs a full-bleed top, **extend one of these** — do not hand-roll.

### Home tab (`HomeDashboardView`)

- Uses `CourtifyFullBleedScreen` — never the old `GeometryReader` + `.ignoresSafeArea(.top)` pattern.
- **Layout:** hero flexes (`maxHeight: .infinity`); Grand Slam countdown is `fixedSize` at the bottom — no fixed 48/52 split (that caused the gap under the player name).
- **Favorite resolve:** `FavoritePlayerCatalog.resolvedPlayer(id:payload:)` — supports `custom:` IDs and `PlayerRankCache` when photos verified.
- **Hero image:** bundled `player-{id}-hero` for featured players; `PlayerTorsoPhotoView` for custom picks (verified API cache) or `PlayerSilhouetteView` (ATP/WTA) — **never** letter placeholders.
- **Rank:** `FavoritePlayerCatalog.displayRank` — widget payload top 20 first, then `PlayerRankCache` only when `photosVerified`.
- **Get Premium:** single pill beside "Next Grand Slam" only (not in the status-bar toolbar).
- **Data:** `loadCachedPayload()` on appear only — no automatic Worker refresh.
- **Grand Slam countdown bg:** `AssetCatalogImage` for slam logos (not `CachedBundledImage`).

### Schedule tab (`ScheduleView`)

- Bundled `TournamentCalendar` only — **zero API cost**, ever.
- `CourtifyHeroScrollScreen` with gradient hero, next-major countdown (Days/Hours/Minutes in `opticYellow`).
- List: upcoming events first, then a "Completed" section (dimmed). Tiles use date block + name + `courtGreen`/`opticYellow` subtitle — no white card.
- `TourPillToggle` + `ProfileIconButton` in hero header.

### Rankings tab (`RankingsView`)

- `CourtifyHeroScrollScreen`; hero shows World No. 1 name + bundled `heroImageName` torso on the right.
- Full top 20 as dark tiles (`RankingTile` + `CourtifyTileDivider`).
- **Refresh:** `.refreshable { await dataStore.refresh() }` only; on appear → `loadCachedPayload()` (always reloads from app-group disk).
- Hero shows `LastUpdatedLabel` + "· Pull down to refresh" when cache exists; `PullToRefreshHint` only when **no cache at all**.
- On pull-to-refresh with HTTP **429/503**, `WidgetDataStore.quotaExceededOnLastRefresh` → alert; **keep showing last cached rankings**.
- WTA points come from Worker already normalized (see points normalization above).

### Settings (profile) screen

Every tab shows `ProfileIconButton` (top-right) → `SettingsView` sheet via
`.settingsSheet(isPresented:)`. Contains:

- **Your favorites** — player + Grand Slam cards with **Change** → picker sheets
  (`FavoritePlayerPickerSheet`, `FavoriteSlamPickerSheet`; writes `AppGroupConstants` / `WidgetTimelineRefresher.reloadAll()`).
- **Favorite cards layout:** equal-width `FavoriteCard`s with overlay artwork (`PlayerTorsoPhotoView` / silhouette / `FavoriteSlamLogoBadge`) — do **not** reuse `FavoritePlayerHeroImage`. Artwork must not drive intrinsic height or Change gets clipped.
- **Slam picker logos:** `AssetCatalogImage` (fresh from asset catalog). Settings cards use circular `FavoriteSlamLogoBadge`.
- **Personal** — time zone (display only), 24h format toggle, Premium activate
  (paywall), Restore purchase (RevenueCat).
- **Help** — `mailto:support@courtify.xyz`, How to add widgets (in-app guide),
  Rate us (`SKStoreReviewController`).
- DEBUG: `-UITestSettings` auto-opens the sheet from Home.

### Tab screen design language

All tabs share: `ThemeManager.midnightGreen` base, gradient hero top
(`emeraldGreen` → `midnightGreen`), white bold rounded type, `opticYellow` for
highlights/countdowns, `courtGreen` for accent subtitles on tiles, hairline
`CourtifyTileDivider` between rows. Haptics/animation come exclusively from
`CourtifyMotion` + `.courtifyButton(...)` (light impact on press) and
`TourPillToggle` (uses `CourtifyMotion.animateSelection`) — do not introduce
other animation curves or haptic calls.

### Widgets tab (gallery)

`WidgetsCollectionView` is an F1-app-style gallery: filter pills
(All / Small / Medium / Large / **Free**), sections with captions under each
card. Catalog: Favorite player (small + medium, **free**), Next tournament
(small + large), Tournament countdown (medium), Season calendar (large),
ATP/WTA standings (medium top-5 + large top-10), Live scores (small),
Order of play (large), Lock Screen (circular rank **free**, circular countdown,
rectangular next / live preview).

Gating rules:

- **Pro-gated except:** Favorite player (small + medium) and Lock Screen favorite rank.
  Entitled means `RevenueCatManager.isProUser || AppGroupConstants.referralBypassActive`.
- Locked cards show a `PRO 🎾` badge and the whole card opens the paywall.
- The Favorite player widget uses **bundled season record** + `FavoritePlayerCatalog.resolvedPlayer` for rank when available; bundled `-hero` for featured players. Custom picks show verified API photos or empty hero (no letter placeholders).
- **Gallery small widgets** are **165×165 pt squares** (`previewHeight` width = height); lone small cards align leading, not full-width.
- Paintbrush on favorite card opens `FavoritePlayerPickerSheet` → writes `favoritePlayerID` via `AppGroupConstants.updateFavoritePlayer`.
- Rankings / live / order-of-play cards read `WidgetDataStore` (cached payload;
  pull-to-refresh only). Tournament cards read the bundled
  `TournamentCalendar` (zero API cost).

### Data refresh policy (API cost control)

**Default rule:** live Worker data refreshes **only when the user pulls to refresh**
(Rankings and Widgets tabs). On appear, screens call `dataStore.loadCachedPayload()`
only, and show `LastUpdatedLabel` plus a pull-to-refresh hint. Do not add
auto-refresh timers or on-appear `refresh()` without an explicit product request.

| Surface | Data source | Network? |
|---------|-------------|----------|
| Rankings tab (20 rows/tour) | Cached Worker payload | Pull-to-refresh only |
| Widgets gallery — rankings / live / order of play | Same cache | Pull-to-refresh only |
| Widgets gallery — tournaments | `TournamentCalendar` (bundled 2026) | Never |
| Widgets gallery — favorite player | Bundled season record **or** `PlayerSeasonRecordCache` + optional verified rank/photo cache | Picker select only (lookup + photo + season-record) |

### Custom favorite players (outside top 20)

| File | Role |
|------|------|
| `FavoritePlayerCatalog` | Resolve `custom:atp\|wta:{name}` IDs; search; display rank |
| `FavoritePlayerPickerSheet` | Shared picker (Settings + Widgets); search-first UX |
| `PlayerRemoteLookup` | One `/api/player-lookup` on pick when not in top-20 payload |
| `PlayerRankCache` | App-group `playerRankCache` — rank + apiId; `photosVerified` gate |
| `PlayerPhotoFetcher` / `PlayerPhotoStore` | Download + cache head/hero JPEGs under `player-images/` |
| `PlayerSeasonRecordFetcher` / `PlayerSeasonRecordCache` | One `/api/player-season-record` on pick; app-group W/L for widgets + Home |
| `PlayerTorsoPhotoView` | Home hero; bundled `-hero` or verified cache or silhouette |
| `PlayerSilhouetteView` | ATP `figure.tennis` / WTA `figure.dress.line.vertical.figure` fallback |
| `TennisPlayerPhotoView` | Circular headshots in lists |

**Pick flow:** clear stale photos / rank / season cache → lookup → store rank (unverified) → fetch photos → `markPhotosVerified` on success → fetch season W/L into `PlayerSeasonRecordCache`; on photo failure remove unverified rank display path / show silhouette.

**Display:** `TennisPlayer.displaySeasonRecord` prefers bundled featured W/L, else `PlayerSeasonRecordCache`.

**Cache migration:** `AppGroupConstants.migratePlayerCachesIfNeeded()` (schema v2) wipes stale `playerRankCache` + `player-images/` once on upgrade.

**Widget intent sync:** `FavoritePlayerWidget` only promotes widget-intent → app-group when intent **changes** (`favoritePlayerWidgetIntentID`), not on every reload.

### Paywall

- Background: `CourtifyMarqueeBackground` — **live** scrolling mini widget cards (same SwiftUI views as the gallery), **not** the old static `marquee-widget-strip` asset and not per-player photos.
- `BundledImageCache.warmOnboardingAssets()` on appear (player + paywall assets). Do **not** warm `marquee-widget-strip` — splash/paywall no longer use it.

**Onboarding one-time fetch** (`OnboardingFlowView.task` →
`WidgetDataStore.refreshOnceForOnboarding()`):

1. Loads cache if present — if hit, no network.
2. Else checks `didFetchOnboardingRankings` in app group — if set, no network
   (even if cache was cleared later).
3. Else calls `refresh()` once and sets the flag on success.

**Onboarding favorite persistence (important):**

- Tour / favorite player / Grand Slam drafts bind to the **same app-group keys** Home and Settings read (`tourPreference`, `favoritePlayerID`, `favoriteGrandSlam`). Picks are written as the user continues each step (`persistOnboardingDraft`), not only at paywall exit.
- `AppRootView.shouldShowHome` is gated on **`hasCompletedOnboarding` only** (plus UITest flags). Do **not** treat `isProUser` or `referralBypassActive` alone as “skip onboarding” — that raced ahead of `commitOnboarding` and dropped picks for fresh installs / mid-paywall Pro flips.
- Final `commitOnboarding` still runs on subscribe / referral / free close: syncs widget access, bumps `favoritePlayerRevision`, reloads timelines.

`FavoritePlayersView` maps API rankings onto bundled photos via diacritic-insensitive
last-name + first-initial matching; players outside the bundled catalog get
`custom:` IDs and silhouettes until photos verify. Custom search (`PlayerSearchCatalog`) stays
bundled — no API for autocomplete.

**Free vs Pro widget access:** `AppGroupConstants.widgetAccessEnabled` is synced from
RevenueCat Pro or referral bypass. Free onboarding completion sets it `false` so home
widgets show the locked state. The in-app Favorite player gallery card is always free
and never reads live rankings.

### Player hero images (zero API cost)

Home uses transparent full-torso cutouts bundled in `Assets.xcassets` as
`player-{id}-hero` imagesets (`TennisPlayer.heroImageName`). They were downloaded
**once at development time** from the tours' free public media CDNs — do NOT fetch
them at runtime and do NOT use the paid RapidAPI for images:

- **ATP**: `https://www.atptour.com/-/media/alias/player-gladiator-headshot/{playerCode}`
  (e.g. Djokovic `d643`, Sinner `s0ag`, Alcaraz `a0e2`, Medvedev `mm58`, Zverev `z355`).
  Cloudflare blocks curl/scripts — fetch through a real browser session.
- **WTA**: torso PNG URLs on `photoresources.wtatennis.com` (curl-friendly); find the
  exact UUID URL by grepping the player page (`https://www.wtatennis.com/players/{id}/{slug}`)
  for `Torso`. Supports `?width=&height=` resizing.

The old `player-{id}` imagesets are small circular avatar cutouts still used by
onboarding/rankings; `player-{id}-paywall` are pre-blurred paywall backgrounds for **bundled** players only.

**Never use `placeholder-male` / `placeholder-female`** for custom player surfaces — use `PlayerSilhouetteView` or verified API cache.

### Bundled assets & image caching

| Component | Use |
|-----------|-----|
| `CachedBundledImage` | Player onboarding cards, paywall bundled `-paywall` assets — **in-memory cache** |
| `AssetCatalogImage` | Grand Slam logos in pickers / Home countdown — always reads asset catalog (avoids stale slam logos after asset swaps) |

`BundledImageCache.warmOnboardingAssets()` preloads player + paywall assets; **does not** preload slam logos or `marquee-widget-strip`.

### Simulator stale-state trap

After changing **asset catalog PNGs** or **Swift UI logic**, agents must **uninstall** the app before re-installing — otherwise old in-memory `BundledImageCache` entries and app-group photo files can make fixes look broken:

```bash
xcrun simctl uninstall <udid> com.courtify.xyz
# rebuild, install, launch
```

Seed rankings for UI tests: `defaults write … widgetDataPayloadCache -data "$(xxd -p /tmp/widget-data.json | tr -d '\n')"` on `group.com.courtify.xyz`.


All hooks are parsed from `ProcessInfo.processInfo.arguments` via
`Courtify/Shared/UITestLaunchArgs.swift` — pass flags to `simctl launch`, not
`UserDefaults`.

| Flag | Effect |
|------|--------|
| `-UITestHome` | Skip onboarding → main `TabView` |
| `-UITestPaywall` | Reset onboarding prefs → onboarding / paywall flow |
| `-UITestTab schedule\|rankings\|widgets` | Open that tab (omit for Home) |
| `-UITestSettings` | Auto-present Settings sheet (Home tab) |
| `-UITestWidgetFilter free\|small\|medium\|large` | Preselect Widgets gallery filter |
| `-UITestWidgetOnly <itemID>` | Render one widget card (see IDs below) |
| `-UITestWidgetColor [itemID]` | Open color sheet for a customizable id (default `favorite`); free users get paywall |

**Standard build + launch loop:**

```bash
xcodebuild -scheme Courtify -project Courtify.xcodeproj \
  -destination 'platform=iOS Simulator,id=744F6ACA-F0CC-4105-8794-D798EF7726CC' \
  -derivedDataPath .derivedData build
xcrun simctl install 744F6ACA-F0CC-4105-8794-D798EF7726CC \
  .derivedData/Build/Products/Debug-iphonesimulator/Courtify.app
xcrun simctl launch 744F6ACA-F0CC-4105-8794-D798EF7726CC com.courtify.xyz \
  -UITestHome -UITestTab rankings
```

Wait **~7 seconds** after launch (bootstrap `ProgressView` + RevenueCat) before
`xcrun simctl io <udid> screenshot out.png`.

### Simulator testing (for agents)

Use this loop every session — do not rediscover setup:

1. **Build + install** (Debug, `.derivedData`):
   ```bash
   xcodebuild -scheme Courtify -project Courtify.xcodeproj \
     -destination 'platform=iOS Simulator,id=744F6ACA-F0CC-4105-8794-D798EF7726CC' \
     -derivedDataPath .derivedData build
   xcrun simctl install 744F6ACA-F0CC-4105-8794-D798EF7726CC \
     .derivedData/Build/Products/Debug-iphonesimulator/Courtify.app
   ```

2. **Launch to a specific state** — combine flags as needed:
   ```bash
   xcrun simctl launch 744F6ACA-F0CC-4105-8794-D798EF7726CC com.courtify.xyz \
     -UITestHome -UITestTab schedule
   ```

3. **WTA tour** — write app-group pref before launch:
   ```bash
   CONTAINER=$(xcrun simctl get_app_container 744F6ACA-F0CC-4105-8794-D798EF7726CC \
     com.courtify.xyz groups | awk '{print $2}')
   PLIST="$CONTAINER/Library/Preferences/group.com.courtify.xyz"
   xcrun simctl spawn 744F6ACA-F0CC-4105-8794-D798EF7726CC \
     defaults write "$PLIST" tourPreference WTA
   ```

4. **Free vs Pro** — same plist path:
   ```bash
   xcrun simctl spawn <udid> defaults write "$PLIST" referralBypassActive -bool NO
   xcrun simctl spawn <udid> defaults write "$PLIST" widgetAccessEnabled -bool NO
   ```

5. **Seed rankings cache** (test tiles without pull-to-refresh):
   ```bash
   curl -s https://courtify-tennis-worker.courtify.workers.dev/api/widget-data \
     -o /tmp/widget-data.json
   HEX=$(xxd -p /tmp/widget-data.json | tr -d '\n')
   xcrun simctl spawn <udid> defaults write "$PLIST" widgetDataPayloadCache -data "$HEX"
   ```

6. **Clear cache** (empty Rankings / pull-hint state):
   ```bash
   xcrun simctl spawn <udid> defaults delete "$PLIST" widgetDataPayloadCache
   ```

7. **Widget gallery item IDs** for `-UITestWidgetOnly`:
   `favorite`, `favorite-medium`, `next-small`, `countdown`, `next-large`, `calendar`,
   `atp-medium`, `atp-large`, `wta-medium`, `wta-large`, `live`, `order`,
   `lock-rank`, `lock-countdown`, `lock-next`, `lock-live`

8. **No tap/scroll automation** — relaunch with different args/prefs instead of
   trying to tap filter pills or pull to refresh.

9. **Layout checks from screenshots:** PRO badge overlapping row 1 (reserve ~56pt
   trailing inset in widget previews), slam logos stretched (use `.fit` not
   `.fill`), bottom tab bar cropping (scroll bottom padding in layout containers).

**Simulator:** iPhone 17 Pro `744F6ACA-F0CC-4105-8794-D798EF7726CC`

### Local dev modes (agents)

**Default: use the Simulator for everything** — UI, data, backend, screenshots. Courtify loads a large asset catalog (`player-*-hero`, slam logos, marquee), RevenueCat, and app-group state; SwiftUI Canvas re-indexes all of that and often shows stuck **"empty catalog import…"** while making Xcode slow and CPU-heavy. Prefer `scripts/dev-sim-hot-reload.sh` and close Xcode Canvas when not archiving.

#### Simulator hot reload (default)

**Use for:** all UI tweaks, `index.js` / Worker JSON, `WidgetDataStore`, app-group cache, custom-favorite lookup, launch-arg screen states, screenshots, E2E before TestFlight.

| Step | Action |
|------|--------|
| Start | `bash scripts/dev-sim-hot-reload.sh` |
| Optional tab | `bash scripts/dev-sim-hot-reload.sh -UITestHome -UITestTab widgets` |
| Skip first build | `SKIP_INITIAL_BUILD=1 bash scripts/dev-sim-hot-reload.sh` (if app already installed) |
| Iterate | Save any `.swift` under `Courtify/` or `CourtifyWidget/` → incremental build + reinstall + relaunch (~20–30s) |
| Build log | `/tmp/courtify-dev-build.log` |
| Seed rankings | See step 5 below (`widgetDataPayloadCache` hex) |
| Keep cool | Edit in Cursor; quit Xcode (or disable Canvas) while the watcher runs |

Default launch: `-UITestHome -UITestTab rankings`. After **asset catalog** or **in-memory cache** changes, `simctl uninstall … com.courtify.xyz` before reinstall.

#### SwiftUI Canvas (optional — rarely)

Only if you need sub-second iteration on a **single isolated view** with no bundled assets. Avoid for Courtify tab screens (they pull the full catalog). If Canvas shows "empty catalog import…", stop using it and switch to the simulator script above.

| Step | Action |
|------|--------|
| Start | `bash scripts/dev-ui-preview.sh` |
| Hub file | `Courtify/Views/UITweakPreviews.swift` |

**Not valid in Canvas:** `WidgetDataStore.refresh()`, seeded cache, `-UITest*` launch args, widget extension, onboarding, paywall.

### TestFlight release

1. Bump `CURRENT_PROJECT_VERSION` in `Courtify.xcodeproj/project.pbxproj` (all targets).
2. Commit + push when the user asks.
3. Deploy Worker if `index.js` changed: `npx wrangler deploy`
4. Upload:
   ```bash
   bash scripts/upload-testflight.sh
   ```
   Uses `scripts/xcode-env.sh` (`DEVELOPER_DIR` → Xcode 26.0.1). Archive +
   export + upload to App Store Connect; wait for processing in TestFlight.

### Home-screen widget (manual E2E)

After onboarding with a favorite player set, long-press home screen → add widget →
Courtify → **Player Tracker** (small). Free users should see the locked view;
Pro/referral users see bundled rank + optional live data. Changing favorite in
Settings or the Widgets gallery picker calls `WidgetTimelineRefresher.reloadAll()`.
Agents cannot add widgets via simctl — verify in Simulator manually or on device
after TestFlight install.

---

## Established practices (build on these, don't redo)

### UI/UX anti-patterns (already fixed — don't reintroduce)

- White rounded card overlapping hero on Schedule/Rankings (use dark tiles + `CourtifyTileDivider`).
- Fixed % height split on Home (use flex hero + content-sized countdown).
- Circular `player-{id}` asset as Home hero (use `player-{id}-hero` torso).
- Duplicate Get Premium pills on Home (one beside Grand Slam only).
- Slam logo in Schedule hero at `.fill` in a small frame (assets are wide — use typography or `.fit`).
- Per-row `.padding` inside `ForEach` passed to `CourtifyHeroScrollScreen` listContent (wrap rows in a single `VStack` in the container instead).
- `AsyncImage` on Home or Schedule (bundled only on those surfaces).
- `placeholder-male` / `placeholder-female` for custom favorites (use `PlayerSilhouetteView`).
- `FavoritePlayerHeroImage` inside Settings `FavoriteCard` (widget padding breaks layout).
- `CachedBundledImage` for Grand Slam logos after asset updates (use `AssetCatalogImage`).
- Full-width small widget gallery cards (small = 165×165 square, leading-aligned).
- Per-player photo/silhouette on paywall (use `CourtifyMarqueeBackground`).
- **Settings `FavoriteCard` taller than `Change`:** oversized torso/silhouette intrinsic size + `.frame(height:)` centers content → title and Change get clipped. Keep artwork overlay-only (no huge intrinsic size); pad Change above the 20pt corner radius; both cards `minWidth: 0` + equal `maxWidth: .infinity`.
- **Silhouette “half white gradient” on widgets:** never put a `LinearGradient` / fill behind `PlayerSilhouetteView` torso — when the hero is leading-padded, the wash only covers the trailing half and looks broken. Use monochrome SF Symbol only.
- **Gallery chrome expanding small cards:** palette/person overlays must live *inside* a ZStack framed to the preview size (165×165). `frame(maxWidth: .infinity)` on overlay buttons pushes a lone small card to the trailing edge.
- **Ad-hoc widget padding:** always use `WidgetTheme.contentInset` (16pt) for small/medium copy. Favorite may add trailing air for silhouette, but leading/top/bottom stay on the shared inset.
- **Widget backgrounds:** prefer `WidgetAtmosphere` / hatch texture and surface-color accent bars; do not fade Grand Slam logos into the background.
- **Widget typography:** `WidgetTheme.displayFont` (default design, heavy) for ranks / countdowns / scores; `roundedFont` for labels — mix weights like F1 sports apps, don’t use one rounded size for everything.
- **Medium hero + stats overlap:** keep copy and player cutouts in **separate columns** (or tuck a small hero *under* rank text). Never stack Win/Loss/% or leaderboard rows on top of the torso.
- **Marquee blackout gutters:** `CourtifyMarqueeBackground` row `startOffset` must not be a positive x-offset into empty space — that leaves a solid midnight strip on the leading edge (reads as a “black rectangle” on paywall/splash). Prefer negative phase / wrap within duplicated strips.
- **Paywall + onboarding chrome:** do **not** wrap the paywall step in `OnboardingFlowView`’s top `safeAreaInset` chrome. The inset reserves a band that only shows `.courtifyBackground()` while the marquee lives in the content below → top-left blackout bar. Paywall should own full-bleed background + its own close control (`managesOwnCloseButton`).
- **WidgetKit bundle limit:** keep the extension’s `@main` `WidgetBundle` **flat** (≤ ~10 kinds). Nested `WidgetBundle` types did **not** compile as `Widget` in this project’s SDK — split kinds or drop a family instead of nesting.
- **Rectangular slam logos in Settings:** wrap with `FavoriteSlamLogoBadge` — `scaledToFill` + `clipShape(Circle())` so AO / RG / Wimbledon / US Open all read as round badges (wide US Open wordmark fills then clips).
- **Quota UX:** when custom favorite photos fail (RapidAPI 429), show silhouette + helper copy / one-shot alert — don’t leave blank heroes or look “broken.”

### UI/UX building blocks

- **Design reference:** F1-style sports app — dark tiles, gradient heroes, no white cards.
- **Reuse:** `CourtifyLayout` containers, `TourPillToggle`, `ProfileIconButton`,
  `.settingsSheet`, `LastUpdatedLabel`, `PullToRefreshHint`, `GetPremiumPill`,
  `FavoritePlayerCatalog`, `FavoritePlayerPickerSheet`, `FavoritePlayerEnricher`,
  `PlayerTorsoPhotoView`, `PlayerSilhouetteView`, `PlayerSeasonRecordCache`, `FavoriteSlamLogoBadge`,
  `WidgetColorStyle`, `WidgetColorPickerSheet`, `WidgetAtmosphere`, `WidgetTheme.displayFont`,
  `CourtifyMarqueeBackground` (live cards), `AssetCatalogImage`.
- **Home-screen + Lock Screen widgets** (`CourtifyWidget/`): favorite (S+M), tournaments, standings,
  live, order of play, plus accessory circular/rectangular kinds in `LockScreenWidgets.swift`.
  Reload via `WidgetTimelineRefresher` (includes lock-screen kinds).
- **Widgets gallery** (`WidgetsCollectionView`): filter pills All/Small/Medium/Large/Free;
  sectioned catalog; **Favorite player** (S+M) + **Lock Screen rank** are free. Others Pro-gated
  (`Premium 🎾` badge → paywall). Small = 165×165 leading-aligned. Overlay chrome:
  color control (top-trailing, Premium) on customizable ids; person control (bottom-trailing)
  on favorite for player pick. Tournament ids (`next-small`, `countdown`, `next-large`,
  `calendar`) keep surface/brand gradients — no recolor.
- **Widget color prefs:** app-group key `widgetColorStyles` via `WidgetColorStyle`;
  preset accent + gradient level; free users tapping color → paywall.
- **Onboarding player cards:** horizontal scroll, star on primary pick, bundled search sheet
  for out-of-top-10 names.

### API / backend

- One Worker request serves rankings + live + upcoming; iOS caches the whole payload in app group.
- Worker refresh is **on-demand** (stale KV + user/client request), max once per 6 h — not cron.
- WTA points ×100 normalization: `normalizeRankingPoints` at parse **and** `normalizeCachedPayload` at serve.
- Expanding ranking depth: change `pageSize` in `index.js` **and** deploy — UI reads `dataStore.rankings(for:)`.
- Player photos in-app: bundled assets. Widget extension may cache RapidAPI image URLs via `WidgetImageCache` (Pro widget cost only).

### Testing

- Parse launch args via `UITestLaunchArgs` — add new hooks there + document in this file.
- Prefer launch-arg / plist state over UI automation.
- Wait ~7s after launch before screenshots.
- Screenshot every UI state you change before calling the task done.

---

## Agent guidelines

- **Do not commit** `RAPID_API_KEY` or any secrets to the repo
- Prefer editing `index.js` for Worker changes; keep the KV payload small for widget performance
- When changing the JSON schema, update both `index.js` and any future iOS/widget models together
- Use Cloudflare plugin skills (`wrangler`, `workers-best-practices`) when modifying the Worker
- The Worker lives at the **repo root** (`index.js`, `wrangler.toml`), separate from the Xcode project under `Courtify/`

---

## Git & GitHub

**Remote**: https://github.com/andreduong/courtify

Agents should **commit and push** completed work so the repo stays documented. See `.cursor/rules/git-documentation.mdc` for the full workflow.

Quick checklist after a task:

1. `git status` — confirm no secrets or ignored artifacts are staged
2. Commit with a clear message describing *why*
3. `git push -u origin HEAD` (or `git push` if upstream exists)

Update this file (`AGENTS.md`) when project architecture, API contracts, or deployment steps change.
