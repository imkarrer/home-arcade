const app = document.getElementById("app");
const navPlay = document.getElementById("nav-play");
const navSettings = document.getElementById("nav-settings");

function route() {
  const hash = location.hash || "#/";
  navPlay.classList.toggle("active", hash === "#/");
  navSettings.classList.toggle("active", hash === "#/settings");
  if (hash === "#/settings") renderSettings();
  else renderPlay();
}

async function api(path, opts) {
  const res = await fetch(path, opts);
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (e) { data = { error: text }; }
  if (!res.ok) throw new Error((data && data.error) || res.statusText);
  return data;
}

async function renderPlay() {
  app.innerHTML = "Loading…";
  try {
    const data = await api("/api/games");
    const grid = document.createElement("div");
    grid.className = "grid";
    for (const game of data.games) {
      const card = document.createElement("div");
      card.className = "card" + (game.ready ? "" : " soon");
      const h = document.createElement("h2");
      h.textContent = game.ready ? game.title : game.title + " (coming soon)";
      card.appendChild(h);
      const actions = document.createElement("div");
      actions.className = "actions";
      const modes = game.modes && game.modes.length ? game.modes : ["solo", "host", "join"];
      const labels = { solo: "Play", host: "Host", join: "Join" };
      const cls = { solo: "play", host: "host", join: "join" };
      for (const mode of modes) {
        const btn = document.createElement("button");
        btn.className = cls[mode] || "play";
        btn.textContent = labels[mode] || mode;
        btn.disabled = !game.ready;
        btn.addEventListener("click", () => play(game.id, mode));
        actions.appendChild(btn);
      }
      card.appendChild(actions);
      grid.appendChild(card);
    }
    app.innerHTML = "";
    app.appendChild(grid);
  } catch (err) {
    app.innerHTML = '<p class="error">' + err.message + "</p>";
  }
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

window.addEventListener("hashchange", route);
route();
