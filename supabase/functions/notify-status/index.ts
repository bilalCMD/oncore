// ═══════════════════════════════════════════════════════════════════
// ONCORE — Application status notification (Supabase Edge Function)
// ───────────────────────────────────────────────────────────────────
// Triggered by a Supabase Database Webhook on UPDATE of
// public.applications. When an admin approves (matched) or rejects an
// application, the student gets an email via Resend.
//
// Deploy:
//   supabase functions deploy notify-status --no-verify-jwt
//
// Required secrets (Supabase → Edge Functions → Manage secrets):
//   RESEND_API_KEY            re_xxx from resend.com
//   FROM_EMAIL                e.g. "ONCORE <onboarding@resend.dev>"
//   SUPABASE_URL              auto-provided in the runtime
//   SUPABASE_SERVICE_ROLE_KEY auto-provided in the runtime
// ═══════════════════════════════════════════════════════════════════

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "ONCORE <onboarding@resend.dev>";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function emailBody(name: string, status: string, projectTitle: string | null) {
  const greeting = `Hi ${name || "there"},`;
  if (status === "matched" || status === "approved") {
    return {
      subject: "🎉 You've been matched — ONCORE",
      html: `
        <div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a;">
          <h2 style="color:#2d5a3d;">Congratulations! 🎉</h2>
          <p>${greeting}</p>
          <p>Your ONCORE research application has been <strong>approved and matched</strong>${
            projectTitle ? ` to the project <strong>${projectTitle}</strong>` : ""
          }.</p>
          <p>The faculty supervisor will reach out to you directly to begin the collaboration. You can view the details anytime on your dashboard.</p>
          <p style="margin-top:24px;">— The ONCORE Team<br><span style="color:#888;font-size:13px;">Oncology Collaboration for Research &amp; Excellence</span></p>
        </div>`,
    };
  }
  return {
    subject: "Update on your ONCORE application",
    html: `
      <div style="font-family:Inter,Arial,sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a;">
        <h2 style="color:#50508c;">Application update</h2>
        <p>${greeting}</p>
        <p>Thank you for applying through ONCORE. After review, your application was <strong>not selected this round</strong>. Please don't be discouraged — new projects open regularly and you're welcome to apply again.</p>
        <p>Browse current opportunities and reapply anytime from your dashboard.</p>
        <p style="margin-top:24px;">— The ONCORE Team<br><span style="color:#888;font-size:13px;">Oncology Collaboration for Research &amp; Excellence</span></p>
      </div>`,
  };
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record ?? payload.new ?? {};
    const oldRecord = payload.old_record ?? payload.old ?? {};

    const newStatus = record.status;
    const oldStatus = oldRecord.status;

    // Only act on a real status change to a notifiable state
    const notifiable = ["matched", "approved", "rejected"];
    if (!newStatus || newStatus === oldStatus || !notifiable.includes(newStatus)) {
      return new Response(JSON.stringify({ skipped: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Look up the student's email + name
    const { data: profile } = await admin
      .from("profiles")
      .select("email, full_name")
      .eq("id", record.student_id)
      .maybeSingle();

    if (!profile?.email) {
      return new Response(JSON.stringify({ error: "No student email" }), { status: 200 });
    }

    // Optional project title
    let projectTitle: string | null = null;
    if (record.project_id) {
      const { data: proj } = await admin
        .from("projects")
        .select("title")
        .eq("id", record.project_id)
        .maybeSingle();
      projectTitle = proj?.title ?? null;
    }

    const { subject, html } = emailBody(profile.full_name, newStatus, projectTitle);

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from: FROM_EMAIL, to: profile.email, subject, html }),
    });

    if (!res.ok) {
      const err = await res.text();
      return new Response(JSON.stringify({ error: err }), { status: 500 });
    }

    return new Response(JSON.stringify({ sent: true, to: profile.email }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
