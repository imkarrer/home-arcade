# Mika's Adorable Playhouse

A collection of educational games for toddlers and kids, all in one cozy place.

This repo is a set of small HTML games plus a single-file dashboard (`index.html`) that finds them automatically and lets kids pick one to play. Add a game, push it, and it shows up. No build step and no list to maintain.

**[Live Site](https://kungpowunicorn.github.io/map/)**

## Features

- **Automatic discovery.** Every `.html` file in the repo, including subfolders, becomes a card with the game's own icon and title.
- **Play inside the dashboard.** Games open in an embedded player with back, previous/next, restart, fullscreen, and open-in-new-tab buttons. Each game has its own URL (`#/folder/game.html`), so links and the browser back button work.
- **Works offline.** Visit the site once with internet and the whole repo is saved to the device. After that, the games open with no signal. It can also be installed to the home screen.
- **Default icons.** A game with no icon gets a pastel tile with an emoji picked from its filename (`abc` gives 🔤, `farm` gives 🐄), or a stable random one.
- **Find things fast.** Search, favorites (★), a favorites-only filter, a random-game button, and sorting A–Z or by folder.
- **Header controls.** Hide the top bar with the ▲ button or the `H` key, or turn on auto-hide so it tucks away while a game is open.
- **Settings.** 7 color themes (5 light, 2 dark), 3 card sizes, play inside the dashboard or in a new tab, a sound switch that also mutes embedded games, and a count of games found.
- **Keyboard shortcuts.** `/` focuses search, `←` / `→` switch games while playing, `H` hides or shows the header, `Esc` goes back to the grid.

## Playing on a phone or tablet

Open the live site, not a downloaded copy. Phones don't reliably run a folder of HTML files saved to storage: Android opens them through temporary `content://` addresses with no neighbouring files, and mobile browsers can't pick folders. The hosted site has none of those problems.

For offline use:

1. Open the live site once while online. **Settings → Offline copy** shows saving progress, then "Ready · N files".
2. After that it works with no signal, including after the browser is closed.
3. To add an icon to the home screen: on Android, use **Settings → Install app**. On iPhone or iPad, tap Share, then Add to Home Screen.

### What gets listed

Every file ending in `.html` or `.htm`, except:

- the root `index.html` (the dashboard itself),
- anything inside a folder whose name starts with `.`,
- anything inside `node_modules`.

Helper pages such as `404.html` will also get a card. Keep non-game pages out of the repo, or add an exclude rule in `index.html`.

## How it finds games

`index.html` is one static file. How it discovers games depends on where it's opened:

| Where it runs | How it finds games |
| --- | --- |
| GitHub Pages (or any `https://` host) | Reads the repo's file tree from the GitHub REST API (`/git/trees/main?recursive=1`). Results are cached for 10 minutes. If the device is offline, the last saved list is used. |
| `localhost` or a private network address, using `serve.py` | Reads `/__games.json` from `serve.py`, which lists every `.html` file in the repo. |
| `localhost` with another server | Falls back to reading directory listings, up to 5 folders deep, but only if the server actually shows listings (see below). |
| Opened as a file (`file://`) on a desktop browser | Asks you to choose the repo folder once, reads the titles and icons from it, and remembers the result. Press ↻ to choose it again after changes. |

## Running locally

Open `index.html` directly.** On a desktop browser, double-click it and choose the repo folder when asked. This doesn't work reliably on phones.

Muting sound inside embedded games works on `https://` and `localhost`, but not when opened as a file, because browsers don't let one local file reach into another.

## Repo files

| File | Purpose |
| --- | --- |
| `index.html` | The dashboard |
| `sw.js` | Service worker that makes offline use possible |
| `manifest.webmanifest` | Lets the site be installed as an app |
| `icon-192.png`, `icon-512.png`, `apple-touch-icon.png` | App icons |

## Known limitations

- **Repo, branch, and hosted address are hardcoded** in `index.html`: `REPO` (`KungPowUnicorn/map`), the `main` branch in the tree URL, and `HOSTED`. If you fork this, change all three.
- **Very large repos:** GitHub can truncate the file tree response. The Settings count notes when the list may be incomplete.
- **Embedded games share the same origin**, so two games using the same `localStorage` key can overwrite each other's saved data. Use unique keys per game.
- **Muting embedded games is best effort.** It works by intercepting Web Audio, `<audio>`/`<video>` playback, and speech synthesis in the game's page. Sound produced before the dashboard hooks in, or by a game that navigates to another origin, may not be muted.
- **Games that redirect the top window** (`window.top.location`) won't behave inside the embedded player. Turn off *Play inside dashboard* in Settings to open games in a new tab instead.
- **Downloaded copies on phones don't work.** See [Playing on a phone or tablet](#playing-on-a-phone-or-tablet).
- **New files can appear before Pages has deployed them.** If a card opens a blank page, wait a minute and try again.

## Support

If the Playhouse made someone's day, you can say thanks on [Ko-fi](https://ko-fi.com/kungpowunicorn).

## License

MIT. See [LICENSE](LICENSE).
