# Courtify — Agent Context

## Project overview

**Courtify** is an iOS app (SwiftUI) for tennis fans, with plans for home-screen widgets showing live scores and rankings.

This repo has two parts:

| Area | Path | Status |
|------|------|--------|
| iOS app | `Courtify/` | Onboarding, paywall (RevenueCat), home view — uses hardcoded `TennisPlayer` data in `Courtify/Models/OnboardingModels.swift` |
| Cloudflare Worker | `index.js`, `wrangler.toml` | **Implemented** — fetches tennis data, caches in KV, serves `/api/widget-data` |

There is **no Widget Extension target** in the Xcode project yet. The splash screen (`SplashScreenView.swift`) only shows decorative widget previews.

---

## Cloudflare Worker (backend for widgets)

### Purpose

A scheduled Worker that:

1. Runs on a **cron every 15 minutes** (`*/15 * * * *` UTC)
2. Calls the **Tennis API - ATP WTA ITF** on RapidAPI
3. Extracts a lightweight JSON payload for iOS widgets
4. Writes it to **KV** (`TENNIS_DATA` binding, key `widget-data`)
5. Exposes **`GET /api/widget-data`** with CORS + `Cache-Control: public, max-age=300`

### Files

- `index.js` — Worker logic (scheduled + fetch handlers)
- `wrangler.toml` — Worker config, cron, KV binding placeholders

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
| ATP top 10 | `GET /tennis/v2/atp/ranking/singles?pageSize=10` |
| WTA top 10 | `GET /tennis/v2/wta/ranking/singles?pageSize=10` |

Player headshots are constructed as:

```
https://tennis-api-atp-wta-itf.p.rapidapi.com/tennis/v2/ms-api/uploads/Photo/{atp|wta}/{paddedId}.jpg
```

(`paddedId` = 5-digit zero-padded player ID, e.g. `05992`)

### Widget JSON schema

```json
{
  "updatedAt": "ISO-8601",
  "liveMatches": [
    {
      "id": 123,
      "tour": "ATP",
      "tournament": "Wimbledon",
      "status": "LIVE",
      "score": "6-4 3-2",
      "gameScore": null,
      "server": 1,
      "player1": { "id": 47275, "name": "...", "country": "ITA", "imageUrl": "..." },
      "player2": { "id": 68074, "name": "...", "country": "ESP", "imageUrl": "..." }
    }
  ],
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
- Refresh model is **pull-based**: no cron; `/api/widget-data` refreshes from RapidAPI at most every 6 h (`MIN_REFRESH_INTERVAL_MS`) when a request finds the KV cache stale.

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
   wrangler deploy
   ```
6. **Verify**:
   ```bash
   wrangler tail                          # watch logs
   curl https://<worker-url>/api/widget-data
   ```

Local cron test:

```bash
wrangler dev --test-scheduled
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*/15+*+*+*+*"
curl http://localhost:8787/api/widget-data
```

### Known limitations

- **Live events endpoint** may require a higher RapidAPI plan (Ultra/Mega for some live features). If it fails, the Worker falls back to fixtures filtering.
- **Player images** from the API proxy may require RapidAPI headers when fetched directly by the iOS widget — consider proxying images through the Worker or bundling fallbacks.
- **Cron propagation** can take up to ~15 minutes after first deploy.
- **KV placeholder IDs** in `wrangler.toml` will block deploy until replaced.

---

## iOS app (not yet wired to Worker)

### Current state

- SwiftUI app with onboarding flow, theme, RevenueCat paywall
- `TennisPlayer.topPlayers` is **hardcoded** mock data — not fetched from the Worker
- No `WidgetKit` extension exists yet

### Future work (for agents)

1. Add a **Widget Extension** target in Xcode
2. Create a shared model (or duplicate) matching the Worker JSON schema above
3. Point widget timeline provider at `https://<worker-url>/api/widget-data`
4. Replace hardcoded rankings/players in the app with live data where appropriate
5. Handle image loading (API images may need auth headers)
6. Add App Group / shared container if widget and app need shared favorites

### iOS conventions in this repo

- SwiftUI, `@AppStorage` for onboarding preferences
- `ThemeManager` for light/dark theming
- `RevenueCatManager` for subscriptions
- Models in `Courtify/Models/OnboardingModels.swift`

### Full-bleed top layouts (IMPORTANT)

**Never wrap a `GeometryReader` in `.ignoresSafeArea(edges: .top)`** — the reader
then reports `safeAreaInsets.top == 0`, so every "safeTop" offset inside silently
collapses and content overlaps the status bar. This bug shipped once on Home.

Use the shared containers in `Courtify/Shared/CourtifyLayout.swift` instead:

| Container | Use for |
|-----------|---------|
| `CourtifyFullBleedScreen` | Non-scrolling full-bleed screens (Home). Measures the real inset first, then extends content under the status bar via frame + offset, and passes the correct `safeTop` to content. |
| `CourtifyHeroScrollScreen` | Scrolling screens with a gradient hero that fades into the dark background, followed by flat list tiles with `CourtifyTileDivider` hairlines (Schedule, Rankings). F1-app-inspired; no white cards. |
| `CourtifyPlainScrollScreen` | Plain scrolling tabs (Widgets) |

If a new screen needs a full-bleed top, extend one of these rather than hand-rolling `ignoresSafeArea`.

### Settings (profile) screen

Every tab shows a `ProfileIconButton` (top-right) that presents `SettingsView`
(`Courtify/Views/SettingsView.swift`) as a sheet — attach it with
`.settingsSheet(isPresented:)`. It contains favorite player / Grand Slam cards
with picker sheets (writes through `AppGroupConstants` so widgets reload),
premium activate (paywall sheet) + RevenueCat restore, and placeholder
contact/rate actions (`mailto:support@courtify.xyz`, `SKStoreReviewController`).

### Tab screen design language

All tabs share: `ThemeManager.midnightGreen` base, gradient hero top
(`emeraldGreen` → `midnightGreen`), white bold rounded type, `opticYellow` for
highlights/countdowns, `courtGreen` for accent subtitles on tiles, hairline
`CourtifyTileDivider` between rows. Haptics/animation come exclusively from
`CourtifyMotion` + `.courtifyButton(...)` (light impact on press) and
`TourPillToggle` (uses `CourtifyMotion.animateSelection`) — do not introduce
other animation curves or haptic calls.

### Data refresh policy (API cost control)

Live data (rankings/live scores from the Worker) refreshes **only when the user
pulls to refresh** (Rankings and Widgets tabs). No automatic fetch on appear —
screens call `dataStore.loadCachedPayload()` only, and show `LastUpdatedLabel`
plus a "Pull down to refresh" hint. The tournament calendar is bundled
(`TournamentCalendar`, zero API cost). Do not add auto-refresh timers or
on-appear fetches without explicit request.

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

### Previewing the Home screen

Build scheme `Courtify`, install on the iPhone 17 Pro simulator, then launch with
the DEBUG-only `-UITestHome` argument to skip onboarding:

```bash
xcodebuild -scheme Courtify -project Courtify.xcodeproj \
  -destination 'platform=iOS Simulator,id=744F6ACA-F0CC-4105-8794-D798EF7726CC' \
  -derivedDataPath .derivedData build
xcrun simctl install 744F6ACA-F0CC-4105-8794-D798EF7726CC .derivedData/Build/Products/Debug-iphonesimulator/Courtify.app
xcrun simctl launch 744F6ACA-F0CC-4105-8794-D798EF7726CC com.courtify.xyz -UITestHome
```

Add `-UITestTab schedule|rankings|widgets` to open a specific tab (DEBUG only,
read in `HomeView`), and `-UITestSettings` to auto-present the Settings sheet. To preview WTA variants, write the shared app-group pref
before launch (find the container with `xcrun simctl get_app_container <udid>
com.courtify.xyz groups`):

```bash
xcrun simctl spawn <udid> defaults write \
  "<group-container>/Library/Preferences/group.com.courtify.xyz" tourPreference WTA
```

Screenshot with `xcrun simctl io <udid> screenshot out.png`. Note there is no
tap/scroll automation tooling installed — verify states by relaunching with
different args/prefs.

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
