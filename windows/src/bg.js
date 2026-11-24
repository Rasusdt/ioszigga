(function drawBg() {
  const canvas = document.getElementById('bg');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  function resize() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    render();
  }
  function render() {
    const w = window.innerWidth, h = window.innerHeight;
    ctx.fillStyle = '#05070D';
    ctx.fillRect(0, 0, w, h);
    const cx = w * 1.02, cy = h * 1.02;
    const radius = Math.max(w, h) * 1.10;
    const grd = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
    grd.addColorStop(0, 'rgba(156,182,228,0.40)');
    grd.addColorStop(0.34, 'rgba(118,144,190,0.16)');
    grd.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);
    const step = 7;
    const rx = w * 1.25, ry = h * 0.92;
    for (let y = step / 2; y < h; y += step) {
      for (let x = step / 2; x < w; x += step) {
        const dx = (x - cx) / rx;
        const dy = (y - cy) / ry;
        const d = Math.min(1, Math.sqrt(dx*dx + dy*dy));
        const f = Math.pow(1 - d, 1.75);
        const vertical = Math.min(1, 0.45 + 0.55 * (1 - (y / h) * 0.35));
        const alpha = (0.075 + 0.925 * f) * vertical;
        if (alpha > 0.06) {
          const r = 0.9 + 0.95 * f;
          const rr = Math.round(25 + 62 * f);
          const gg = Math.round(36 + 55 * f);
          const bb = Math.round(54 + 46 * f);
          ctx.fillStyle = `rgba(${rr},${gg},${bb},${alpha})`;
          ctx.beginPath();
          ctx.arc(x, y, r, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
    const vg = ctx.createLinearGradient(0, 0, 0, h);
    vg.addColorStop(0, 'rgba(0,0,0,0.30)');
    vg.addColorStop(0.5, 'rgba(0,0,0,0.04)');
    vg.addColorStop(1, 'rgba(5,7,13,0.60)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, w, h);
  }
  window.addEventListener('resize', resize);
  resize();
})();
