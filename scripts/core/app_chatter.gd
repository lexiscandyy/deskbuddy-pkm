extends RefCounted
## Picks a short comment for the mascot when the user switches to / opens an
## app. Pure logic (no nodes, no I/O) so it can be unit tested.
##
## Input is only the foreground executable name (e.g. "chrome.exe"). Nothing
## is stored: the per-app cooldown table lives in memory and is cleared on exit.

## Per intensity level: minimum gap between any two comments, and before the
## same app gets a comment again (seconds).
const COOLDOWNS := [
	{"global": 25.0, "per_app": 900.0},
	{"global": 8.0, "per_app": 300.0},
	{"global": 4.0, "per_app": 120.0},
]

## Shell / system processes that become "foreground" without the user really
## opening an app.
const IGNORED := [
	"explorer.exe", "searchhost.exe", "searchapp.exe", "startmenuexperiencehost.exe",
	"shellexperiencehost.exe", "lockapp.exe", "applicationframehost.exe",
	"textinputhost.exe", "systemsettingsbroker.exe", "dwm.exe", "idle",
	"pickerhost.exe", "consent.exe", "rundll32.exe",
]

## exe -> [category, friendly name]
const APPS := {
	"chrome.exe": ["browser", "Chrome"], "msedge.exe": ["browser", "Edge"],
	"firefox.exe": ["browser", "Firefox"], "brave.exe": ["browser", "Brave"],
	"opera.exe": ["browser", "Opera"], "arc.exe": ["browser", "Arc"],
	"code.exe": ["code", "VS Code"], "cursor.exe": ["code", "Cursor"],
	"devenv.exe": ["code", "Visual Studio"], "idea64.exe": ["code", "IntelliJ"],
	"pycharm64.exe": ["code", "PyCharm"], "sublime_text.exe": ["code", "Sublime Text"],
	"android studio.exe": ["code", "Android Studio"], "studio64.exe": ["code", "Android Studio"],
	"windowsterminal.exe": ["terminal", "Terminal"], "cmd.exe": ["terminal", "Command Prompt"],
	"powershell.exe": ["terminal", "PowerShell"], "pwsh.exe": ["terminal", "PowerShell"],
	"winword.exe": ["write", "Word"], "notepad.exe": ["write", "Notepad"],
	"obsidian.exe": ["write", "Obsidian"], "notion.exe": ["write", "Notion"],
	"excel.exe": ["sheet", "Excel"], "powerpnt.exe": ["slides", "PowerPoint"],
	"acrord32.exe": ["read", "Acrobat"], "acrobat.exe": ["read", "Acrobat"], "sumatrapdf.exe": ["read", "SumatraPDF"],
	"figma.exe": ["design", "Figma"], "photoshop.exe": ["design", "Photoshop"],
	"illustrator.exe": ["design", "Illustrator"], "blender.exe": ["design", "Blender"],
	"krita.exe": ["design", "Krita"], "canva.exe": ["design", "Canva"],
	"discord.exe": ["chat", "Discord"], "whatsapp.exe": ["chat", "WhatsApp"],
	"telegram.exe": ["chat", "Telegram"], "slack.exe": ["chat", "Slack"], "line.exe": ["chat", "LINE"],
	"zoom.exe": ["meeting", "Zoom"], "ms-teams.exe": ["meeting", "Teams"], "teams.exe": ["meeting", "Teams"],
	"spotify.exe": ["music", "Spotify"], "vlc.exe": ["video", "VLC"],
	"steam.exe": ["game", "Steam"], "epicgameslauncher.exe": ["game", "Epic Games"],
	"riotclientservices.exe": ["game", "Riot Client"], "valorant.exe": ["game", "Valorant"],
	"robloxplayerbeta.exe": ["game", "Roblox"], "minecraft.exe": ["game", "Minecraft"],
	"obs64.exe": ["stream", "OBS"], "taskmgr.exe": ["system", "Task Manager"],
	"systemsettings.exe": ["system", "Pengaturan"],
}

const LINES := {
	"browser": ["Mau browsing apa di {app}?", "Buka {app}! Jangan kebanyakan tab ya~", "{app} siap! Cari referensi, ya?"],
	"code": ["Ngoding di {app}? Semangat!", "Waktunya ngoding! Semoga bebas bug~", "{app} terbuka. Jangan lupa save ya!"],
	"terminal": ["Wih, buka {app}. Hacker mode!", "Ketik perintahnya hati-hati ya~"],
	"write": ["Nulis di {app}? Aku temenin!", "Satu kalimat dulu, sisanya nyusul~"],
	"sheet": ["{app}! Angka-angkanya rapi ya~", "Waktunya main rumus di {app}!"],
	"slides": ["Bikin slide di {app}? Pasti keren!", "Presentasi ya? Semangat!"],
	"read": ["Lagi baca dokumen? Aku diam dulu~", "Baca di {app}. Fokus ya!"],
	"design": ["Mendesain di {app}? Aku suka!", "Waktunya berkarya di {app}!"],
	"chat": ["Ngobrol di {app}? Jangan lama-lama ya~", "Ada pesan baru di {app}?"],
	"meeting": ["Rapat di {app}? Aku pelan-pelan ya~", "Semoga rapatnya lancar!"],
	"music": ["Putar musik di {app}! Lagu apa nih?", "Musik on! Makin semangat~"],
	"video": ["Nonton di {app}? Jangan lupa istirahat mata!"],
	"game": ["Main {app}? Ingat waktu ya~", "Game time! Jangan lupa minum!"],
	"stream": ["Live di {app}? Aku ikut tampil!"],
	"system": ["Buka {app}? Ada yang perlu diatur?"],
	"other": ["Oh, buka {app}!", "{app}, ya? Semangat!", "Halo, {app}!"],
}

var intensity := 1
var _last_app := ""
var _global_left := 0.0
var _next_ok := {}
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


static func normalize(process_name: String) -> String:
	var n := process_name.strip_edges().to_lower()
	if n != "" and not n.ends_with(".exe"):
		n += ".exe"
	return n


## "my_cool-app.exe" -> "My Cool App". Used for apps not in APPS.
static func friendly_name(process_name: String) -> String:
	var n := normalize(process_name)
	if APPS.has(n):
		return APPS[n][1]
	var base := n.trim_suffix(".exe").replace("_", " ").replace("-", " ")
	var words := PackedStringArray()
	for w in base.split(" ", false):
		words.append(w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(words)


static func category(process_name: String) -> String:
	var n := normalize(process_name)
	return APPS[n][0] if APPS.has(n) else "other"


func reset() -> void:
	_last_app = ""
	_global_left = 0.0
	_next_ok.clear()


## Advance the internal clock (cooldowns).
func advance(dt: float) -> void:
	_clock += dt
	_global_left = maxf(0.0, _global_left - dt)


## Called when the foreground app changes. Returns the comment to show, or ""
## when nothing should be said (ignored app, same app, cooldowns, own app).
## own_process: DeskBuddy's own exe, never commented on.
## skip: e.g. app is on the distraction list during focus (the distraction
## warning handles it instead).
func on_foreground(process_name: String, own_process := "", skip := false) -> String:
	var n := normalize(process_name)
	if n == "" or n in IGNORED or n == normalize(own_process):
		return ""
	if n == _last_app:
		return ""
	_last_app = n
	if skip or _global_left > 0.0 or _clock < float(_next_ok.get(n, 0.0)):
		return ""
	var cd: Dictionary = COOLDOWNS[clampi(intensity, 0, COOLDOWNS.size() - 1)]
	_global_left = float(cd["global"])
	_next_ok[n] = _clock + float(cd["per_app"])
	var lines: Array = LINES[category(n)]
	var line: String = lines[_rng.randi_range(0, lines.size() - 1)]
	return line.replace("{app}", friendly_name(n))
