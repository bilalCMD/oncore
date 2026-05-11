-- ═══════════════════════════════════════════════════════════════════
-- ONCORE — Make a user admin
-- ═══════════════════════════════════════════════════════════════════
-- Pehle website pe signup karo apni email se. Phir Supabase SQL Editor
-- mein yeh file open karo, neeche apni email daalo, aur RUN dabao.
-- ═══════════════════════════════════════════════════════════════════

UPDATE public.profiles
SET is_admin = TRUE,
    role     = 'admin'
WHERE email = 'YOUR_EMAIL_HERE@example.com';   -- ← yahan apni email likho

-- Verify (yeh row dikhna chahiye is_admin=true ke saath)
SELECT id, email, full_name, role, is_admin
FROM public.profiles
WHERE email = 'YOUR_EMAIL_HERE@example.com';
