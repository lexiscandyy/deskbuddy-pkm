# DeskBuddy

Aplikasi desktop companion untuk membantu mahasiswa menjaga fokus dan mengatur jeda. Prototipe PKM-KC.

- **Target:** Windows 10/11 x64, **Godot 4.7.2 stable** (renderer *Compatibility*/OpenGL 3.3)
- **Bahasa:** GDScript, ditambah satu helper C kecil untuk Win32 (`native/probe`).
- **Status:**
  - Milestone 1 selesai.
  - Milestone 2 berjalan lewat helper: waktu idle dan aplikasi aktif dibaca dari Windows.
  - Maskot critter kartun berkomentar saat pengguna membuka aplikasi.
  - Panel kontrol bergaya kartun.

## Menjalankan

1. Buka Godot 4.7.2, lalu *Import* folder ini (`project.godot`).
2. **Matikan embed game** sebelum menekan Play. Godot 4.4+ menjalankan game di dalam tab *Game* editor secara default, dan di sana jendela tidak bisa transparan, borderless, atau berpindah posisi. Di tab **Game**, klik menu ⋮ lalu hilangkan centang **Embed Game on Next Play**.
3. Tekan F5. Maskot muncul di atas taskbar, panel kontrol muncul di kanan atas.

Atau jalankan dari terminal (cara paling andal untuk menguji overlay):

```bash
"C:/path/ke/Godot_v4.7.2-stable_win64.exe" --path .
```

Opsi tambahan:
- `-- --test-reminder` langsung memunculkan contoh balon pengingat.
- `-- --test-sleepy` menampilkan pose tidur.

### Kontrol
- **Panel kontrol** adalah jendela terpisah dengan tab Sesi, Aktivitas, Tampilan, dan Privasi. Tombol close hanya meminimalkan panel. Untuk keluar, pakai **Keluar DeskBuddy**.
- Untuk membuka panel lagi, **klik maskot** (ia melompat kecil) atau klik ikon DeskBuddy di **system tray**. Menu klik kanan tray berisi Buka panel, Tampilkan/sembunyikan maskot, dan Keluar.

## Skenario demo (±2 menit)

1. **Komentar aplikasi.** Pastikan *Pemantauan aktivitas aktif* menyala di tab Aktivitas. Buka aplikasi apa saja, misalnya VS Code, Chrome, atau Word. Maskot melompat dan menampilkan balon di atas kepalanya, misalnya "Ngoding di VS Code? Semangat!". Tombol **Tes komentar** menampilkan contohnya.
2. **Mode simulasi.** Di tab **Aktivitas**, nyalakan **Mode Simulasi**. Label `SIMULASI` muncul di header. Data aktivitas sekarang berasal dari tombol simulasi.
3. **Durasi demo.** Di tab **Sesi**, nyalakan **Durasi demo** (fokus 30 dtk, jeda 10 dtk, 20-20-20 tiap 45 dtk, idle 5 dtk).
4. **Sesi fokus.** Isi target, misalnya "Menulis Bab 2", lalu tekan **Mulai**. Setelah ±10 dtk tekan **Jeda** (hitung mundur berhenti), lalu **Lanjut**.
5. **Distraksi.**
   - Di tab Aktivitas, nyalakan peringatan distraksi, isi daftar `game.exe`, lalu tekan Enter.
   - Ketik `game.exe` di *Aplikasi aktif* pada kotak simulasi, lalu tekan Enter.
   - Setelah 5 dtk maskot menegur.
   - Tekan Jeda: teguran hilang dan tidak muncul lagi.
6. **Waktu istirahat.** Saat fokus habis, maskot mengingatkan untuk istirahat dan meregang. Jeda 10 dtk berjalan, lalu sesi berakhir.
7. **Mode Ambient.**
   - Ganti **Mode** ke Ambient. Waktu aktif bertambah.
   - Tekan **Simulasikan idle**: waktu berhenti dan maskot tidur ("z z").
   - Tekan **Simulasikan aktif**: waktu jalan lagi.
   - Setelah 45 dtk aktif, pengingat 20-20-20 muncul dengan tombol **Tunda**.

## Arsitektur

```
scripts/
  autoload/settings_store.gd    Settings  : preferensi + statistik agregat (ConfigFile, user://)
  autoload/activity_monitor.gd  Activity  : sampling provider tiap 1 dtk -> AKTIF / IDLE / TIDAK DIKETAHUI
  autoload/reminder_manager.gd  Reminders : satu saluran pengingat, berprioritas, tanpa tumpukan
  autoload/app_state.gd         AppState  : SATU sumber status (mode, fase sesi, Ambient, distraksi)
  activity/activity_provider.gd           antarmuka ActivityProvider
  activity/mock_activity_provider.gd      simulasi (demo & tes)
  activity/native_activity_provider.gd    Windows: menjalankan native/bin/deskbuddy_probe.exe
  core/pomodoro_timer.gd                  logika Pomodoro murni (tanpa jam, diberi dt)
  core/ambient_tracker.gd                 waktu aktif + jatuh tempo 20-20-20
  core/distraction_detector.gd            dwell + cooldown untuk aplikasi pilihan pengguna
  core/app_chatter.gd                     memilih komentar saat aplikasi aktif berganti (+ cooldown)
  overlay/critter_art.gd                  gambar vektor critter (outline kartun, ekspresi)
  overlay/mascot.gd                       perilaku maskot: jalan, lompat, tidur, balon bicara
  ui/cartoon_theme.gd                     tema UI kartun (warna, font, stylebox, ikon SVG)
  ui/control_panel.gd                     jendela kontrol
  main.gd                                 overlay transparan + klik-tembus + tray + komentar aplikasi
native/probe/deskbuddy_probe.c            helper Win32 (idle + nama exe aktif), build.bat
native/bin/deskbuddy_probe.exe            hasil build helper (20 KB)
tests/unit_tests.gd, tests/integration_test.tscn
tools/render_mascot_preview.tscn          render PNG pratinjau maskot + panel
```

- **Aktivitas komputer** (Activity) dan **fase sesi** (AppState.pomodoro) adalah dua status terpisah. Duduk diam (idle) tidak sama dengan sedang menjalani jeda Pomodoro.
- UI dan maskot hanya membaca dari `AppState` dan memanggil method-nya. Tidak ada komponen lain yang punya timer sesi sendiri.

### Maskot critter
Maskotnya critter bulat bertelinga kucing dengan tunas daun di kepala. Semuanya digambar sebagai vektor di `critter_art.gd` dengan outline tebal bergaya kartun, jadi tajam di semua ukuran tanpa file gambar.

| Keadaan | Tampilan |
|---|---|
| Diam | bernapas (squash & stretch halus), berkedip acak, telinga/tunas/ekor bergoyang |
| Jalan | melompat-lompat kecil ke arah tujuan, wajah menoleh ke arah jalan |
| Komentar aplikasi | lompat kecil, mata tersenyum (^ ^), melambai, balon putih di atas kepala ±4,5 dtk |
| Pengingat | mata berbinar, bicara sambil melambai, balon kuning sampai ditutup |
| Komputer idle | mata terpejam, warna sedikit meredup, "z z Z" melayang |

Pengaturan di tab **Tampilan**:
- **Warna:** Stroberi, Persik, Lemon, Mint, Langit, Lilac (dipilih lewat swatch).
- **Ukuran:** Kecil, Sedang, Besar.
- **Intensitas interaksi:** mengatur kecepatan jalan dan seberapa sering maskot berkomentar.

Merender pratinjau ke PNG (butuh GPU, jadi tanpa `--headless`):

```bash
godot --path . res://tools/render_mascot_preview.tscn -- C:/temp/preview
```


### Komentar saat membuka aplikasi
Setiap kali aplikasi aktif berganti, `core/app_chatter.gd` memilih kalimat sesuai jenis aplikasinya:
- browser, editor kode, terminal, dokumen, spreadsheet, slide, desain, chat, rapat, musik, video, dan game;
- aplikasi yang tidak dikenal mendapat kalimat umum, misalnya "Oh, buka Charmap!".

Aturannya:
- Proses sistem (desktop/explorer, Start menu, pencarian, layar kunci) dan DeskBuddy sendiri diabaikan.
- Ada jeda antar-komentar dan jeda per aplikasi, sesuai intensitas:

  | Intensitas | Jeda antar-komentar | Jeda per aplikasi |
  |---|---|---|
  | Tenang | 25 dtk | 15 mnt |
  | Sedang | 8 dtk | 5 mnt |
  | Aktif | 4 dtk | 2 mnt |

  Jadi pindah-pindah jendela dengan Alt+Tab tidak membuat maskot cerewet.
- Komentar tidak muncul saat ada pengingat. Aplikasi yang ada di daftar distraksi tidak dikomentari selama sesi fokus, karena peringatan distraksi yang mengurusnya.
- Bisa dimatikan di tab Aktivitas → *Komentar aplikasi*.

Untuk menambah aplikasi atau kalimat, edit `APPS` dan `LINES` di `app_chatter.gd`.

### Integrasi Windows (helper `deskbuddy_probe.exe`)
`NativeActivityProvider` menjalankan `native/bin/deskbuddy_probe.exe` tanpa jendela. Helper ini program C kecil (`native/probe/deskbuddy_probe.c`) yang setiap detik mencetak satu baris `idle_ms|nama.exe` ke stdout.

Data yang dibaca:
- `GetLastInputInfo` → lama tanpa input keyboard/mouse.
- `GetForegroundWindow` → `GetWindowThreadProcessId` → `QueryFullProcessImageNameW` → nama file exe saja.
- Nama exe hanya dibaca bila komentar aplikasi atau peringatan distraksi menyala. Jika keduanya mati, helper dijalankan ulang tanpa membaca nama aplikasi.

Sifat helper:
- Tidak membaca judul jendela, URL, ketikan, atau isi layar.
- Tidak menulis file dan tidak punya kode jaringan.
- Berhenti sendiri saat DeskBuddy ditutup.
- Hasil ukur: RAM ±6 MB, CPU ±0%.

Build ulang helper (MinGW gcc di PATH):

```bash
native/probe/build.bat
```

- **Export:** salin `deskbuddy_probe.exe` ke folder yang sama dengan `DeskBuddy.exe`. Provider mencari di sana dulu, lalu di `native/bin/`.
- **Tanpa helper:** status menjadi "tidak diketahui". Aplikasi tidak mengarang data.
- **Kenapa bukan PowerShell:** versi awal memakai skrip PowerShell (`-EncodedCommand`), tapi diblokir antivirus (RAV Endpoint Protection: *Suspicious.Argument*). Karena itu helper diganti dengan exe kecil ini.

### Tema UI kartun
`ui/cartoon_theme.gd` membangun `Theme` lewat kode, tanpa file biner:
- latar krem;
- kartu putih bergaya "stiker" dengan outline gelap 3 px dan tepi bawah tebal;
- tombol berwarna pastel yang "tenggelam" saat ditekan;
- tab berbentuk pil dan sakelar on/off (ikon SVG inline);
- scrollbar dan popup yang serasi;
- font Segoe UI tebal (Nunito dipakai otomatis bila terpasang).

Penanda di panel:
- Header memuat critter mini yang ikut bernapas dan berkedip.
- Timer Pomodoro tampil besar dengan angka bergaris tepi.
- Pengingat di panel tampil sebagai catatan kuning.

### Overlay & klik-tembus
Jendela utama:
- borderless, transparan per-piksel, always-on-top, dan `unfocusable` (WS_EX_NOACTIVATE);
- selebar area kerja monitor (`DisplayServer.screen_get_usable_rect`) dan setinggi 330 px (cukup untuk critter terbesar, lompatannya, dan balon);
- tepi bawahnya menempel di atas taskbar.

Klik-tembus memakai `Window.mouse_passthrough_polygon`:
- Polygon diset ke kotak di sekitar maskot dan balon, dibulatkan ke grid 32 px agar region tidak dibangun ulang tiap frame.
- Di luar kotak itu, klik diteruskan ke aplikasi di belakang.
- Di Windows, area di luar polygon juga tidak digambar. Itu tidak masalah karena memang transparan.

**Mode cadangan:** di tab Tampilan, pilih *Jendela biasa* untuk menampilkan maskot di jendela normal berlatar. Pakai ini bila overlay transparan tidak tampil (misalnya driver GPU lama atau Remote Desktop).

### Perilaku timer setelah sleep/wake
`AppState` mengukur waktu dengan `Time.get_ticks_msec()` dan mencocokkannya dengan jam sistem setiap 0,25 dtk. Jika ada lompatan lebih dari 5 dtk (sleep, hibernate, atau proses macet):
- Sesi Pomodoro yang berjalan **otomatis dijeda** dan waktu yang hilang **tidak dikurangkan**. Panel menampilkan pemberitahuan, lalu pengguna menekan **Lanjut**.
- Waktu aktif Ambient **tidak bertambah** selama jeda tersebut. Jika jedanya ≥ 60 dtk, siklus 20-20-20 dimulai ulang karena mata dianggap sudah beristirahat.
- Penghitung distraksi direset, jadi tidak ada pengingat yang menumpuk setelah wake.

### Privasi
Hanya dua file di `%APPDATA%\Godot\app_userdata\DeskBuddy\`:
- `settings.cfg`: preferensi yang ada di whitelist `Settings.DEFAULTS` (termasuk daftar aplikasi yang diketik pengguna sendiri).
- `stats.cfg`: `date`, `ambient_active_sec`, `focus_sessions` (agregat harian).

Yang tidak pernah disimpan: ketikan, judul jendela, URL, screenshot, riwayat aplikasi, dan target sesi.

Nama exe aplikasi aktif hanya dibaca saat komentar aplikasi atau peringatan distraksi menyala. Nama itu dipakai sesaat untuk memilih komentar atau mencocokkan daftar distraksi, lalu dibuang. Tabel jeda per aplikasi hanya ada di memori.

Kontrol privasi di panel:
- Tab Privasi: tombol **Hapus statistik lokal**.
- Tab Aktivitas: sakelar untuk mematikan pemantauan dan sakelar untuk mematikan komentar aplikasi.

## Pengujian

```bash
godot --headless --path . --script res://tests/unit_tests.gd
```

```bash
godot --headless --path . res://tests/integration_test.tscn
```

Exit code 0 berarti lulus. Tes integrasi memakai file settings/stats terpisah (`it_*.cfg`) dan menghapusnya di akhir. Saat headless, provider Windows sengaja tidak menjalankan helper.

### Hasil yang sudah dijalankan (Windows 11 Pro, Godot 4.7.2, RTX 3050, 1920×1080 skala 100%)
| Tes | Hasil |
|---|---|
| `unit_tests.gd`: Pomodoro 30/10 + pause/resume, kontrol tidak valid, Ambient hanya menghitung saat aktif, 20-20-20 tunda/matikan, distraksi, mock, komentar aplikasi (nama ramah, abaikan sistem/DeskBuddy, jeda global & per aplikasi, serahkan ke distraksi saat fokus), provider native aman saat headless, isi sumber helper, settings whitelist & hapus statistik | **100/100 lulus** |
| `integration_test.tscn`: alur lewat autoload asli, termasuk nama exe tidak dibaca bila komentar & distraksi mati | **41/41 lulus** |
| Helper live: idle ms dan nama exe aktif terbaca; tanpa jendela; berhenti sendiri setelah DeskBuddy ditutup | lulus |
| Live di desktop: membuka Charmap → critter melompat, tersenyum, balon "Oh, buka Charmap!" di atas kepala | lulus |
| Pratinjau render: diam, jalan, komentar, pengingat, tidur, 6 warna, 3 ukuran; panel tab Sesi/Aktivitas/Tampilan | lulus |
| Beban saat berjalan: DeskBuddy CPU ±15% dari 1 core dan RAM ±200 MB; helper CPU ±0% dan RAM ±6 MB | dicatat |

### Verifikasi manual yang masih perlu dilakukan di mesin Windows
- [ ] Klik tombol-tombol panel secara langsung (Mulai/Jeda/Lanjut/Akhiri, pindah mode, tunda) dan jalankan skenario demo di atas sampai selesai.
- [ ] Buka beberapa aplikasi sungguhan (VS Code, Chrome, Word, Discord) dan cek kalimat serta jedanya terasa pas.
- [ ] Mode *Jendela biasa*: tampil, dan kembali ke overlay saat dipilih lagi.
- [ ] Ikon tray: klik kiri membuka panel, menu klik kanan berfungsi.
- [ ] Taskbar di posisi lain (kiri/atas) dan taskbar auto-hide. Saat ini hanya taskbar bawah yang didukung.
- [ ] Skala DPI 125%/150%: maskot belum diskalakan mengikuti DPI.
- [ ] Sleep laptop di tengah sesi fokus: setelah wake, sesi dijeda dan muncul pemberitahuan.

## Batasan yang diketahui
- **Fullscreen eksklusif** (game/video DirectX eksklusif) menutupi semua jendela always-on-top, termasuk DeskBuddy. Ini perilaku Windows. Pengingat tetap berjalan dan akan terlihat setelah keluar dari fullscreen. Borderless fullscreen umumnya tetap menampilkan maskot.
- Hanya monitor utama. Belum ada pemilihan monitor.
- CPU ±15% dari satu core, terutama untuk menggambar ulang overlay transparan selebar layar pada 30 fps. Belum ada mode hemat daya.
- Komentar dipicu oleh pergantian aplikasi aktif, bukan oleh peluncuran proses. Aplikasi yang dibuka di latar belakang tidak dikomentari, dan kembali ke aplikasi lama setelah jedanya habis akan dikomentari lagi.
- Aplikasi UWP/Store tertentu (Kalkulator, Pengaturan) tampil sebagai `ApplicationFrameHost.exe` dan diabaikan.
- `deskbuddy_probe.exe` belum ditandatangani (unsigned). Antivirus yang sangat ketat bisa saja menanyakannya. Untuk rilis, tanda tangani exe atau pindahkan ke GDExtension.
