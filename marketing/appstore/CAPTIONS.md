# Courtify App Store Screenshots — captions & SEO

Output: `marketing/appstore/deliverables/` (1290×2796)

Built from **real simulator captures** + your splash marquee (not AI-invented UI).

| # | File | Headline | Subline | Keywords |
|---|------|----------|---------|----------|
| 1 | `01-social-proof.png` | 500,000+ TENNIS FANS. | ONE OBSESSION. ATP & WTA LIVE SCORES, WIDGETS & RANKINGS. | tennis fans, ATP, WTA, live scores, widgets, rankings + press logos + Best of 2026 finalist badge |
| 2 | `02-favorite-player.png` | TRACK YOUR FAVORITE PLAYER. | PERSONALIZED TENNIS STATS, ATP RANKINGS & GRAND SLAM COUNTDOWNS. | favorite player, tennis stats, ATP rankings, Grand Slam |
| 3 | `03-widgets.png` | CUSTOMIZE HOME & LOCK SCREEN WIDGETS. | OVER 15 STYLES FOR ATP, WTA, GRAND SLAMS & LIVE SCORES. | home screen widgets, lock screen, ATP, WTA, Grand Slams, live scores |
| 4 | `04-rankings.png` | ATP & WTA RANKINGS AT A GLANCE. | REAL-TIME TENNIS POINTS & STANDINGS. ALWAYS COURTSIDE. | ATP rankings, WTA rankings, tennis points, standings |
| 5 | `05-grand-slam.png` | NEVER MISS A GRAND SLAM. | US OPEN COUNTDOWN, MASTERS 1000 & TOURNAMENT CALENDAR. | Grand Slam, US Open, Masters 1000, tournament calendar, countdown |
| 6 | `06-order-of-play.png` | LIVE SCORES & ORDER OF PLAY. | INSTANT MATCH UPDATES, ATP / WTA SCHEDULES & WIDGETS. | live scores, order of play, ATP, WTA, schedules, widgets |
| 7 | `07-companion.png` | THE ULTIMATE TENNIS COMPANION. | ATP, WTA, LIVE SCORES, WIDGETS & STATS IN ONE PLACE. | tennis companion, ATP, WTA, live scores, widgets, stats |
| 8 | `08-favorite-widget.png` | YOUR PLAYER. YOUR HOME SCREEN. | FAVORITE PLAYER TENNIS WIDGETS WITH RANK, W-L & SEASON STATS. | favorite player, home screen, tennis widgets, rank, season |

## Regen
```bash
# Recapture raw screens (optional)
# then:
python3 marketing/appstore/compose_screenshots.py
```

## Notes
- Slide 1 credentials (fan count / press / award) are marketing polish — swap if you want softer claims.
- Live scores widget was empty at capture time (off-season); slide 6 uses Order of Play instead.
- Raw simulator PNGs live in `marketing/appstore/raw/`.
