// Time-of-day background theme — shared by all games
// Returns { grad: [color1, color2], stars: bool }
function getTimeTheme() {
  const h = new Date().getHours();
  if (h >= 22 || h < 5)  return { grad: ['#020818', '#0d0d2b'], stars: true  }; // night
  if (h >= 5  && h < 7)  return { grad: ['#1a1a4e', '#f4845f'], stars: true  }; // dawn
  if (h >= 7  && h < 12) return { grad: ['#1e90b8', '#5cb8d6'], stars: false }; // morning
  if (h >= 12 && h < 17) return { grad: ['#0e9e72', '#52b88a'], stars: false }; // afternoon
  if (h >= 17 && h < 20) return { grad: ['#c0392b', '#8e44ad'], stars: false }; // sunset
  return                         { grad: ['#2c2c72', '#1a1a4e'], stars: true  }; // evening
}

function applyTimeTheme(bgEl) {
  const { grad } = getTimeTheme();
  bgEl.style.background = `linear-gradient(160deg, ${grad[0]}, ${grad[1]})`;
}
