// A web game's saves belong to the profile playing it, not to this PC.
// arcade-agent.ps1 puts this ahead of every game page under games/, after
// window.__arcadeSaves = { player, game, data: <base64 of the profile's
// saves\<player>\web\<game>.json> }. The game's localStorage becomes that
// file: what it saves is posted back to the agent and roams with the profile.
// The frames of one game (Mika's menu and the game inside it) share one
// store, so neither overwrites what the other saved.
(function () {
  const boot = window.__arcadeSaves;
  if (!boot) return;
  let store = null;
  try {
    const up = window.parent !== window ? window.parent.__arcadeStore : null;
    if (up && up.game === boot.game && up.player === boot.player) store = up;
  } catch (e) { /* the page above is another site's: keep our own */ }
  if (!store) store = newStore(boot);
  window.__arcadeStore = store;

  const storage = {
    getItem: (k) => store.get(String(k)),
    setItem: (k, v) => store.set(String(k), String(v)),
    removeItem: (k) => store.remove(String(k)),
    clear: () => store.clear(),
    key: (i) => store.key(i),
    get length() { return store.size(); }
  };
  try {
    Object.defineProperty(window, "localStorage", { configurable: true, get: () => storage });
  } catch (e) { /* the browser's own then: per PC, but the game still works */ }
  window.addEventListener("pagehide", () => store.flush());

  function newStore(b) {
    const map = new Map();
    try {
      const bytes = Uint8Array.from(atob(b.data || ""), (c) => c.charCodeAt(0));
      const saved = JSON.parse(new TextDecoder().decode(bytes) || "{}");
      for (const k of Object.keys(saved)) map.set(k, String(saved[k]));
    } catch (e) { /* unreadable saves: start fresh rather than not start */ }
    let timer = null;
    const s = {
      game: b.game,
      player: b.player,
      get: (k) => (map.has(k) ? map.get(k) : null),
      set(k, v) { map.set(k, v); later(); },
      remove(k) { map.delete(k); later(); },
      clear() { map.clear(); later(); },
      key: (i) => { const keys = Array.from(map.keys()); return i < keys.length ? keys[i] : null; },
      size: () => map.size,
      // What is not posted yet, as a request; Home Arcade sends it itself when
      // it closes the game, because this frame's own requests die with it.
      take() {
        if (!timer) return null;
        clearTimeout(timer);
        timer = null;
        return {
          url: "/api/websave?game=" + encodeURIComponent(s.game) + "&player=" + encodeURIComponent(s.player),
          body: JSON.stringify(Object.fromEntries(map))
        };
      },
      flush() {
        const t = s.take();
        if (!t) return;
        fetch(t.url, {
          method: "POST",
          keepalive: true,
          headers: { "Content-Type": "application/json; charset=utf-8" },
          body: t.body
        }).catch(() => {});
      }
    };
    // A tap can set a best score many times a second: post once it settles.
    function later() { if (!timer) timer = setTimeout(() => s.flush(), 250); }
    return s;
  }
})();
