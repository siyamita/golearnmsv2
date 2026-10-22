import { createClient } from '@supabase/supabase-js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  const { username, password } = req.body || {};
  if (typeof username !== 'string' || typeof password !== 'string' || !username.trim() || !password) return res.status(400).json({ error: 'Username dan password wajib diisi.' });
  if (username.length > 80 || password.length > 200) return res.status(400).json({ error: 'Input tidak valid.' });
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
  const anon = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY;
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !anon || !service) return res.status(503).json({ error: 'Login username belum dikonfigurasi. Tambahkan variabel Supabase server-side di Vercel.' });
  try {
    const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile, error: lookupError } = await admin.from('profiles').select('email,status').eq('username', username.trim()).maybeSingle();
    if (lookupError || !profile || profile.status === 'deleted') return res.status(401).json({ error: 'Username atau password salah, atau akun tidak dapat diakses.' });
    const client = createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await client.auth.signInWithPassword({ email: profile.email, password });
    if (error || !data.session) return res.status(401).json({ error: 'Username atau password salah.' });
    return res.status(200).json({ session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token } });
  } catch { return res.status(500).json({ error: 'Terjadi kesalahan saat masuk.' }); }
}
