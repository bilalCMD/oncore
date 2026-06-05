/* ONCORE — Shared JavaScript */

function toggleMobileMenu() {
  const menu = document.getElementById('mobileMenu');
  if (!menu) return;
  menu.classList.toggle('open');
  document.body.classList.toggle('menu-open', menu.classList.contains('open'));
}

document.addEventListener('click', (e) => {
  const menu = document.getElementById('mobileMenu');
  if (!menu || !menu.classList.contains('open')) return;
  if (e.target.closest('.mobile-menu .nav-link, .mobile-menu .btn')) {
    setTimeout(() => {
      menu.classList.remove('open');
      document.body.classList.remove('menu-open');
    }, 50);
  }
});

function showToast(message) {
  const toast = document.getElementById('toast');
  if (!toast) return;
  const msg = toast.querySelector('.toast-msg');
  if (msg) msg.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 4200);
}

// ─── Subtle scroll-reveal (only on pages with <body data-animate>) ───
document.addEventListener('DOMContentLoaded', () => {
  if (!document.body.hasAttribute('data-animate')) return;

  const selector = '.section-header, .feature-card, .disc-card, .mv-card, ' +
    '.value-card, .impact-band, .story-card, .collab-card, .research-card, ' +
    '.photo-card, .cta-inner, .about-hero-content';
  const items = Array.from(document.querySelectorAll(selector));
  if (!items.length || !('IntersectionObserver' in window)) return;

  items.forEach(el => el.classList.add('reveal'));

  const io = new IntersectionObserver((entries, obs) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      // Stagger siblings sharing the same parent for a smooth cascade
      const el = entry.target;
      const siblings = Array.from(el.parentElement.children).filter(c => c.classList.contains('reveal'));
      const idx = siblings.indexOf(el);
      el.style.setProperty('--reveal-delay', `${Math.min(idx, 5) * 0.08}s`);
      el.classList.add('in-view');
      obs.unobserve(el);
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  items.forEach(el => io.observe(el));
});
