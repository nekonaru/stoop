# Catatan Rilis

Semua perubahan penting untuk proyek ini dicatat di sini.

## v0.1.0

Rilis pertama. Stoop adalah pemantau harga berbasis command line: melacak harga produk dari URL incaran, menyimpan riwayat di database SQLite lokal, dan mengirim pesan Telegram saat harga mencapai targetmu.

## Fitur baru

- **Perintah watchlist.** `add`, `list`, `remove`, `check`, `history`, `export` dan `run` mengelola produk dan harganya dari terminal.
- **Ekstraksi harga.** JSON-LD (`schema.org/Product`) menjadi sumber utama, dengan meta tag dan CSS selector per produk sebagai cadangan.
- **Parser harga Indonesia.** Mem-parsing `Rp1.250.000`, `Rp 1.250.000,00`, `IDR 1.250.000` dan format serupa menjadi integer rupiah.
- **Penyimpanan SQLite.** Produk dan price point tersimpan di `~/.stoop/stoop.db` (override dengan `STOOP_DB`).
- **Notifikasi Telegram.** Pesan teks polos Bahasa Indonesia berisi nama produk, harga terkini, harga sebelumnya, target, dan URL.
- **Aturan notifikasi.** Notifikasi saat harga mencapai target, turun sebesar persen tertentu, atau produk kembali tersedia.
- **Anti spam.** Cooldown 12 jam per produk dan deduplikasi harga yang sama; event restock tetap notifikasi meski harganya sama.
- **Deteksi basi.** Setelah tiga kali gagal berturut-turut produk ditandai stale dan kamu menerima satu peringatan; statusnya pulih saat pengecekan berikutnya berhasil.
- **Watch loop.** `stoop run` memeriksa harga berjadwal (minimal 30 menit) dengan retry dan backoff untuk kegagalan HTTP sementara.
- **Etika.** robots.txt dihormati (path yang tidak bisa diverifikasi tidak pernah diambil), permintaan diberi batas laju per host, User-Agent jujur, dan tidak ada bypass anti-bot.
- **Sistem adapter.** Adapter khusus per situs bisa ditulis sekitar 30 baris; contoh yang berjalan tersedia di `lib/stoop/adapters/example_shop.rb`.

## Peningkatan

- **Output terformat.** Tabel, format rupiah, persen perubahan, dan tampilan nama dari halaman yang tidak terpercaya disanitasi.
- **Pengamanan.** Secret hanya dari ENV, pesan eror tidak pernah menyertakan token Telegram, body respons dibatasi 10 MB, alias YAML dimatikan, dan ekspor CSV menetralkan formula injection.
- **CI dan quality gate.** RuboCop, RSpec di Ubuntu/Windows/macOS dengan Ruby 3.2 sampai 3.4, coverage gate untuk parser dan rules, secret scan di setiap push, dan GitHub Actions yang dipin ke SHA dengan gem yang terkunci dan terverifikasi checksum.
- **Dokumentasi bilingual.** README Bahasa Inggris dan Bahasa Indonesia, plus kebijakan keamanan publik.
