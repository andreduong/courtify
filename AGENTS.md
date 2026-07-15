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
| Player photos (in-app) | `player-{id}-hero` assets + `TennisPlayer.heroImageName` | Fetch ATP/WTA CDN at runtime or use paid API images on free surfaces |
| Tab chrome | `ProfileIconButton`, `TourPillToggle`, `LastUpdatedLabel`, `CourtifyTileDivider` | Duplicate profile/settings entry points or introduce new haptic/animation curves |
| Settings / favorites | `SettingsView` + `AppGroupConstants` | Write prefs outside app group (widgets won't see them) |
| Simulator screenshots | `UITestLaunchArgs` + `simctl launch` flags | Install tap/scroll automation (none available) |

**UI language:** F1-app dark mode — `midnightGreen` base, `emeraldGreen`→`midnightGreen` gradient heroes, white rounded type, `opticYellow` highlights, `courtGreen` tile subtitles, hairline dividers. Motion/haptics only via `CourtifyMotion` + `.courtifyButton(...)`.

**API cost rule:** Worker data refreshes on **user pull-to-refresh** (Rankings, Widgets) or the **one-time onboarding exception**. Everything else reads cache or bundled data. Deploy Worker after `index.js` changes: `npx wrangler deploy`.

**Verify your work:** build → `simctl install` → `simctl launch … -UITestHome [-UITestTab …]` → wait ~7s (bootstrap spinner) → screenshot. See [Simulator testing](#simulator-testing-for-agents) below.

---

## Cloudflare Worker (backend for widgets)

### Purpose

An on-demand Worker that:

1. Serves **`GET /api/widget-data`** from KV with CORS + `Cache-Control: public, max-age=300`
2. Refreshes from RapidAPI at most every **6 hours** when a client request finds stale cache (`MIN_REFRESH_INTERVAL_MS`)
3. Calls the **Tennis API - ATP WTA ITF** on RapidAPI (rankings, live, fixtures)
4. Writes a lightweight JSON payload to **KV** (`TENNIS_DATA` binding, key `widget-data`)

There is **no cron** (see `wrangler.toml`). iOS pull-to-refresh and the one-time onboarding fetch hit this endpoint; free-tier surfaces must not poll it automatically.

### Files

- `index.js` — fetch handler + KV read/write + RapidAPI mapping
- `wrangler.toml` — Worker config, KV binding

### External API

- **Provider**: [Tennis API - ATP WTA ITF](https://rapidapi.com/jjrm365-kIFr3Nx_odV/api/tennis-api-atp-wta-itf)
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

Player headshots are constructed as:

```
https://tennis-api-atp-wta-itf.p.rapidapi.com/tennis/v2/ms-api/uploads/Photo/{atp|wta}/{paddedId}.jpg
```

(`paddedId` = 5-digit zero-padded player ID, e.g. `05992`)

### Widget JSON schema

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
      "wtaRankings": "ok | error:STATUS"
    }
  }
}
```

- `server`: `1` = player1 serving, `2` = player2 serving, `null` if unknown (fixtures fallback has no server data)
- Rate limits: Worker retries on 429/5xx with backoff; 250ms delay between sequential API calls
- **Points normalization**: the WTA feed reports points scaled ×100 (e.g. `855000` for 8,550). `normalizeRankingPoints` fixes this at parse time *and* at serve time (`normalizeCachedPayload`), so stale KV payloads are corrected without extra RapidAPI calls.
- Refresh model is **on-demand**: `/api/widget-data` refreshes from RapidAPI at most every 6 h when a request finds the KV cache stale. No scheduled cron.

### Deployment checklist (user action required)

These steps are **not done** until the user completes them:

1. **Rotate RapidAPI key** — a key was pasted in chat during initial setup; treat it as compromised
2. **Create KV namespaces**:
   ```bash
   wrangler kv namespace create TENNIS_DATA
   wrangler kv namespace create TENNIS_DATA --preview
   ```
3. **Update `wrangler.toml`** — replace `REPLACE_WITH_PRODUCTION_KV_NAMESPACE_ID` and `REPLACE_WITH_PREVIEW_KV_NAMESPACE_ID`
4. **Set secret**:
   ```bash
   wrangler secret put RAPID_API_KEY
   ```
5. **Deploy**:
   ```bash
   npx wrangler deploy   # wrangler CLI may not be on PATH; npx works
   ```
6. **Verify**:
   ```bash
   wrangler tail                          # watch logs
   curl https://courtify-tennis-worker.courtify.workers.dev/api/widget-data
   ```

### Known limitations

- **Live events endpoint** may require a higher RapidAPI plan (Ultra/Mega for some live features). If it fails, the Worker falls back to fixtures filtering.
- **Player images** from the API proxy may require RapidAPI headers when fetched directly by the iOS widget — consider proxying images through the Worker or bundling fallbacks.
- **KV placeholder IDs** in `wrangler.toml` will block deploy until replaced.

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
| Fetch + cache | `WidgetDataStore` | Single `@MainActor` store; KV cache key `widgetDataPayloadCache` in app group |
| Models | `WidgetDataModels.swift` | Codable types matching Worker JSON |
| API URL | `WidgetAPIService.widgetDataURL` | Production Worker endpoint |
| Prefs | `AppGroupConstants` | `favoritePlayerID`, `tourPreference`, `widgetAccessEnabled`, `didFetchOnboardingRankings`, etc. |

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
- **Hero image:** `TennisPlayer.heroImageName` → `player-{id}-hero` transparent torso (not the circular `player-{id}` avatar).
- **Get Premium:** single pill beside "Next Grand Slam" only (not in the status-bar toolbar).
- **Data:** `loadCachedPayload()` on appear only — no automatic Worker refresh.

### Schedule tab (`ScheduleView`)

- Bundled `TournamentCalendar` only — **zero API cost**, ever.
- `CourtifyHeroScrollScreen` with gradient hero, next-major countdown (Days/Hours/Minutes in `opticYellow`).
- List: upcoming events first, then a "Completed" section (dimmed). Tiles use date block + name + `courtGreen`/`opticYellow` subtitle — no white card.
- `TourPillToggle` + `ProfileIconButton` in hero header.

### Rankings tab (`RankingsView`)

- `CourtifyHeroScrollScreen`; hero shows World No. 1 name + bundled `heroImageName` torso on the right.
- Full top 10 as dark tiles (`RankingTile` + `CourtifyTileDivider`).
- **Refresh:** `.refreshable { await dataStore.refresh() }` only; on appear → `loadCachedPayload()` only.
- Hero shows `LastUpdatedLabel` + "· Pull down to refresh" when cache exists; empty cache shows `PullToRefreshHint`.
- WTA points come from Worker already normalized (see points normalization above).

### Settings (profile) screen

Every tab shows `ProfileIconButton` (top-right) → `SettingsView` sheet via
`.settingsSheet(isPresented:)`. Contains:

- **Your favorites** — player + Grand Slam cards with **Change** → picker sheets
  (writes `AppGroupConstants` / `WidgetTimelineRefresher.reloadAll()`).
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
(All / **Free** / Small / Medium / Large), sections with captions under each
card. Catalog: Favorite player (small, **free**), Next tournament
(small + large), Tournament countdown (medium), Season calendar (large),
ATP/WTA standings (medium top-5 + large top-10), Live scores (small),
Order of play (large).

Gating rules:

- **Every widget is Pro-gated except Favorite player.** Entitled means
  `RevenueCatManager.isProUser || AppGroupConstants.referralBypassActive`.
- Locked cards show a `PRO 🎾` badge and the whole card opens the paywall.
- The Favorite player widget uses **bundled data only** (hardcoded
  `TennisPlayer.ranking`, `seasonRecord`, hero asset) so free users never
  trigger API calls. Its paintbrush button opens a picker that writes
  `favoritePlayerID` via `AppGroupConstants.updateFavoritePlayer`.
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
| Widgets gallery — favorite player | `TennisPlayer` bundled rank + `seasonRecord` + hero asset | Never |
| Onboarding favorite-player row | Worker top 10 (or top 5+5 for Both) | **Once ever** on first app open |
| Home-screen widget extension | Worker (Pro/bypass only) | Widget timeline refresh |

**Onboarding one-time fetch** (`OnboardingFlowView.task` →
`WidgetDataStore.refreshOnceForOnboarding()`):

1. Loads cache if present — if hit, no network.
2. Else checks `didFetchOnboardingRankings` in app group — if set, no network
   (even if cache was cleared later).
3. Else calls `refresh()` once and sets the flag on success.

`FavoritePlayersView` maps API rankings onto bundled photos via diacritic-insensitive
last-name + first-initial matching; players outside the bundled catalog get
`custom:` IDs and placeholder avatars. Custom search (`PlayerSearchCatalog`) stays
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
onboarding/rankings; `player-{id}-paywall` are pre-blurred paywall backgrounds.

### Previewing tabs & Settings (DEBUG launch args)

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
   `favorite`, `next-small`, `countdown`, `next-large`, `calendar`,
   `atp-medium`, `atp-large`, `wta-medium`, `wta-large`, `live`, `order`

8. **No tap/scroll automation** — relaunch with different args/prefs instead of
   trying to tap filter pills or pull to refresh.

9. **Layout checks from screenshots:** PRO badge overlapping row 1 (reserve ~56pt
   trailing inset in widget previews), slam logos stretched (use `.fit` not
   `.fill`), bottom tab bar cropping (scroll bottom padding in layout containers).

**Simulator:** iPhone 17 Pro `744F6ACA-F0CC-4105-8794-D798EF7726CC`

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

### UI/UX building blocks

- **Design reference:** F1-style sports app — dark tiles, gradient heroes, no white cards.
- **Reuse:** `CourtifyLayout` containers, `TourPillToggle`, `ProfileIconButton`,
  `.settingsSheet`, `LastUpdatedLabel`, `PullToRefreshHint`, `GetPremiumPill`.
- **Widgets gallery** (`WidgetsCollectionView`): filter pills All/Free/Small/Medium/Large;
  sectioned catalog; only **Favorite player** is free (bundled). All other cards Pro-gated
  (`PRO 🎾` badge → paywall). Reserve ~56pt trailing inset in widget previews so PRO badges
  don't overlap row 1.
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
