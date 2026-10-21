// Admin-only staff account management.
// Creating users and setting passwords needs Supabase's privileged Auth API, so it lives here
// (server side) and never in the website. The service-role key is injected by the Edge runtime
// as SUPABASE_SERVICE_ROLE_KEY and is not stored in this repo or sent to browsers.
//
// POST { action: 'create', email, password, role }       -> creates a confirmed account + staff profile
// POST { action: 'reset_password', email, password }      -> sets a new password for an existing staff account
// The caller must be signed in as an active administrator.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PW_MSG = 'Password must be 10-72 characters and include letters and numbers.';
const passwordOk = (p: unknown, email: string) =>
  typeof p === 'string' && p.length >= 10 && p.length <= 72 && /[A-Za-z]/.test(p) && /\d/.test(p) &&
  p.toLowerCase() !== email && !/^(password|passw0rd|12345)/i.test(p);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // 1) Who is calling?
  const caller = createClient(url, anon, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return json({ error: 'Please sign in again.' }, 401);

  const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });

  // 2) Must be an active administrator.
  const { data: me } = await admin.from('profiles').select('role, is_active').eq('id', user.id).maybeSingle();
  if (!me || !me.is_active || me.role !== 'admin') return json({ error: 'Only administrators can do this.' }, 403);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: 'Invalid request.' }, 400); }

  const email = String(body.email ?? '').trim().toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 120) return json({ error: 'Enter a valid email address.' }, 400);

  // 3) Actions
  if (body.action === 'create') {
    const role = body.role === 'admin' ? 'admin' : 'employee';
    if (!passwordOk(body.password, email)) return json({ error: PW_MSG }, 400);

    let userId: string | undefined;
    let existed = false;
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email, password: body.password as string, email_confirm: true,
    });
    if (createError) {
      if (!/already|registered|exists/i.test(createError.message)) return json({ error: createError.message }, 400);
      // The login already exists: just give it staff access (its password is left unchanged).
      for (let page = 1; page <= 10 && !userId; page++) {
        const { data } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        userId = data?.users.find((u) => u.email?.toLowerCase() === email)?.id;
        if (!data || data.users.length < 200) break;
      }
      if (!userId) return json({ error: 'That email is already registered but could not be found.' }, 409);
      existed = true;
    } else {
      userId = created.user.id;
    }

    const { error: profileError } = await admin.from('profiles')
      .upsert({ id: userId, email, role, is_active: true }, { onConflict: 'id' });
    if (profileError) return json({ error: profileError.message }, 400);
    return json({ ok: true, existed });
  }

  if (body.action === 'reset_password') {
    if (!passwordOk(body.password, email)) return json({ error: PW_MSG }, 400);
    // Only existing staff accounts can be reset through this screen.
    const { data: target } = await admin.from('profiles').select('id').eq('email', email).maybeSingle();
    if (!target) return json({ error: 'That email is not a staff account.' }, 404);
    const { error } = await admin.auth.admin.updateUserById(target.id, { password: body.password as string });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: 'Unknown action.' }, 400);
});
