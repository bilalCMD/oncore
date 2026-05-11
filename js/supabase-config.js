// ═══════════════════════════════════════════════════════════
// SUPABASE CONFIG — Shared across all pages
// ═══════════════════════════════════════════════════════════

const SUPABASE_URL = 'https://imwgyunypcnlcpiayjfh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imltd2d5dW55cGNubGNwaWF5amZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyOTI0ODEsImV4cCI6MjA5Mzg2ODQ4MX0.lYEWFoZStLVI4II_KOgK_1euwXyegrfCQBKTltiXgRg';

// Initialize Supabase client (loaded from CDN in HTML)
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});

// ═══════════════════════════════════════════════════════════
// AUTH HELPERS
// ═══════════════════════════════════════════════════════════

async function getCurrentUser() {
  const { data: { user } } = await supabaseClient.auth.getUser();
  return user;
}

// Tries up to 3 times with backoff — handles race condition where
// the DB trigger that creates the profile hasn't fired yet right
// after signup. As a fallback we self-insert if still missing.
async function getCurrentProfile() {
  const user = await getCurrentUser();
  if (!user) return null;

  for (let attempt = 0; attempt < 3; attempt++) {
    const { data, error } = await supabaseClient
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    if (data) return data;
    if (error && error.code !== 'PGRST116') {
      console.error('Profile fetch error:', error);
    }

    // Fallback: profile might not exist yet (trigger not fired). Try self-insert.
    if (attempt === 1) {
      const meta = user.user_metadata || {};
      await supabaseClient.from('profiles').insert({
        id: user.id,
        email: user.email,
        full_name: meta.full_name || '',
        role: meta.role || 'student',
        is_admin: false
      }).select().maybeSingle();
    }

    await new Promise(r => setTimeout(r, 400 * (attempt + 1)));
  }
  return null;
}

async function isAdmin() {
  const profile = await getCurrentProfile();
  return profile?.is_admin === true;
}

async function logout() {
  await supabaseClient.auth.signOut();
  window.location.href = 'index.html';
}

// ═══════════════════════════════════════════════════════════
// HEADER LOGIN STATUS — updates header based on login state
// ═══════════════════════════════════════════════════════════

async function updateHeaderAuth() {
  const user = await getCurrentUser();
  const loginBtn = document.getElementById('headerLoginBtn');
  const userMenu = document.getElementById('headerUserMenu');

  if (user) {
    const profile = await getCurrentProfile();
    const isAdminUser = profile?.is_admin === true;

    if (loginBtn) loginBtn.style.display = 'none';

    if (userMenu) {
      userMenu.style.display = 'flex';
      const dashboardLink = isAdminUser ? 'admin.html' : 'dashboard.html';
      const dashboardLabel = isAdminUser ? 'Admin Panel' : 'My Dashboard';
      userMenu.innerHTML = `
        <a href="${dashboardLink}" class="nav-link" style="display:flex;align-items:center;gap:6px;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          ${dashboardLabel}
        </a>
        <button onclick="logout()" class="btn btn-outline" style="padding:8px 16px;font-size:14px;">Logout</button>
      `;
    }
  } else {
    if (loginBtn) loginBtn.style.display = 'flex';
    if (userMenu) userMenu.style.display = 'none';
  }
}

// Auto-run on page load
document.addEventListener('DOMContentLoaded', updateHeaderAuth);
