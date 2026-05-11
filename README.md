# ONCORE — Oncology Collaboration for Research & Excellence

Static website + Supabase backend. Login OTP-based hai (no password).

---

## ⚡ Quick deploy guide (step by step)

### STEP 1 — Supabase database setup (sabse zaroori)

Yeh step skip karne pe **login bilkul kaam nahi karega**.

1. Open: https://supabase.com/dashboard/project/imwgyunypcnlcpiayjfh
2. Left sidebar → **SQL Editor** → **+ New query**
3. Open `sql/00-complete-setup.sql` is folder se, **pura content copy karo**
4. Supabase SQL editor mein paste karo aur **RUN** dabao
5. Neeche output mein `✅ Tables created` aur har table ke saamne `✅ Enabled` aana chahiye

### STEP 2 — Email auth ON karo Supabase mein

1. Supabase dashboard → **Authentication** → **Providers** → **Email**
2. Yeh sab ON karo:
   - ✅ **Enable Email provider**
   - ✅ **Enable Email Signup** (allow new users)
   - ✅ **Enable Email OTP** (6-digit code)
3. **Confirm email** ko **OFF** karo (testing ke liye fast hai)
4. Save

### STEP 3 — Local pe test karo (optional but recommended)

Folder open karo, `index.html` ko browser mein open karo (file://...).
Ya phir terminal se:
```bash
cd oncore-final
python3 -m http.server 8000
# http://localhost:8000 open karo
```

### STEP 4 — Pehla admin banao

1. Website pe jao → `signup.html` → apni email se signup karo (role koi bhi)
2. Email mein OTP aayega (agar nahi aaye to spam check karo, ya STEP 7 dekho)
3. OTP daal ke verify karo
4. Supabase dashboard → SQL Editor → naya query banao
5. `sql/01-make-admin.sql` open karo, `YOUR_EMAIL_HERE@example.com` ki jagah apni email likho
6. RUN dabao
7. Website pe logout karke phir login karo → ab `admin.html` khulega

### STEP 5 — GitHub pe push karo

```bash
cd oncore-final
git init
git add .
git commit -m "Initial ONCORE deploy"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/oncore.git
git push -u origin main
```

(Agar GitHub repo abhi nahi hai: https://github.com/new pe jao → naya repo banao → naam `oncore` rakho → **Public/Private** kuch bhi → "Add README" mat checked karo → Create repo. Phir upar wale commands chalao apni `YOUR-USERNAME` daal ke.)

### STEP 6 — Vercel pe deploy karo

1. https://vercel.com pe jao → **Sign up with GitHub**
2. **Add New** → **Project** → apna `oncore` repo import karo
3. Framework: **Other** (ya "Static" auto-detect ho jayega)
4. Build Command: **(blank chhod do)**
5. Output Directory: **(blank chhod do)**
6. **Deploy** dabao
7. ~30 second mein deploy ho jayega → URL milega jaise `oncore-xyz.vercel.app`

### STEP 7 — Supabase mein Vercel URL whitelist karo (BAHUT zaroori)

Bina iske email link aur OTP redirect kaam nahi karenge.

1. Supabase dashboard → **Authentication** → **URL Configuration**
2. **Site URL** mein daalo: `https://your-vercel-url.vercel.app`
3. **Redirect URLs** mein add karo (ek-ek line per):
   - `https://your-vercel-url.vercel.app/**`
   - `https://your-vercel-url.vercel.app/auth-callback.html`
   - `http://localhost:8000/**` (local testing ke liye)
4. **Save**

### STEP 8 — (Optional) Production email — Resend setup

Default Supabase email **2 emails per hour** tak rate-limited hai. Yeh testing ke liye theek hai but production mein Resend lagao:

1. https://resend.com pe signup karo (free 3000 emails/month)
2. **API Keys** → **Create API Key** → "Sending access" choose karo → key copy karo
3. Supabase dashboard → **Project Settings** → **Authentication** → **SMTP Settings**
4. Enable Custom SMTP, phir yeh values daalo:
   - **Host**: `smtp.resend.com`
   - **Port**: `465`
   - **Username**: `resend`
   - **Password**: (apni API key paste karo)
   - **Sender email**: `onboarding@resend.dev`
   - **Sender name**: `ONCORE`
5. Save

Ab unlimited emails jayenge.

---

## 🐛 Common issues + fixes

**❌ "Login horha nahi" / OTP nahi aata**
- Spam folder check karo
- Supabase Authentication → Providers → Email **ON** hai? (STEP 2)
- 2 emails/hour ka rate limit hit ho gaya — 30 minute wait karo ya Resend lagao (STEP 8)
- SQL setup chala hai? (STEP 1) — agar nahi to profile create nahi hoti aur dashboard pe "Profile not found" aata hai

**❌ "Email rate limit reached"**
Aap pichle hour mein 2 emails bhej chuke ho. Wait karo ya Resend lagao.

**❌ Signup ke baad dashboard pe "Profile not found"**
SQL setup nahi chala. `sql/00-complete-setup.sql` chalao. Phir logout karke phir login karo.

**❌ Admin panel "Access denied"**
Apni email ka `is_admin` flag `true` set nahi hua. `sql/01-make-admin.sql` chalao apni email ke saath.

**❌ Form submit pe "Row level security policy violated"**
RLS policies missing hain. `sql/00-complete-setup.sql` poora chalao (yeh RLS bhi setup karta hai).

**❌ Vercel pe deploy hua but login redirect kaam nahi karta**
STEP 7 nahi kiya. Supabase mein Site URL aur Redirect URLs add karo.

---

## 📁 File structure

```
oncore-final/
├── index.html                  Public homepage
├── about.html                  About page
├── research.html               Research projects (sirf approved show hote hain)
├── contact.html                Contact page
├── doctor-requirements.html    Faculty form (post project)
├── student-application.html    Student form (apply)
├── login.html                  OTP login
├── signup.html                 OTP signup with role
├── auth-callback.html          Magic-link redirect handler
├── dashboard.html              User dashboard (student/doctor)
├── admin.html                  Admin panel (review/approve/reject)
├── vercel.json                 Vercel deployment config
├── .gitignore
├── css/style.css
├── js/
│   ├── main.js                 Site UI JS
│   └── supabase-config.js      Supabase client + auth helpers
├── images/
└── sql/
    ├── 00-complete-setup.sql   ⭐ Full DB setup (run pehle)
    └── 01-make-admin.sql       Admin promote (run baad mein)
```

---

## 🔄 User flows

**Student**:
1. `student-application.html` form fill karta hai
2. Agar logged in nahi to OTP signup → form auto-submit
3. `dashboard.html` pe status dikhta hai (pending/matched/rejected)
4. Admin approve karega tabhi `status='matched'` hoga, aur student ko dashboard pe match score dikhe ga

**Doctor / Faculty**:
1. `doctor-requirements.html` form fill karta hai
2. Project `pending` status mein save hota hai
3. Admin `admin.html` pe **Publish** dabaye → `status='approved'` → public `research.html` pe live aata hai
4. Agar admin **Reject** kare to public site pe nahi dikhega

**Admin**:
1. `login.html` → `admin.html` automatically redirect
2. Tabs: Applications · Projects · Match Portal · Users
3. Har application/project ko Approve ya Reject kar sakta hai
4. Approve karne pe student dashboard pe `matched` ho jata hai
5. Project Publish karne pe `research.html` pe live ho jata hai

---

## 🎯 Match scoring (auto-calculated by DB trigger)

Application insert/update hone pe automatic 0-100 score:
- **Discipline match** with project: 40 pts
- **Skill overlap** with project required skills: 10 pts per skill (max 30)
- **Year of study**: 4+ year = 15 pts, 2-3 year = 10 pts, 1 year = 5 pts
- **GPA**: 3.7+ = 10 pts, 3.3+ = 7 pts, 3.0+ = 4 pts
- **Publications**: 2 pts each (max 5)
- Base: 20 pts for having a discipline

Score >= 80 = Strong match (green), 60-79 = Mid (yellow), <60 = Weak (red)

---

## 🔐 Security

- Anon key safe to expose — designed for browser
- All access controlled via **Row-Level Security (RLS)** policies in Supabase:
  - Public: sirf approved projects read kar sakta hai
  - Student: apni applications read/insert/update (only when pending)
  - Doctor: apne projects + apne projects pe applications
  - Admin: sab kuch (helper function `is_admin()` use hota hai)
- Admin role flag `profiles.is_admin = true` (sirf SQL ya admin panel se set hota hai)
