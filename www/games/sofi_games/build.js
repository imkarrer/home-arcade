const fs = require('fs');
const soundsDir = 'c:/Users/meira/sofi-games/sounds';
const animals = ['dog','cat','cow','duck','lion','elephant','frog','rooster','donkey'];
const sounds = {};
animals.forEach(name => {
  const b64 = fs.readFileSync(soundsDir + '/' + name + '_trim.ogg').toString('base64');
  sounds[name] = 'data:audio/ogg;base64,' + b64;
});
const soundsJS = 'const SOUNDS = ' + JSON.stringify(sounds) + ';';

const html = `<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <title>חיות ואקולות</title>
  <style>
    * { box-sizing:border-box; margin:0; padding:0; -webkit-tap-highlight-color:transparent; user-select:none; }
    html,body { width:100%; height:100%; overflow:hidden; background:#1a1a2e; font-family:'Arial Rounded MT Bold',Arial,sans-serif; }
    #app { width:100vw; height:100vh; display:flex; flex-direction:column; align-items:center; justify-content:center; position:relative; overflow:hidden; }
    #bg { position:absolute; inset:0; background:linear-gradient(135deg,#0f3460,#16213e,#0f3460); background-size:400% 400%; animation:bgShift 8s ease infinite; z-index:0; }
    @keyframes bgShift { 0%{background-position:0% 50%} 50%{background-position:100% 50%} 100%{background-position:0% 50%} }
    .star { position:absolute; background:white; border-radius:50%; animation:twinkle var(--dur) ease-in-out infinite; z-index:1; }
    @keyframes twinkle { 0%,100%{opacity:0.2;transform:scale(1)} 50%{opacity:1;transform:scale(1.4)} }
    #stage { position:relative; width:88vw; max-width:680px; height:72vh; z-index:10; }
    .card { position:absolute; inset:0; border-radius:40px; display:flex; flex-direction:column; align-items:center; justify-content:center; padding:30px 24px 20px; box-shadow:0 20px 60px rgba(0,0,0,0.5); cursor:pointer; will-change:transform; touch-action:pan-y; }
    .card.animating { transition:transform 0.35s cubic-bezier(0.25,0.46,0.45,0.94), opacity 0.35s ease; }
    .card-emoji { font-size:min(30vw,220px); line-height:1; transition:transform 0.15s ease; filter:drop-shadow(0 8px 20px rgba(0,0,0,0.4)); }
    .card.pressed .card-emoji { transform:scale(1.12) rotate(-4deg); }
    .card-name { font-size:clamp(28px,7vw,56px); font-weight:900; color:white; text-shadow:0 3px 10px rgba(0,0,0,0.5); margin-top:18px; letter-spacing:2px; }
    .ripple-ring { position:absolute; border-radius:50%; border:4px solid rgba(255,255,255,0.7); animation:expandRing 0.8s ease-out forwards; pointer-events:none; z-index:20; }
    @keyframes expandRing { 0%{width:80px;height:80px;opacity:0.9;margin:-40px} 100%{width:340px;height:340px;opacity:0;margin:-170px} }
    .arrow { position:absolute; top:50%; transform:translateY(-50%); font-size:44px; color:rgba(255,255,255,0.25); z-index:10; pointer-events:none; animation:pulse 2.5s ease-in-out infinite; }
    .arrow.left { left:4px; } .arrow.right { right:4px; }
    @keyframes pulse { 0%,100%{opacity:0.25;transform:translateY(-50%) scale(1)} 50%{opacity:0.65;transform:translateY(-50%) scale(1.2)} }
    #dots { display:flex; gap:12px; margin-top:22px; z-index:10; position:relative; }
    .dot { width:16px; height:16px; border-radius:50%; background:rgba(255,255,255,0.3); transition:background 0.3s,transform 0.3s; }
    .dot.active { background:white; transform:scale(1.4); }
    .float-emoji { position:fixed; font-size:48px; pointer-events:none; z-index:50; animation:floatUp 1.4s ease-out forwards; }
    @keyframes floatUp { 0%{transform:translateY(0) scale(0.5) rotate(-10deg);opacity:1} 60%{transform:translateY(-140px) scale(1.1) rotate(8deg);opacity:1} 100%{transform:translateY(-220px) scale(0.8) rotate(0);opacity:0} }
  </style>
</head>
<body>
<div id="app">
  <div id="bg"></div>
  <div class="arrow left">&#9664;</div>
  <div class="arrow right">&#9654;</div>
  <div id="stage"></div>
  <div id="dots"></div>
</div>
<script>
${soundsJS}

function pigOink() {
  const ctx = new (window.AudioContext || window.webkitAudioContext)();
  function oink(t, freq, dur) {
    const osc = ctx.createOscillator(), gain = ctx.createGain();
    osc.connect(gain); gain.connect(ctx.destination);
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, t);
    osc.frequency.exponentialRampToValueAtTime(freq * 1.6, t + dur * 0.4);
    osc.frequency.exponentialRampToValueAtTime(freq * 0.7, t + dur);
    gain.gain.setValueAtTime(0.4, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.start(t); osc.stop(t + dur + 0.05);
  }
  const now = ctx.currentTime;
  oink(now, 220, 0.22);
  oink(now + 0.28, 260, 0.2);
}

const ANIMALS = [
  { name:'כלב',    emoji:'🐶', bg:['#e8603c','#f5a623'], sound:'dog',      floats:['🦴','🐾','💛'] },
  { name:'חתול',   emoji:'🐱', bg:['#9b59b6','#e056fd'], sound:'cat',      floats:['🐟','🧶','💜'] },
  { name:'פרה',    emoji:'🐮', bg:['#27ae60','#2ecc71'], sound:'cow',      floats:['🌿','🥛','💚'] },
  { name:'ברווז',  emoji:'🦆', bg:['#3498db','#74b9ff'], sound:'duck',     floats:['💧','🌊','💙'] },
  { name:'אריה',   emoji:'🦁', bg:['#e67e22','#f9ca24'], sound:'lion',     floats:['⭐','👑','🧡'] },
  { name:'פיל',    emoji:'🐘', bg:['#636e72','#b2bec3'], sound:'elephant', floats:['🥜','🌴','🩶'] },
  { name:'צפרדע',  emoji:'🐸', bg:['#00b894','#55efc4'], sound:'frog',     floats:['🪲','💧','🟢'] },
  { name:'חזיר',   emoji:'🐷', bg:['#fd79a8','#e84393'], sound:'pig',      floats:['🌸','🍎','🩷'] },
  { name:'תרנגול', emoji:'🐓', bg:['#fdcb6e','#e17055'], sound:'rooster',  floats:['🌞','🥚','⭐'] },
  { name:'חמור',   emoji:'🫏', bg:['#a29bfe','#6c5ce7'], sound:'donkey',   floats:['🌾','🏔️','💜'] },
];

let current = 0, isDragging = false, startX = 0, dragX = 0;
const MIN_SWIPE = 80;
const stage = document.getElementById('stage');
const dotsEl = document.getElementById('dots');

let currentAudio = null;
function playSound(name) {
  if (currentAudio) { currentAudio.pause(); currentAudio.currentTime = 0; currentAudio = null; }
  if (name === 'pig') { pigOink(); return; }
  if (SOUNDS[name]) {
    currentAudio = new Audio(SOUNDS[name]);
    currentAudio.play().catch(() => {});
  }
}

(function buildStars() {
  const bg = document.getElementById('bg');
  for (let i = 0; i < 60; i++) {
    const s = document.createElement('div');
    s.className = 'star';
    const sz = Math.random() * 3 + 1;
    s.style.cssText = 'width:'+sz+'px;height:'+sz+'px;top:'+(Math.random()*100)+'%;left:'+(Math.random()*100)+'%;--dur:'+(Math.random()*3+2).toFixed(1)+'s;animation-delay:'+(Math.random()*4).toFixed(1)+'s';
    bg.appendChild(s);
  }
})();

function buildDots() {
  dotsEl.innerHTML = '';
  ANIMALS.forEach(function(_,i) {
    const d = document.createElement('div');
    d.className = 'dot' + (i === current ? ' active' : '');
    dotsEl.appendChild(d);
  });
}

function makeCard(index) {
  const a = ANIMALS[index];
  const card = document.createElement('div');
  card.className = 'card';
  card.style.background = 'linear-gradient(145deg,' + a.bg[0] + ',' + a.bg[1] + ')';
  card.innerHTML = '<div class="card-emoji">' + a.emoji + '</div><div class="card-name">' + a.name + '</div>';
  return card;
}

function showRipple(card) {
  const r = document.createElement('div');
  r.className = 'ripple-ring';
  r.style.left = '50%'; r.style.top = '45%';
  card.appendChild(r);
  r.addEventListener('animationend', function(){ r.remove(); });
}

function floatEmojis(x, y, floats) {
  floats.forEach(function(em,i) {
    const el = document.createElement('div');
    el.className = 'float-emoji';
    el.textContent = em;
    el.style.left = (x + (i-1)*55) + 'px';
    el.style.top  = y + 'px';
    el.style.animationDelay = (i * 0.12) + 's';
    document.body.appendChild(el);
    el.addEventListener('animationend', function(){ el.remove(); });
  });
}

let activeCard = null;
function renderCurrent() {
  if (activeCard) activeCard.remove();
  const card = makeCard(current);
  stage.appendChild(card);
  activeCard = card;
  attachCardEvents(card);
  buildDots();
}

function slideTo(newIndex, direction) {
  if (newIndex === current) return;
  const outCard = activeCard;
  const inCard  = makeCard(newIndex);
  inCard.style.transform = 'translateX(' + (direction * 110) + '%)';
  stage.appendChild(inCard);
  activeCard = inCard;
  current = newIndex;
  inCard.getBoundingClientRect();
  outCard.classList.add('animating');
  inCard.classList.add('animating');
  outCard.style.transform = 'translateX(' + (direction * -110) + '%)';
  outCard.style.opacity = '0';
  inCard.style.transform = 'translateX(0)';
  inCard.addEventListener('transitionend', function() {
    outCard.remove();
    inCard.classList.remove('animating');
    attachCardEvents(inCard);
  }, { once: true });
  buildDots();
}

function attachCardEvents(card) {
  let tapStartX = 0, tapStartY = 0, tapTime = 0;
  card.addEventListener('pointerdown', function(e) {
    tapStartX = e.clientX; tapStartY = e.clientY;
    tapTime = Date.now(); startX = e.clientX; dragX = 0;
    isDragging = true;
    card.setPointerCapture(e.pointerId);
    card.classList.add('pressed');
  });
  card.addEventListener('pointermove', function(e) {
    if (!isDragging) return;
    dragX = e.clientX - startX;
    if (Math.abs(dragX) > 12)
      card.style.transform = 'translateX(' + (dragX * 0.45) + 'px) rotate(' + (dragX * 0.012) + 'deg)';
  });
  card.addEventListener('pointerup', function(e) {
    if (!isDragging) return;
    isDragging = false;
    card.classList.remove('pressed');
    card.style.transform = '';
    const dx = e.clientX - tapStartX, dy = e.clientY - tapStartY;
    const dist = Math.sqrt(dx*dx + dy*dy);
    const dt = Date.now() - tapTime;
    if (dist < 20 && dt < 600) {
      playSound(ANIMALS[current].sound);
      showRipple(card);
      floatEmojis(e.clientX, e.clientY, ANIMALS[current].floats);
    } else if (Math.abs(dragX) >= MIN_SWIPE) {
      if (dragX < 0) slideTo((current + 1) % ANIMALS.length, 1);
      else           slideTo((current - 1 + ANIMALS.length) % ANIMALS.length, -1);
    }
    dragX = 0;
  });
  card.addEventListener('pointercancel', function() {
    isDragging = false;
    card.classList.remove('pressed');
    card.style.transform = '';
    dragX = 0;
  });
}

renderCurrent();
</script>
</body>
</html>`;

fs.writeFileSync('c:/Users/meira/sofi-games/animals.html', html, 'utf8');
const size = fs.statSync('c:/Users/meira/sofi-games/animals.html').size;
console.log('Written:', size, 'bytes (' + (size/1024).toFixed(1) + ' KB)');
