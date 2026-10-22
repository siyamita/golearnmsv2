# GoLearnMS — LMS starter untuk Vercel

GoLearnMS adalah starter aplikasi Learning Management System berbahasa Indonesia dengan UI joyful (ungu muda, biru, emas). Proyek ini menggunakan React + Vite, Supabase (auth/database), dan Vercel Functions untuk endpoint AI.

## Fitur yang tersedia pada starter
- UI responsif, logo SVG berbasis komponen, mode terang/gelap.
- Login/daftar untuk siswa, guru, dan admin; login demo jika Supabase belum dikonfigurasi.
- Autentikasi Supabase, reset password melalui email, profil dan pengaturan akun.
- Data pengguna untuk admin, pengubahan role/status di UI, ekspor CSV.
- Dashboard, ringkasan kunjungan, grafik sederhana dan insight berbasis data tercatat.
- Buat kelas untuk guru, join kelas dengan kode, tampilan sesi/tugas bila data tersedia.
- Presensi pertemuan untuk guru dan tampilan rekap untuk siswa.
- Asisten AI lewat Vercel Function (API key tetap di server), panel maintenance dan pesan bantuan.
- Skema SQL awal dan Row Level Security (RLS) untuk Supabase.

## Penting sebelum deploy
Ini merupakan **starter yang bisa dikembangkan**, bukan implementasi produksi penuh dari semua detail spesifikasi. Fitur unggah file, viewer semua tipe dokumen, penilaian tugas lengkap, leaderboard dan poin kecepatan, ekspor PDF/XLSX/PPTX, analisis AI berbasis database, email customer service otomatis, status offline otomatis 30 hari, serta pemulihan akun yang memaksa password baru membutuhkan integrasi dan pengujian tambahan. Ekspor bawaan saat ini adalah CSV. Jangan gunakan data siswa nyata sebelum menguji keamanan dan kebijakan privasi.

## 1. Jalankan lokal
1. Instal Node.js versi LTS.
2. Ekstrak ZIP dan buka folder proyek di terminal.
3. Jalankan `npm install` lalu `npm run dev`.
4. Buka URL lokal yang dicetak Vite.

Tanpa Supabase, situs akan masuk mode pratinjau. Login demo: **username `siya`**, password **`demo123`**. Mode demo tidak menyimpan data secara online. Kredensial demo ini bukan kredensial admin produksi.

## 2. Siapkan database online dengan Supabase
1. Buat proyek di https://supabase.com/.
2. Buka SQL Editor dan jalankan seluruh isi `supabase/schema.sql`.
3. Salin Project URL dan anon/public key dari Project Settings → API.
4. Salin `.env.example` menjadi `.env` lalu isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY`.
5. Di Authentication → URL Configuration, set Site URL ke URL deployment dan tambahkan URL redirect yang dipakai untuk reset password.
6. Aktifkan konfigurasi email/SMTP di Supabase untuk verifikasi pendaftaran dan reset password yang andal.
7. Daftarkan akun utama melalui form signup dengan email admin yang dimaksud. Setelah akun ada, jalankan query bootstrap di bagian akhir `supabase/schema.sql` untuk mengubah profil tersebut menjadi admin utama.

**Jangan menaruh password, Supabase service_role key, atau API key AI di source code publik.** Akun utama yang disebutkan dalam permintaan tidak ditanam sebagai kredensial tetap di repo. Gunakan password kuat dan ganti segera jika pernah dipakai di tempat lain.

### Catatan database yang perlu diselesaikan sebelum produksi
- Skema menyertakan fungsi `get_email_for_username` untuk login dengan username. Buat fungsi ini sebagai RPC server-side yang aman, atau ubah login menjadi email saja. Hindari fungsi publik yang memungkinkan enumerasi email.
- Login username menggunakan Vercel Function `/api/username-login`. Tambahkan `SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY` di Environment Variables Vercel. `SUPABASE_SERVICE_ROLE_KEY` hanya untuk server dan tidak boleh memakai awalan `VITE_`. Lindungi endpoint dengan rate limiting sebelum produksi. Untuk promosi admin tambahan, gunakan endpoint terproteksi yang memeriksa `is_super_admin`; jangan memberi akses `service_role` ke browser. UI pengeditan role perlu dihubungkan ke endpoint tersebut sebelum digunakan di produksi.
- Periksa kebijakan RLS di `supabase/schema.sql` dengan akun uji dari setiap peran. RLS adalah lapisan penting, bukan pengganti audit keamanan.

## 3. Deploy ke Vercel
1. Unggah folder proyek ke repository GitHub.
2. Di Vercel, pilih **Add New → Project**, impor repository tersebut.
3. Framework akan terdeteksi sebagai Vite. Build command: `npm run build`; output directory: `dist`.
4. Tambahkan environment variables `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY`.
5. Untuk AI, tambahkan `OPENAI_API_KEY` dan opsional `OPENAI_MODEL` sebagai environment variables server-side.
6. Deploy. Setelah deploy, tambahkan URL Vercel ke Supabase Auth URL Configuration.

## Struktur
```
GoLearnMS/
├── api/ai.js              # Vercel serverless function untuk AI
├── api/username-login.js  # Login username secara server-side
├── src/main.jsx           # React app dan fitur LMS
├── src/style.css          # UI responsif + tema gelap
├── supabase/schema.sql    # tabel, trigger, dan RLS
├── index.html
├── vercel.json
├── .env.example
└── README.md
```

## Batasan AI dan email bantuan
Endpoint AI memerlukan API key sendiri dan penggunaan API dapat menimbulkan biaya. Pesan bantuan pada starter disimpan di database; pengiriman email otomatis belum aktif sampai integrasi penyedia email (misalnya Resend) ditambahkan pada fungsi server. Jangan mengirim data rahasia atau data pribadi siswa ke layanan AI.
