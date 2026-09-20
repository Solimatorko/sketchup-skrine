/* Pictograms for option cards. Style: white faces, dark outline, orange accent. */
/* exported ICONS */
const ICONS = (() => {
  const S = '#333';
  const A = '#f28c28';
  const svg = (body) => `<svg viewBox="0 0 48 48" width="48" height="48" fill="none" stroke="${S}" stroke-width="1.6" stroke-linejoin="round">${body}</svg>`;
  const cab = (x = 10, y = 8, w = 28, h = 32) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#fff"/>`;
  const wall = (x) => `<line x1="${x}" y1="4" x2="${x}" y2="44" stroke-width="3"/>`;
  const shelves = (x = 10, w = 28, ys = [18, 26, 34]) => ys.map((y) => `<line x1="${x}" y1="${y}" x2="${x + w}" y2="${y}"/>`).join('');
  const drawers = (x = 11, y = 22, w = 26, n = 3, h = 6) =>
    Array.from({ length: n }, (_, i) => `<rect x="${x}" y="${y + i * h}" width="${w}" height="${h - 1}" fill="#fff"/><line x1="${x + w / 2 - 4}" y1="${y + i * h + 2.5}" x2="${x + w / 2 + 4}" y2="${y + i * h + 2.5}" stroke="${A}" stroke-width="2"/>`).join('');
  const rod = (x = 12, w = 24, y = 16) => `<line x1="${x}" y1="${y}" x2="${x + w}" y2="${y}" stroke="${A}" stroke-width="2.5"/>` +
    [0, 8, 16].map((d) => `<path d="M${x + 4 + d} ${y} v3 l-3 5 h6 z" fill="#fff"/>`).join('');
  const dots = (x, ys) => ys.map((y) => `<circle cx="${x}" cy="${y}" r="1.6" fill="${A}" stroke="none"/>`).join('');
  const planSides = () => `<rect x="8" y="14" width="4" height="26" fill="#fff"/><rect x="36" y="14" width="4" height="26" fill="#fff"/>`;

  return {
    'placement.between_walls': svg(wall(6) + wall(42) + cab(10, 8, 28, 34)),
    'placement.corner_left': svg(wall(6) + cab(10, 8, 28, 34)),
    'placement.corner_right': svg(wall(42) + cab(10, 8, 28, 34)),
    'placement.free': svg(cab(10, 8, 28, 34)),

    'base.legs': svg(cab(10, 6, 28, 30) + `<rect x="13" y="36" width="3" height="6" fill="${A}" stroke="none"/><rect x="32" y="36" width="3" height="6" fill="${A}" stroke="none"/><line x1="6" y1="43" x2="42" y2="43"/>`),
    'base.plinth': svg(cab(10, 6, 28, 30) + `<rect x="13" y="36" width="22" height="6" fill="${A}" stroke="none"/><line x1="6" y1="43" x2="42" y2="43"/>`),
    'base.floor': svg(cab(10, 10, 28, 33) + '<line x1="6" y1="43" x2="42" y2="43"/>'),

    'back.groove': svg(planSides() + `<rect x="12" y="34" width="24" height="2" fill="${A}" stroke="none"/><line x1="8" y1="14" x2="40" y2="14" stroke-dasharray="2 2"/>`),
    'back.overlay': svg(planSides() + `<rect x="8" y="40" width="32" height="2" fill="${A}" stroke="none"/>`),
    'back.inset': svg(planSides() + `<rect x="12" y="34" width="24" height="5" fill="${A}" stroke="none"/>`),

    'doors.none': svg(cab() + shelves()),
    'doors.single_left': svg(cab() + `<rect x="12" y="10" width="24" height="28" fill="${A}" fill-opacity=".35"/>` + dots(14, [16, 32])),
    'doors.single_right': svg(cab() + `<rect x="12" y="10" width="24" height="28" fill="${A}" fill-opacity=".35"/>` + dots(34, [16, 32])),
    'doors.double': svg(cab() + `<rect x="12" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/><rect x="25" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/>` + dots(14, [16, 32]) + dots(34, [16, 32])),
    'doors.flap_up': svg(cab(10, 14, 28, 22) + `<path d="M12 16 L36 16 L36 6 L12 10 Z" fill="${A}" fill-opacity=".35"/><path d="M24 30 v-8 m-3 3 l3 -3 l3 3" stroke="${A}" stroke-width="2"/>`),

    'mount.overlay': svg(planSides() + `<rect x="8" y="10" width="32" height="4" fill="${A}" stroke="none"/>`),
    'mount.half_overlay': svg(planSides() + `<rect x="10" y="10" width="28" height="4" fill="${A}" stroke="none"/>`),
    'mount.inset': svg(planSides() + `<rect x="12" y="15" width="24" height="4" fill="${A}" stroke="none"/>`),

    'handle.none': svg(cab(12, 8, 24, 32)),
    'handle.drilled': svg(cab(12, 8, 24, 32) + `<line x1="18" y1="14" x2="30" y2="14" stroke="${A}" stroke-width="2.5"/>` + dots(18, [14]) + dots(30, [14])),
    'handle.profile': svg(cab(12, 12, 24, 28) + `<rect x="12" y="8" width="24" height="4" fill="${A}" stroke="none"/>`),

    'content.shelves': svg(cab() + shelves()),
    'content.rod': svg(cab() + rod()),
    'content.drawers': svg(cab() + drawers(11, 12, 26, 4, 7)),
    'content.inner_drawers': svg(cab() + `<rect x="12" y="10" width="24" height="28" stroke-dasharray="3 2"/>` + drawers(14, 20, 20, 2, 7)),
    'content.empty': svg(cab()),

    'system.front_only': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><line x1="12" y1="24" x2="40" y2="24" stroke-dasharray="3 2"/>`),
    'system.wood_box': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="16" width="26" height="16" fill="#e8dcc0"/>`),
    'system.blum_legrabox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="7" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">LEGRA</text>`),
    'system.blum_tandembox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="6" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">TANDEM</text>`),
    'system.blum_merivobox': svg(`<rect x="8" y="10" width="4" height="28" fill="${A}" stroke="none"/><rect x="12" y="14" width="26" height="18" fill="#dcdcdc"/><text x="25" y="27" font-size="6" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">MERIVO</text>`),

    'corner.inset': svg(`<rect x="10" y="8" width="6" height="32" fill="#fff"/><rect x="16" y="8" width="22" height="6" fill="${A}" fill-opacity=".5"/>`),
    'corner.overlay': svg(`<rect x="10" y="14" width="6" height="26" fill="#fff"/><rect x="10" y="8" width="28" height="6" fill="${A}" fill-opacity=".5"/>`),

    'joinery.none': svg(cab(10, 12, 28, 24)),
    'joinery.dowels': svg(cab(10, 12, 28, 24) + dots(24, [16, 32])),
    'joinery.confirmat': svg(cab(10, 12, 28, 24) + `<line x1="24" y1="14" x2="24" y2="34" stroke="${A}" stroke-width="2.5"/>`),
    'joinery.cam_lock': svg(cab(10, 12, 28, 24) + `<circle cx="24" cy="24" r="4" stroke="${A}" stroke-width="2"/>`),

    'mode.auto': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">auto</text>`),
    'mode.mm': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">mm</text>`),
    'mode.ratio': svg(`<text x="24" y="30" font-size="14" text-anchor="middle" fill="${S}" stroke="none" font-family="sans-serif">1 : n</text>`),

    'view.front': svg(cab() + `<rect x="12" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/><rect x="25" y="10" width="11" height="28" fill="${A}" fill-opacity=".35"/>`),
    'view.front_open': svg(cab() + shelves()),
    'view.side': svg(`<rect x="16" y="8" width="16" height="32" fill="#fff"/><rect x="14" y="8" width="2" height="32" fill="${A}" stroke="none"/>`),
    'view.plan': svg(`<rect x="8" y="14" width="32" height="20" fill="#fff"/><rect x="8" y="12" width="32" height="2" fill="${A}" stroke="none"/>`)
  };
})();
