// Tap score + all-time best per game, saved in localStorage.
// Usage: const SCORE = initScore('bubbles'); SCORE.add();
(function () {
  const css = document.createElement('style');
  css.textContent = [
    '#scorebox { position:fixed; top:14px; left:50%; transform:translateX(-50%);',
    '  z-index:998; display:flex; gap:20px; align-items:center;',
    '  background:rgba(0,0,0,0.35); border-radius:999px; padding:8px 24px;',
    "  font-family:'Arial Rounded MT Bold',Arial,sans-serif; pointer-events:none; }",
    '.score-item { display:flex; gap:8px; align-items:center; color:white;',
    '  font-weight:900; font-size:clamp(20px,4vw,32px);',
    '  text-shadow:0 2px 6px rgba(0,0,0,0.5); }',
    '.score-item span { display:inline-block; min-width:1.2em; text-align:center; }',
    '.score-item span.bump { animation:scoreBump 0.25s ease; }',
    '@keyframes scoreBump { 50% { transform:scale(1.5); } }',
  ].join('\n');
  document.head.appendChild(css);
})();

function initScore(gameKey) {
  const KEY = 'best_' + gameKey;
  let score = 0;
  let best = parseInt(localStorage.getItem(KEY) || '0', 10) || 0;

  const box = document.createElement('div');
  box.id = 'scorebox';
  box.innerHTML =
    '<div class="score-item">⭐<span id="score-cur">0</span></div>' +
    '<div class="score-item">🏆<span id="score-best">' + best + '</span></div>';
  document.body.appendChild(box);

  const curEl  = box.querySelector('#score-cur');
  const bestEl = box.querySelector('#score-best');

  function bump(el) {
    el.classList.remove('bump');
    void el.offsetWidth; // restart animation
    el.classList.add('bump');
  }

  return {
    add(n) {
      score += (n || 1);
      curEl.textContent = score;
      bump(curEl);
      if (score > best) {
        best = score;
        bestEl.textContent = best;
        bump(bestEl);
        try { localStorage.setItem(KEY, String(best)); } catch (e) {}
      }
    }
  };
}
