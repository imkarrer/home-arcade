const app = document.getElementById("app");
const navPlay = document.getElementById("nav-play");
const navSettings = document.getElementById("nav-settings");
const playerDiv = document.getElementById("player");

function route() {
  const hash = location.hash || "#/";
  const web = hash.match(/^#\/play\/([a-z0-9_]+)$/);
  navPlay.classList.toggle("active", hash === "#/" || !!web);
  navSettings.classList.toggle("active", hash === "#/settings");
  if (web) return openWebGame(web[1]);
  closeWebGame();
  if (hash === "#/settings") renderSettings();
  else renderPlay();
}

// Profiles roam: the same list on every PC, saves follow the profile.
async function renderPlayer() {
  try {
    const data = await api("/api/players");
    playerDiv.textContent = "Playing as ";
    const select = document.createElement("select");
    select.id = "player-select";
    for (const p of data.players) {
      const opt = document.createElement("option");
      opt.value = p.id;
      opt.textContent = p.name;
      opt.selected = p.id === data.current;
      select.appendChild(opt);
    }
    select.addEventListener("change", () => setPlayer({ id: select.value }));
    const add = document.createElement("button");
    add.id = "new-profile";
    add.textContent = "New profile";
    add.addEventListener("click", () => {
      const name = prompt("Name for the new profile?");
      if (name) setPlayer({ name });
    });
    playerDiv.append(select, " ", add);
  } catch (err) {
    playerDiv.innerHTML = '<p class="error"></p>';
    playerDiv.firstChild.textContent = err.message;
  }
}

async function setPlayer(body) {
  try {
    await api("/api/player", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
  } catch (err) {
    alert(err.message);
  }
  renderPlayer();
}

async function api(path, opts) {
  const res = await fetch(path, opts);
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (e) { data = { error: text }; }
  if (!res.ok) throw new Error((data && data.error) || res.statusText);
  return data;
}

// Every game is on one page, on the catalog's shelves in the catalog's order.
// A game on no shelf (or an agent too old to send shelves) goes in the last.
async function renderPlay() {
  app.innerHTML = "Loading…";
  try {
    const data = await api("/api/games");
    const shelves = (data.shelves || []).map((s) => ({ id: s.id, title: s.title, games: [] }));
    const more = { id: "more", title: shelves.length ? "More games" : "", games: [] };
    for (const game of data.games) {
      (shelves.find((s) => s.id === game.shelf) || more).games.push(game);
    }
    app.innerHTML = "";
    for (const shelf of shelves.concat(more)) {
      if (!shelf.games.length) continue;
      const section = document.createElement("section");
      section.className = "shelf shelf-" + shelf.id;
      if (shelf.title) {
        const h = document.createElement("h2");
        h.textContent = shelf.title;
        section.appendChild(h);
      }
      const grid = document.createElement("div");
      grid.className = "grid";
      for (const game of shelf.games) grid.appendChild(game.kind === "web" ? webCard(game) : gameCard(game));
      section.appendChild(grid);
      app.appendChild(section);
    }
  } catch (err) {
    app.innerHTML = '<p class="error">' + err.message + "</p>";
  }
}

function iconFor(game) {
  const span = document.createElement("span");
  span.className = "icon";
  span.setAttribute("aria-hidden", "true");
  span.textContent = game.icon || "🎮";
  return span;
}

function gameCard(game) {
  const card = document.createElement("div");
  card.className = "card" + (game.ready ? "" : " soon");
  const h = document.createElement("h3");
  h.className = "title";
  h.textContent = game.ready ? game.title : game.title + " (coming soon)";
  card.append(iconFor(game), h);
  const actions = document.createElement("div");
  actions.className = "actions";
  const modes = game.modes && game.modes.length ? game.modes : ["solo", "host", "join"];
  const labels = { solo: "Play", host: "Host", join: "Join" };
  const cls = { solo: "play", host: "host", join: "join" };
  for (const mode of modes) {
    const btn = document.createElement("button");
    btn.className = cls[mode] || "play";
    btn.textContent = (game.modeLabels && game.modeLabels[mode]) || labels[mode] || mode;
    btn.disabled = !game.ready;
    btn.addEventListener("click", () => play(game.id, mode));
    actions.appendChild(btn);
  }
  card.appendChild(actions);
  return card;
}

// A web game is one big button: the little ones it is for cannot aim at a
// small one.
function webCard(game) {
  const card = document.createElement("button");
  card.className = "card web" + (game.ready ? "" : " soon");
  card.disabled = !game.ready || !game.href;
  const title = document.createElement("span");
  title.className = "title";
  title.textContent = game.ready ? game.title : game.title + " (coming soon)";
  card.append(iconFor(game), title);
  if (game.online) {
    const note = document.createElement("span");
    note.className = "note";
    note.textContent = "Needs the internet";
    card.appendChild(note);
  }
  card.addEventListener("click", () => {
    // Fullscreen has to start in the click itself, so the browser's tabs and
    // the taskbar are out of reach before the game opens.
    const root = document.documentElement;
    if (root.requestFullscreen) root.requestFullscreen().catch(() => {});
    location.hash = "#/play/" + game.id;
  });
  return card;
}

// Web games play here, over the shelves. "Arcade" (bottom left, clear of the
// games' own buttons), Esc or Back closes one. The frame gets no fullscreen
// of its own, so a game that asks for it cannot cover that button.
async function openWebGame(id) {
  let game = null;
  try {
    game = (await api("/api/games")).games.find((g) => g.id === id);
  } catch (err) {
    alert(err.message);
  }
  if (location.hash !== "#/play/" + id) return;
  if (!game || !game.href) {
    location.hash = "#/";
    return;
  }
  closeWebGame(true);
  const layer = document.createElement("div");
  layer.id = "web-player";
  const frame = document.createElement("iframe");
  frame.src = game.href;
  frame.title = game.title;
  frame.allow = "autoplay";
  const back = document.createElement("button");
  back.id = "web-back";
  back.textContent = "⬅ Arcade";
  back.addEventListener("click", () => { location.hash = "#/"; });
  layer.append(frame, back);
  document.body.appendChild(layer);
  document.body.classList.add("playing");
  frame.focus();
}

function closeWebGame(keepFullscreen) {
  const layer = document.getElementById("web-player");
  if (layer) layer.remove();
  document.body.classList.remove("playing");
  if (!keepFullscreen && document.fullscreenElement) document.exitFullscreen().catch(() => {});
}

async function play(id, mode) {
  const settings = loadSettings();
  try {
    await api("/api/play", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: id,
        mode: mode,
        joinHost: settings.joinHost || "",
        bigScreen: settings.bigScreen !== false
      })
    });
  } catch (err) {
    alert(err.message);
  }
}

function loadSettings() {
  try { return JSON.parse(localStorage.getItem("arcade-settings") || "{}"); }
  catch (e) { return {}; }
}

function saveSettings(s) {
  localStorage.setItem("arcade-settings", JSON.stringify(s));
}

async function renderSettings() {
  app.innerHTML = "Loading…";
  const settings = loadSettings();
  try {
    const data = await api("/api/games");
    let html = '<div class="settings-block">';
    html += "<h2>This station</h2>";
    html += '<label>Join IP (other PC)</label>';
    html += '<input id="joinHost" value="' + (settings.joinHost || data.joinHost || "") + '">';
    html += '<label><input id="bigScreen" type="checkbox"' + ((settings.bigScreen !== false) ? " checked" : "") + "> Big screen for two-player races</label>";
    html += '<p><button class="save" id="saveStation">Save station</button></p>';
    html += "</div>";
    html += "<h2>Start file (dad)</h2>";
    html += "<p>Kids never see this. Pick the file that starts each DOS game once.</p>";
    for (const game of data.games) {
      if (game.core !== "dosbox_pure_libretro.dll") continue;
      html += '<div class="settings-block" data-id="' + game.id + '">';
      html += "<h3>" + game.title + "</h3>";
      html += '<label>Boot file</label>';
      html += '<select class="boot"></select>';
      html += '<p><button class="save save-boot">Save start file</button></p>';
      html += "</div>";
    }
    app.innerHTML = html;
    document.getElementById("saveStation").addEventListener("click", () => {
      saveSettings({
        joinHost: document.getElementById("joinHost").value.trim(),
        bigScreen: document.getElementById("bigScreen").checked
      });
    });
    for (const block of app.querySelectorAll("[data-id]")) {
      fillFiles(block, data.games.find((g) => g.id === block.getAttribute("data-id")));
    }
  } catch (err) {
    app.innerHTML = '<p class="error">' + err.message + "</p>";
  }
}

async function fillFiles(block, game) {
  const sel = block.querySelector(".boot");
  try {
    const data = await api("/api/files?id=" + encodeURIComponent(game.id));
    const files = data.files || [];
    if (!files.length) {
      sel.innerHTML = "<option>(no files yet)</option>";
      return;
    }
    sel.innerHTML = files.map((f) => {
      const pick = (game.boot && f.toLowerCase().endsWith(game.boot.toLowerCase())) || f.split(/[/\\]/).pop().toLowerCase() === String(game.boot || "").toLowerCase();
      return "<option" + (pick ? " selected" : "") + ">" + f + "</option>";
    }).join("");
  } catch (e) {
    sel.innerHTML = "<option>(could not list files)</option>";
  }
  block.querySelector(".save-boot").addEventListener("click", async () => {
    const boot = sel.value.split(/[/\\]/).pop();
    try {
      await api("/api/boot", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: game.id, boot: boot })
      });
    } catch (err) {
      alert(err.message);
    }
  });
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && document.getElementById("web-player")) location.hash = "#/";
});
window.addEventListener("hashchange", route);
renderPlayer();
route();
