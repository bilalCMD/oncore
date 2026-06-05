# ONCORE — Email notifications (`notify-status`)

Student ko email jata hai jab admin uski application **approve (matched)** ya **reject** karta hai. Resend.com se send hota hai (free tier 3000 emails/month).

Yeh **optional** hai — iske bina baaki site poori chalti hai (status dashboard pe update hota hi rehta hai). Yeh sirf email layer add karta hai.

---

## Setup (one-time)

### 1. Resend API key
1. https://resend.com pe signup karo
2. **API Keys → Create API Key** (Sending access) → key copy karo (`re_...`)

### 2. Supabase CLI se function deploy karo
```bash
# install: https://supabase.com/docs/guides/cli
supabase login
supabase link --project-ref imwgyunypcnlcpiayjfh
supabase functions deploy notify-status --no-verify-jwt
```

### 3. Secrets set karo
```bash
supabase secrets set RESEND_API_KEY=re_your_key_here
supabase secrets set FROM_EMAIL="ONCORE <onboarding@resend.dev>"
```
> `SUPABASE_URL` aur `SUPABASE_SERVICE_ROLE_KEY` runtime mein automatically available hote hain — inhe set karne ki zaroorat nahi.

### 4. Database Webhook banao
Supabase Dashboard → **Database → Webhooks → Create a new hook**
- **Name:** `notify-status`
- **Table:** `applications`
- **Events:** ✅ **Update** (sirf update)
- **Type:** **Supabase Edge Function** → `notify-status`
- **Save**

Bas. Ab jab admin panel se koi application approve/reject hogi, student ko apne aap email chala jayega.

---

## Test
1. Admin panel → koi pending application **Approve** karo
2. Us student ki email check karo (spam bhi)
3. Logs: Supabase Dashboard → **Edge Functions → notify-status → Logs**

## Notes
- `onboarding@resend.dev` se sirf testing hoti hai. Production mein apna domain Resend pe verify karke `FROM_EMAIL` usi domain ka rakho (e.g. `ONCORE <noreply@oncore.org>`).
- Function sirf un status changes pe email bhejta hai jo `matched`, `approved`, ya `rejected` hon — aur tabhi jab status waqai badla ho.
