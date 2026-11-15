<div align="center">
  <img src="assets/stoop-mark.png" alt="Logo Stoop" width="120" />
  <h1>Stoop: Pemantau Harga Produk dengan Notifikasi Telegram</h1>
  <p><b>Pantau harga produk dari URL incaran dan terima pesan Telegram<br/>
  saat harga turun ke targetmu. Lokal dulu, tanpa akun.</b></p>

  <a href="https://github.com/nekonaru/stoop/releases"><img src="https://img.shields.io/github/v/release/nekonaru/stoop?style=flat-square&color=blue" alt="Rilis" /></a>
  <a href="https://github.com/nekonaru/stoop/actions/workflows/ci.yml"><img src="https://github.com/nekonaru/stoop/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Ruby-3.2%2B-CC342D?style=flat-square&logo=ruby&logoColor=white" alt="Ruby" />
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-555?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="Lisensi" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" alt="Status" />
</div>

<br />

[English](README.md) | **Bahasa Indonesia**

> [!NOTE]
> Stoop adalah alat otomasi pribadi, bukan layanan scraping. Stoop menghormati robots.txt, menerapkan batas laju, dan menolak mengambil halaman yang tidak diizinkan situs.

---

## Daftar Isi

- [Tentang](#tentang)
- [Fitur](#fitur)
- [Kebutuhan](#kebutuhan)
- [Instalasi](#instalasi)
- [Konfigurasi](#konfigurasi)
- [Cara Pakai](#cara-pakai)
- [Menulis Adapter](#menulis-adapter)
- [Struktur Proyek](#struktur-proyek)
- [Pengembangan](#pengembangan)
- [Pengujian](#pengujian)
- [Keamanan](#keamanan)
- [Continuous Integration](#continuous-integration)
- [FAQ](#faq)
- [Penulis](#penulis)
- [Penafian](#penafian)
- [Lisensi](#lisensi)

---

## Tentang

**Stoop** adalah alat baris perintah untuk memantau harga produk. Tambahkan URL produk ke watchlist lokal, dan Stoop mengambil harga terkini sesuai permintaan atau jadwal, menyimpan riwayatnya di database SQLite lokal, lalu mengirim notifikasi Telegram saat harga menyentuh targetmu, turun sebesar persen yang kamu tentukan, atau kembali tersedia. Cocok untuk kamu yang ingin menangkap harga turun tanpa aplikasi, tanpa akun, tanpa langganan.

> _"Stoop yang mantau harga. Kamu yang dapat promonya."_

---

## Fitur

### Watchlist

| Fitur | Deskripsi |
|-------|-----------|
| **Tambah produk** | `stoop add <url> --target 250000` menambahkan produk ke watchlist |
| **Lihat produk** | `stoop list` mencetak tabel berisi harga terakhir, target, drop, dan status |
| **Hapus produk** | `stoop remove <id>` menghapus produk beserta riwayat harganya |
| **Target per produk** | Atur harga target, persen turun, atau keduanya, per produk |
| **Riwayat harga** | `stoop history <id>` menampilkan riwayat harga dalam tabel dengan perubahan per cek |
| **Ekspor CSV** | `stoop export [id]` mengekspor riwayat harga sebagai CSV ke stdout atau file |

### Pengecekan Harga

| Fitur | Deskripsi |
|-------|-----------|
| **Cek sesuai permintaan** | `stoop check [id]` mengambil harga terkini untuk semua produk aktif atau satu produk |
| **Watch loop** | `stoop run` memeriksa harga berkala dengan interval yang bisa diatur (minimal 30 menit) |
| **JSON-LD lebih dulu** | Data terstruktur (`schema.org/Product`) sebagai sumber utama, meta tag dan CSS selector sebagai cadangan |
| **Format rupiah** | Mem-parsing `Rp1.250.000`, `Rp 1.250.000,00`, `IDR 1.250.000` dan format serupa |
| **Retry dengan backoff** | Eror 5xx dan jaringan di-retry maksimal 3 kali, 4xx tidak di-retry |
| **Deteksi basi** | Setelah gagal berturut-turut (default 3) produk ditandai stale dan kamu menerima satu peringatan |

### Notifikasi

| Fitur | Deskripsi |
|-------|-----------|
| **Peringatan Telegram** | Mengirim pesan lewat Telegram Bot API (token dari ENV saja) |
| **Aturan trigger** | Notifikasi saat harga mencapai target, turun X persen, atau kembali tersedia |
| **Anti spam** | Cooldown 12 jam per produk dan deduplikasi harga yang sama |
| **Pesan jujur** | Teks polos Bahasa Indonesia: nama, harga, harga sebelumnya, target, URL |

### Etika

| Fitur | Deskripsi |
|-------|-----------|
| **robots.txt dihormati** | URL yang dilarang tidak pernah diambil |
| **Batas laju** | Maksimal satu permintaan per host per 5 detik |
| **User-Agent jujur** | Mengidentifikasi diri sebagai `Stoop/<versi> (+https://github.com/nekonaru/stoop)` |
| **Tidak membobol** | Tidak ada bypass anti-bot, tidak ada login, tidak ada bypass CAPTCHA, tidak melanggar robots.txt |

---

## Kebutuhan

| Dependency | Versi Minimum | Catatan |
|------------|---------------|---------|
| **Ruby** | 3.2 | Termasuk gem bawaan; `gem --version` harus jalan |
| **SQLite** | 3.x | Tertanam, tanpa server |
| **Git** | bebas | Untuk instalasi dari source |
| **Bot Telegram** | - | Hanya untuk notifikasi; buat lewat @BotFather |

> [!TIP]
> Kamu tidak perlu build apa pun. Instalasi dari source cuma beberapa perintah (lihat di bawah).

### Belum pernah pakai terminal? Mulai dari sini

<details>
<summary><b>Membuka terminal di sistemmu</b></summary>

1. **Linux:** tekan `Ctrl+Alt+T`, ketik perintahmu di sana.
2. **macOS:** tekan `Cmd+Space`, ketik `Terminal`, tekan Enter.
3. **Windows:** tekan `Win+X`, pilih `Terminal` atau `PowerShell`.

</details>

---

## Instalasi

### Opsi A: Instal dari source

<details>
<summary><b>Saya punya Git</b></summary>

```bash
git clone https://github.com/nekonaru/stoop.git
cd stoop
bundle install
ruby bin/stoop version
```

</details>

<details>
<summary><b>Saya tidak punya Git</b></summary>

1. Unduh [rilis terbaru](https://github.com/nekonaru/stoop/releases) sebagai ZIP dari GitHub, atau clone dengan GitHub CLI.
2. Ekstrak dan buka terminal di folder tersebut.
3. Jalankan `bundle install` lalu `ruby bin/stoop version`.

</details>

> [!IMPORTANT]
> `ruby bin/stoop` adalah smoke test. Jika mencetak `Stoop 0.1.0`, instalasi berhasil.

Supaya `stoop` bisa dipanggil langsung tanpa `ruby bin/stoop`, tambahkan ke PATH:

```bash
alias stoop='bundle exec ruby /path/to/stoop/bin/stoop'
```

---

## Konfigurasi

### 1. Bot Telegram (untuk notifikasi)

> [!IMPORTANT]
> Langkah 2 sampai 4 memberimu dua secret. Jangan pernah commit keduanya.

1. Buka Telegram dan kirim pesan ke **@BotFather**.
2. Kirim `/newbot`, ikuti langkahnya, lalu salin **token bot** yang diberikan.
3. Kirim pesan apa pun ke bot baru kamu (misalnya `/start`).
4. Buka `https://api.telegram.org/bot<TOKEN_KAMU>/getUpdates` di browser dan salin `chat.id` dari respons JSON. Itu **chat id** kamu.
5. Ekspor keduanya sebagai environment variable, misalnya di `~/.bashrc`, `~/.zshrc`, atau di environment CI/cron kamu:

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

Sebagai alternatif, salin `.env.example` ke `.env` dan isi nilainya. Stoop memuat `.env` dari direktori saat ini jika ada. Jangan commit `.env`.

### 2. Pengaturan (opsional)

Salin `config.example.yml` ke `~/.stoop/config.yml` dan sesuaikan:

```yaml
check_interval_minutes: 60   # interval daemon, minimal 30
cooldown_hours: 12           # cooldown notifikasi per produk
stale_after_failures: 3      # gagal berturut-turut sebelum ditandai stale
notify_on_restock: true      # notifikasi saat produk kembali tersedia
default_drop_percent: 10     # batas drop saat produk belum punya ambang
database: ~/.stoop/stoop.db  # override path database
```

Stoop membaca `STOOP_CONFIG` untuk lokasi config kustom dan `STOOP_DB` untuk lokasi database kustom.

---

## Cara Pakai

### Pertama kali

1. Buat bot Telegram dan atur `TELEGRAM_BOT_TOKEN` serta `TELEGRAM_CHAT_ID` kalau kamu ingin notifikasi.
2. Tambahkan produk:

```bash
stoop add "https://shop.example.com/product/123" --target 250000
```

3. Cek harga satu kali:

```bash
stoop check
```

4. Jalankan terus-menerus (atau pakai cron). Lihat di bawah.

### Pemakaian sehari-hari

- **Lihat watchlist**: `stoop list`
- **Cek semua harga**: `stoop check`
- **Cek satu produk**: `stoop check 3`
- **Lihat riwayat**: `stoop history 3`
- **Ekspor CSV**: `stoop export` atau `stoop export 3 --output prices.csv`
- **Jalankan daemon**: `stoop run` (foreground; berhenti dengan Ctrl+C)
- **Satu cek per jalan**: `stoop run --once` (cocok dengan cron)

### Menjalankan dengan cron

Stoop tidak fork atau daemonize. Untuk pengaturan berbasis cron:

```cron
*/60 * * * * TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... /path/to/stoop/bin/stoop run --once
```

### Cara notifikasi bekerja

- Notifikasi dikirim saat **salah satu** dari ini benar: harga di atau di bawah targetmu, harga turun minimal `drop_percent` (atau `default_drop_percent`), atau produk kembali tersedia.
- Kamu tidak akan menerima harga yang sama dua kali, dan maksimal satu pesan per produk per 12 jam.
- Setelah 3 kali gagal berturut-turut produk ditandai stale, dan kamu menerima **satu** peringatan. Statusnya reset saat pengecekan berikutnya berhasil.

---

## Menulis Adapter

Kebanyakan situs berjalan langsung. Stoop mencoba, berurutan:

1. **JSON-LD** (`schema.org/Product` di dalam `<script type="application/ld+json">`)
2. **Meta tag** (`product:price:amount` / `og:price:amount`)
3. **CSS selector yang kamu berikan per produk**: `stoop add <url> --selector ".product-price"`

Untuk situs yang butuh lebih, tulis site adapter sekitar 30 baris:

```ruby
# lib/stoop/adapters/my_shop.rb
# frozen_string_literal: true

require_relative 'generic'

module Stoop
  module Adapters
    # Adapter untuk myshop.example.com.
    class MyShop < Generic
      SITE_DOMAINS = %w[myshop.example.com www.myshop.example.com].freeze

      # Override fetch atau helper ekstraksi dari Generic.
      # Return Result.new(name:, price:, currency:, in_stock:).
    end
  end
end
```

Lalu daftarkan di `lib/stoop/adapters.rb`:

```ruby
SITE_ADAPTERS = [ExampleShop, MyShop].freeze
```

Lihat `lib/stoop/adapters/example_shop.rb` untuk contoh yang berjalan. Uji dengan fixture HTML di `spec/fixtures/`, jangan hit situs asli.

---

## Struktur Proyek

```
stoop/
├── bin/stoop              # entry point CLI
├── lib/stoop/
│   ├── cli.rb             # definisi perintah
│   ├── config.rb          # loading YAML + .env
│   ├── db.rb              # penyimpanan SQLite
│   ├── tracker.rb         # orkestrasi cek, catat, notifikasi
│   ├── rules.rb           # kapan notifikasi dikirim
│   ├── price_parser.rb    # format harga Indonesia
│   ├── http_client.rb     # HTTP dengan rate limit dan retry
│   ├── robots.rb          # gate robots.txt
│   ├── rate_limiter.rb    # jeda antar host
│   ├── format.rb          # formatting output
│   ├── adapters/          # adapter per situs
│   │   ├── base.rb
│   │   ├── generic.rb     # JSON-LD / meta / selector
│   │   └── example_shop.rb
│   └── notifiers/
│       ├── base.rb
│       └── telegram.rb
├── spec/
│   ├── stoop/             # unit test
│   └── fixtures/          # fixture HTML
├── config.example.yml     # semua pengaturan, berdokumentasi
├── .env.example           # TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
├── docs/decisions.md      # catatan keputusan desain
├── README.md              # dokumentasi (English)
└── README.id.md           # dokumentasi ini (Bahasa Indonesia)
```

---

## Pengembangan

1. **Instal dependency**: `bundle install`
2. **Jalankan CLI**: `ruby bin/stoop --help`
3. **Tambah perintah**: tambahkan pasangan `desc`/`def` di `lib/stoop/cli.rb`, tambah spec di `spec/stoop/cli_spec.rb`.
4. **Tambah adapter**: salin `lib/stoop/adapters/example_shop.rb`, daftarkan di `lib/stoop/adapters.rb`, tambah fixture dan spec.
5. **Gaya**: `bundle exec rubocop` harus melaporkan nol offense.

> [!WARNING]
> Jangan commit `.env`, `SECURITY_MAP.md`, `SECURITY_REVIEW.md` atau `SECURITY_REPORT.md`. Test tidak pernah hit jaringan; test memakai WebMock dan `spec/fixtures/`.

---

## Pengujian

```bash
bundle exec rspec                          # 121 examples
bundle exec rubocop                        # 0 offense
bundle exec ruby scripts/coverage_check.rb # parser dan rules di atas 80%
ruby bin/stoop --help               # smoke test
```

| Cek | Syarat |
|-----|--------|
| RSpec | Semua contoh lolos |
| RuboCop | 0 offense |
| Coverage | `price_parser.rb` dan `rules.rb` di atas 80% line coverage |
| Secret scan | Gitleaks jalan di CI |

---

## Keamanan

Stoop membaca halaman atas nama kamu dan hanya menyimpan yang kamu pantau. Proteksi yang sudah diverifikasi: permintaan HTTP memakai User-Agent jujur, verifikasi TLS (default faraday), timeout open 5 detik dan read 10 detik, batas laju per host, batas body 10 MB, dan robots.txt dihormati. Secret hanya dari ENV; pesan eror tidak pernah menyertakan token Telegram. Dependency terkunci di `Gemfile.lock` dan dipindai di CI.

> [!NOTE]
> Untuk melaporkan kerentanan, gunakan private vulnerability reporting GitHub (lihat [`SECURITY.md`](SECURITY.md)). Mohon jangan membuka issue publik untuk laporan keamanan.

---

## Continuous Integration

| Workflow | Fungsi |
|----------|--------|
| `.github/workflows/ci.yml` | RuboCop, RSpec di Ubuntu/Windows/macOS dengan Ruby 3.2-3.4, coverage gate, secret scan |
| `.github/dependabot.yml` | Update dependency mingguan untuk bundler dan GitHub Actions |

Setiap pull request wajib lolos 10 cek CI ditambah secret scan sebelum bisa merge. `main` terlindungi: tidak ada force push, riwayat linear, aturan admin ditegakkan.

---

## FAQ

<details>
<summary><b>Apakah Stoop membobol anti-bot?</b></summary>

Tidak. Stoop tidak pernah membobol anti-bot, login, atau CAPTCHA. Jika situs tidak mengizinkan akses otomatis, Stoop memberi tahu dan menolak mengambil halaman itu.

</details>

<details>
<summary><b>Situs mana saja yang didukung?</b></summary>

Situs apa pun yang halaman produknya menyediakan JSON-LD (`schema.org/Product`) atau meta tag harga standar. Selebihnya, kamu bisa memberi CSS selector per produk, atau menulis adapter kecil.

</details>

<details>
<summary><b>Bisakah memantau harga mata uang lain?</b></summary>

Parser ditujukan untuk rupiah Indonesia. Mata uang lain terparse sebagai angka umum, tetapi format notifikasi mengasumsikan rupiah.

</details>

<details>
<summary><b>Token Telegram saya bocor. Sekarang apa?</b></summary>

Cabut langsung lewat @BotFather (`/revoke`), buat yang baru, lalu perbarui environment kamu. Jangan pernah commit token; `.env` diabaikan oleh git dan CI memindai leak di setiap push.

</details>

<details>
<summary><b>Di mana data saya disimpan?</b></summary>

Di file SQLite lokal di `~/.stoop/stoop.db` (override dengan `STOOP_DB`). Tidak ada yang dikirim ke mana pun selain halaman yang kamu pantau dan, jika diatur, pesan Telegram ke chat kamu sendiri.

</details>

---

## Penulis

<div align="center">

| [![Nicolas Dwi Dharma](https://github.com/nekonaru.png?size=100)](https://github.com/nekonaru) |
|:---:|
| **Nicolas Dwi Dharma** |
| [@nekonaru](https://github.com/nekonaru) |

</div>

---

## Penafian

Stoop adalah proyek open-source independen. Stoop tidak berafiliasi dengan marketplace atau merchant mana pun. Hormati terms of service dan robots.txt setiap situs. Penulis tidak bertanggung jawab atas cara tool ini digunakan.

---

## Lisensi

Didistribusikan di bawah **MIT License**. Lihat [`LICENSE`](LICENSE) untuk informasi selengkapnya.
