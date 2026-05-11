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
