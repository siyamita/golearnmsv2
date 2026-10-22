export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!process.env.OPENAI_API_KEY) return res.status(503).json({ error: 'Asisten AI belum dikonfigurasi. Tambahkan OPENAI_API_KEY di Vercel.' });
  try {
    const { message, role = 'student', context = '' } = req.body || {};
    if (typeof message !== 'string' || !message.trim()) return res.status(400).json({ error: 'Pesan tidak boleh kosong.' });
    if (message.length > 8000) return res.status(400).json({ error: 'Pesan terlalu panjang (maksimal 8.000 karakter).' });
    const system = role === 'admin'
      ? 'Anda adalah asisten teknis GoLearnMS. Bantu analisis data atau troubleshooting berdasarkan konteks yang diberikan. Jangan mengaku dapat mengakses server atau database secara langsung jika datanya tidak diberikan.'
      : role === 'teacher'
        ? 'Anda adalah asisten guru GoLearnMS. Bantu merancang pembelajaran, merangkum materi, menyusun soal, rubrik penilaian, dan menganalisis data yang diberikan. Jangan mengarang data.'
        : 'Anda adalah tutor belajar GoLearnMS. Jelaskan konsep dengan ramah, bertahap, dan mendidik. Bantu siswa memahami proses, bukan sekadar memberi jawaban akhir.';
    const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
      body: JSON.stringify({ model: process.env.OPENAI_MODEL || 'gpt-4.1-mini', messages: [{ role: 'system', content: system }, { role: 'user', content: `${context ? `Konteks: ${context}

` : ''}${message}` }], temperature: 0.5 })
    });
    const data = await upstream.json();
    if (!upstream.ok) return res.status(upstream.status).json({ error: data.error?.message || 'Layanan AI gagal merespons.' });
    return res.status(200).json({ answer: data.choices?.[0]?.message?.content || 'Belum ada jawaban.' });
  } catch (e) { return res.status(500).json({ error: 'Terjadi kesalahan pada layanan AI.' }); }
}
