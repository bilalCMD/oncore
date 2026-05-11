-- ═══════════════════════════════════════════════════════════════════
-- ONCORE — COMPLETE DATABASE SETUP (one-shot, run-anytime safe)
-- ═══════════════════════════════════════════════════════════════════
-- Yeh single file hai jo SAARA database setup karta hai.
-- Supabase Dashboard → SQL Editor mein paste karke RUN dabao.
-- Safe to run multiple times — sab kuch IF NOT EXISTS / OR REPLACE hai.
-- ═══════════════════════════════════════════════════════════════════


-- ─── 1. PROFILES TABLE ────────────────────────────────────────────
-- Har authenticated user ka extended profile (role, name, etc.)
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT UNIQUE NOT NULL,
  full_name    TEXT DEFAULT '',
  role         TEXT DEFAULT 'student' CHECK (role IN ('student', 'doctor', 'admin')),
  is_admin     BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);


-- ─── 2. PROJECTS TABLE ────────────────────────────────────────────
-- Doctors/faculty post their research opportunities here.
CREATE TABLE IF NOT EXISTS public.projects (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id           UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title               TEXT NOT NULL,
  description         TEXT,
  discipline          TEXT,
  required_skills     TEXT[] DEFAULT '{}',
  status              TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Backfill columns that might be missing on existing tables
ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS min_year_of_study INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS min_gpa DECIMAL(3,2) DEFAULT 0;


-- ─── 3. APPLICATIONS TABLE ────────────────────────────────────────
-- Students apply here. Each row = one application to one project.
CREATE TABLE IF NOT EXISTS public.applications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id          UUID REFERENCES public.projects(id) ON DELETE SET NULL,
  discipline          TEXT,
  skills              TEXT[] DEFAULT '{}',
  year_of_study       TEXT,
  gpa                 TEXT,
  publications        INT DEFAULT 0,
  research_interest   TEXT,
  status              TEXT DEFAULT 'pending' CHECK (status IN ('pending','matched','approved','rejected')),
  match_score         INT,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Backfill columns that might be missing
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS disciplines  TEXT[],
  ADD COLUMN IF NOT EXISTS notes        TEXT,
  ADD COLUMN IF NOT EXISTS admin_note   TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by  UUID REFERENCES auth.users(id);


-- ═══════════════════════════════════════════════════════════════════
-- 4. AUTO-CREATE PROFILE WHEN USER SIGNS UP
-- Yeh trigger har naye Supabase auth user ke liye automatically
-- profiles row banata hai (signup metadata se name + role uthata hai).
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_admin)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
    FALSE
  )
  ON CONFLICT (id) DO UPDATE
    SET full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
        role      = COALESCE(EXCLUDED.role,      public.profiles.role);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ═══════════════════════════════════════════════════════════════════
-- 5. AUTO MATCH-SCORE CALCULATION
-- Jab application insert/update ho, match_score automatically calculate
-- ho jaye based on discipline, skills, year, GPA, publications.
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.calculate_match_score()
RETURNS TRIGGER AS $$
DECLARE
  proj          public.projects%ROWTYPE;
  score         INT := 0;
  skill_overlap INT := 0;
  year_num      INT := 0;
  gpa_num       NUMERIC := 0;
BEGIN
  -- Discipline base score
  IF NEW.discipline IS NOT NULL THEN
    score := score + 20;
  END IF;

  -- If linked to a project, do detailed match
  IF NEW.project_id IS NOT NULL THEN
    SELECT * INTO proj FROM public.projects WHERE id = NEW.project_id;
    IF FOUND THEN
      -- Discipline match (40)
      IF proj.discipline = NEW.discipline THEN
        score := score + 40;
      END IF;
      -- Skill overlap (up to 30)
      IF NEW.skills IS NOT NULL AND proj.required_skills IS NOT NULL THEN
        SELECT COUNT(*) INTO skill_overlap
          FROM unnest(NEW.skills) s
          WHERE s = ANY(proj.required_skills);
        score := score + LEAST(skill_overlap * 10, 30);
      END IF;
    END IF;
  END IF;

  -- Year of study (15)
  BEGIN
    year_num := NULLIF(REGEXP_REPLACE(COALESCE(NEW.year_of_study,''), '[^0-9]', '', 'g'), '')::INT;
    IF year_num >= 4 THEN score := score + 15;
    ELSIF year_num >= 2 THEN score := score + 10;
    ELSE score := score + 5;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    score := score + 5;
  END;

  -- GPA (10)
  BEGIN
    gpa_num := NULLIF(REGEXP_REPLACE(COALESCE(NEW.gpa,''), '[^0-9.]', '', 'g'), '')::NUMERIC;
    IF gpa_num >= 3.7 THEN score := score + 10;
    ELSIF gpa_num >= 3.3 THEN score := score + 7;
    ELSIF gpa_num >= 3.0 THEN score := score + 4;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    score := score + 0;
  END;

  -- Publications (5)
  IF COALESCE(NEW.publications, 0) > 0 THEN
    score := score + LEAST(NEW.publications * 2, 5);
  END IF;

  NEW.match_score := LEAST(score, 100);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS calc_match_score ON public.applications;
CREATE TRIGGER calc_match_score
  BEFORE INSERT OR UPDATE OF discipline, skills, year_of_study, gpa, publications, project_id
  ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.calculate_match_score();


-- ═══════════════════════════════════════════════════════════════════
-- 6. ROW LEVEL SECURITY (RLS)
-- Yeh sabse zaroori part hai — bina iske login kaam nahi karta!
-- Yeh policies decide karti hain ke kaun kya read/write kar sakta hai.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE public.profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications  ENABLE ROW LEVEL SECURITY;

-- Helper: check if current user is admin (avoids recursion on profiles)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;


-- ─── PROFILES policies ───
DROP POLICY IF EXISTS "profiles_select_all"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_self"  ON public.profiles;

-- Anyone authenticated can read all profiles (needed for joins on admin/dashboard)
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT TO authenticated USING (TRUE);

-- Users can update their own profile
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid() AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid()));

-- Admin can update any profile (including is_admin flag)
CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Allow profile self-insert (fallback if trigger didn't fire)
CREATE POLICY "profiles_insert_self" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());


-- ─── PROJECTS policies ───
DROP POLICY IF EXISTS "projects_public_read"   ON public.projects;
DROP POLICY IF EXISTS "projects_owner_read"    ON public.projects;
DROP POLICY IF EXISTS "projects_admin_read"    ON public.projects;
DROP POLICY IF EXISTS "projects_doctor_insert" ON public.projects;
DROP POLICY IF EXISTS "projects_owner_update"  ON public.projects;
DROP POLICY IF EXISTS "projects_admin_update"  ON public.projects;
DROP POLICY IF EXISTS "projects_admin_delete"  ON public.projects;

-- Public can see APPROVED projects only (research.html main page)
CREATE POLICY "projects_public_read" ON public.projects
  FOR SELECT TO anon, authenticated
  USING (status = 'approved');

-- Owner can see their own projects regardless of status (dashboard)
CREATE POLICY "projects_owner_read" ON public.projects
  FOR SELECT TO authenticated
  USING (doctor_id = auth.uid());

-- Admin can see ALL projects (admin panel)
CREATE POLICY "projects_admin_read" ON public.projects
  FOR SELECT TO authenticated
  USING (public.is_admin());

-- Authenticated doctor can post a project (status defaults to pending)
CREATE POLICY "projects_doctor_insert" ON public.projects
  FOR INSERT TO authenticated
  WITH CHECK (doctor_id = auth.uid());

-- Owner can update their own project
CREATE POLICY "projects_owner_update" ON public.projects
  FOR UPDATE TO authenticated
  USING (doctor_id = auth.uid());

-- Admin can update any project (publish/reject)
CREATE POLICY "projects_admin_update" ON public.projects
  FOR UPDATE TO authenticated
  USING (public.is_admin());

-- Admin can delete projects
CREATE POLICY "projects_admin_delete" ON public.projects
  FOR DELETE TO authenticated
  USING (public.is_admin());


-- ─── APPLICATIONS policies ───
DROP POLICY IF EXISTS "apps_student_read"  ON public.applications;
DROP POLICY IF EXISTS "apps_doctor_read"   ON public.applications;
DROP POLICY IF EXISTS "apps_admin_read"    ON public.applications;
DROP POLICY IF EXISTS "apps_student_insert" ON public.applications;
DROP POLICY IF EXISTS "apps_admin_update"  ON public.applications;
DROP POLICY IF EXISTS "apps_student_update" ON public.applications;

-- Student can read their own applications
CREATE POLICY "apps_student_read" ON public.applications
  FOR SELECT TO authenticated
  USING (student_id = auth.uid());

-- Doctor can read applications to THEIR projects
CREATE POLICY "apps_doctor_read" ON public.applications
  FOR SELECT TO authenticated
  USING (
    project_id IN (SELECT id FROM public.projects WHERE doctor_id = auth.uid())
  );

-- Admin can read all applications
CREATE POLICY "apps_admin_read" ON public.applications
  FOR SELECT TO authenticated
  USING (public.is_admin());

-- Student can submit applications for themselves
CREATE POLICY "apps_student_insert" ON public.applications
  FOR INSERT TO authenticated
  WITH CHECK (student_id = auth.uid());

-- Student can update their own pending application
CREATE POLICY "apps_student_update" ON public.applications
  FOR UPDATE TO authenticated
  USING (student_id = auth.uid() AND status = 'pending');

-- Admin can update any application (approve/reject)
CREATE POLICY "apps_admin_update" ON public.applications
  FOR UPDATE TO authenticated
  USING (public.is_admin());


-- ═══════════════════════════════════════════════════════════════════
-- 7. BACKFILL EXISTING USERS (one-time)
-- Agar pehle se kuch users hain in auth.users but profile nahi hai,
-- yeh unke liye profiles bana deta hai.
-- ═══════════════════════════════════════════════════════════════════
INSERT INTO public.profiles (id, email, full_name, role, is_admin)
SELECT
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'full_name', ''),
  COALESCE(u.raw_user_meta_data->>'role', 'student'),
  FALSE
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;


-- ═══════════════════════════════════════════════════════════════════
-- 8. VERIFICATION — sab theek hai ya nahi check karo
-- ═══════════════════════════════════════════════════════════════════
SELECT '✅ Tables created' AS status;
SELECT 'profiles'     AS table_name, COUNT(*) AS row_count FROM public.profiles
UNION ALL SELECT 'projects',     COUNT(*) FROM public.projects
UNION ALL SELECT 'applications', COUNT(*) FROM public.applications;

-- Check RLS is enabled
SELECT
  schemaname, tablename,
  CASE WHEN rowsecurity THEN '✅ Enabled' ELSE '❌ DISABLED' END AS rls_status
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('profiles','projects','applications');
