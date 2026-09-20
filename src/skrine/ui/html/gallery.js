/* Wardrobe gallery overlay (presets with thumbnails). */
/* global Drawing */
/* exported Gallery */
const Gallery = {
  show(list, { onApply, onNew }) {
    const overlay = document.getElementById('gallery');
    const grid = overlay.querySelector('.grid');
    grid.innerHTML = '';
    overlay.classList.remove('hidden');
    list.forEach((entry) => {
      const card = document.createElement('div'); card.className = 'gcard';
      const h = document.createElement('h4'); h.textContent = entry.name; card.appendChild(h);
      const thumb = document.createElement('div'); thumb.className = 'thumb'; card.appendChild(thumb);
      const row = document.createElement('div'); row.className = 'btnrow';
      const bApply = document.createElement('button'); bApply.type = 'button'; bApply.textContent = 'Použiť na túto skriňu';
      bApply.onclick = () => { this.hide(); onApply(entry.file); };
      const bNew = document.createElement('button'); bNew.type = 'button'; bNew.textContent = 'Vytvoriť novú';
      bNew.onclick = () => { this.hide(); onNew(entry.file); };
      row.appendChild(bApply); row.appendChild(bNew); card.appendChild(row);
      grid.appendChild(card);
      Drawing.render(thumb, entry.scene, { view: 'front', interactive: false });
    });
    if (!list.length) grid.innerHTML = '<p>Žiadne presety.</p>';
  },
  hide() { document.getElementById('gallery').classList.add('hidden'); }
};
