# 🧸 Sofi Games — Toddler-Safe Tablet Games (PWA)

**Five free, open-source HTML5 games for babies and toddlers (ages 1–3), built for kiosk-style tablet use.** No ads, no tracking, no in-app purchases, no internet required after first load — just big colorful things that make sounds when tiny fingers tap them.

**🎮 Play now:** https://razhadas.github.io/sofi-games/

<div dir="rtl">

## 🇮🇱 משחקי סופי — משחקים לפעוטות בטאבלט

חמישה משחקים חינמיים לפעוטות (גיל 1–3) בעברית: חיות וקולות, בועות, פסנתר, זיקוקים וציור באצבע. בלי פרסומות, בלי רכישות, בנוי למצב קיוסק — הילד לא יכול לצאת מהמשחק בטעות. עובד בכל דפדפן, מותקן כאפליקציה מהדפדפון ("הוספה למסך הבית").

</div>

## The Games

| Game | What it does |
|------|-------------|
| 🐶 **Animals** (חיות) | Swipe between animal cards, tap to hear real animal sounds |
| 🫧 **Bubbles** (בועות) | Pop floating bubbles — bursts, particles, pop sounds |
| 🎹 **Piano** (פסנתר) | Full-screen rainbow keys, pentatonic notes, multi-touch |
| 🎆 **Fireworks** (זיקוקים) | Tap **anywhere** — fireworks explode at the finger with boom & crackle |
| 🖍️ **Drawing** (ציור) | Finger paints glowing rainbow strokes with sparkles and musical tones; canvas slowly self-clears |

Every game shows a tap score and remembers the all-time best (⭐ current / 🏆 best, stored in `localStorage`).

## Why it's toddler-proof

Designed for a 1.5-year-old who taps, mashes, and swipes randomly:

- **No wrong taps** — every touch gives positive feedback; there is nothing to lose, break, or misconfigure
- **Pinch-zoom fully blocked** (viewport + touch-event guards — Chrome ignores `user-scalable=no` alone)
- **Back button locked** via `history.pushState` trap
- **Exit requires a deliberate 700 ms hold** on a small semi-transparent home button
- **Multi-touch safe** — palm presses and extra fingers never break game state
- **No menus, no dialogs, no text prompts** inside the games
- **Fullscreen persists** across page navigation

## Kiosk setup (lock the tablet to the games)

- **Android:** install as PWA (Chrome → *Add to Home screen*), then enable **App Pinning** (Settings → Security) with PIN-to-unpin
- **Windows tablet:** launch with `chrome.exe --kiosk "https://razhadas.github.io/sofi-games/"`, or use Assigned Access with Edge kiosk mode
- **iPad:** use **Guided Access** (Settings → Accessibility)

## Tech

- **Zero dependencies, zero build step** — vanilla HTML/CSS/JS, one file per game
- **Web Audio API** synthesized sounds (piano harmonics, firework boom + crackle, drawing tones) + real animal recordings inlined as base64 OGG
- **Canvas 2D** particle systems (bubbles, fireworks, drawing sparkles)
- **PWA manifest** — installable, standalone display
- **Time-of-day themed backgrounds** — night stars, dawn, sunset gradients ([theme.js](theme.js))
- **RTL Hebrew UI**

Runs from any static host (GitHub Pages) or straight from the filesystem.

## Run locally

```bash
git clone https://github.com/RazHadas/sofi-games.git
cd sofi-games
python -m http.server 8123
# open http://localhost:8123
```

## License

MIT — use it, fork it, make games for your own kid.

---

*Keywords: toddler games, baby games, kids games, tablet games, touch games, HTML5 games, PWA games, kiosk mode, ad-free kids app, offline games, open source children games, משחקים לפעוטות, משחקים לתינוקות*
