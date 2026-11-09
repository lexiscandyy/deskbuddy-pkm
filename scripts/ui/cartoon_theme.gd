extends RefCounted
## Cartoon UI theme for DeskBuddy: cream background, white "sticker" cards
## with thick dark outlines, chunky buttons with a thicker bottom edge (they
## sink when pressed), pill tabs, toggle switches and bold rounded type.
##
## Built in code (no binary .tres) so colours stay easy to tweak. Icons are
## tiny inline SVGs rasterised at runtime.

const INK := Color("3b2433")
const MUTED := Color("8a6f7e")
const BG := Color("fff4e6")
const CARD := Color("ffffff")
const CREAM_DARK := Color("f3e3d0")
const PINK := Color("ff9ec4")
const PINK_DARK := Color("f0679a")
const MINT := Color("8fe0bf")
const LEMON := Color("ffd96a")
const SKY := Color("8ec9ff")
const CORAL := Color("ff9a8f")
const NOTE := Color("fff0b3")

const RADIUS := 14
const BORDER := 3
const DEPTH := 6

static var _theme: Theme
static var _fonts := {}


## Bold system font (Segoe UI on Windows). weight: 400..900.
static func font(weight := 700) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Nunito", "Segoe UI", "Arial Rounded MT Bold", "Arial"])
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		_fonts[weight] = f
	return _fonts[weight]


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Rounded box with the cartoon outline. depth = thicker bottom edge.
static func box(fill: Color, radius := RADIUS, depth := 0, border := BORDER, margin := 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.border_width_bottom = border + depth
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.content_margin_bottom = margin + depth
	sb.anti_aliasing = true
	return sb


static func _button_styles(t: Theme, type: String, fill: Color) -> void:
	var normal := box(fill, RADIUS, 4, BORDER, 8.0)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.18)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.08)
	pressed.border_width_bottom = BORDER
	pressed.content_margin_top = normal.content_margin_top + 4.0
	pressed.content_margin_bottom = normal.content_margin_bottom - 4.0
	pressed.expand_margin_top = -4.0
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = fill.lerp(CREAM_DARK, 0.7)
	disabled.border_color = MUTED
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, INK)
	t.set_color("font_disabled_color", type, MUTED)


static func svg_texture(svg: String, scale := 1.0) -> ImageTexture:
	var img := Image.new()
	img.load_svg_from_string(svg, scale)
	return ImageTexture.create_from_image(img)


static func _switch_svg(on: bool, disabled := false) -> String:
	var track := "#8fe0bf" if on else "#eadccd"
	var knob_x := 31 if on else 13
	var op := "0.45" if disabled else "1"
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="46" height="28" opacity="%s">'
		+ '<rect x="1.5" y="1.5" width="43" height="25" rx="12.5" fill="%s" stroke="#3b2433" stroke-width="3"/>'
		+ '<circle cx="%d" cy="14" r="7.5" fill="#ffffff" stroke="#3b2433" stroke-width="3"/></svg>') % [op, track, knob_x]


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 15

	# --- text
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", INK)

	# --- buttons (+ coloured variations)
	_button_styles(t, "Button", CARD)
	for v: Array in [["PinkButton", PINK], ["MintButton", MINT], ["LemonButton", LEMON], ["SkyButton", SKY], ["CoralButton", CORAL]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1])
	_button_styles(t, "OptionButton", CARD)
	t.set_icon("arrow", "OptionButton", svg_texture(
		'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="12"><path d="M3 3 L8 9 L13 3" stroke="#3b2433" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>'))
	t.set_constant("arrow_margin", "OptionButton", 12)

	# --- toggles: CheckBox drawn as a cartoon switch
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_content_margin_all(4)
	var flat_hover := flat.duplicate() as StyleBoxFlat
	flat_hover.bg_color = Color(PINK, 0.15)
	flat_hover.set_corner_radius_all(10)
	for s in ["normal", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(s, "CheckBox", flat)
	t.set_stylebox("hover", "CheckBox", flat_hover)
	t.set_stylebox("hover_pressed", "CheckBox", flat_hover)
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckBox", svg_texture(_switch_svg(true)))
	t.set_icon("unchecked", "CheckBox", svg_texture(_switch_svg(false)))
	t.set_icon("checked_disabled", "CheckBox", svg_texture(_switch_svg(true, true)))
	t.set_icon("unchecked_disabled", "CheckBox", svg_texture(_switch_svg(false, true)))
	t.set_constant("h_separation", "CheckBox", 10)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", INK)
	t.set_color("font_disabled_color", "CheckBox", MUTED)

	# --- text fields
	var field := box(CARD, 12, 0, BORDER, 8.0)
	field.content_margin_left = 12.0
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = PINK_DARK
	var field_ro := field.duplicate() as StyleBoxFlat
	field_ro.bg_color = CREAM_DARK
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field_ro)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_uneditable_color", "LineEdit", MUTED)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.75))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(PINK, 0.5))
	var updown := svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="24"><path d="M3 9 L8 4 L13 9 M3 15 L8 20 L13 15" stroke="#3b2433" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	t.set_icon("updown", "SpinBox", updown)

	# --- tabs
	var tab_panel := box(CARD, 16, DEPTH, BORDER, 14.0)
	var tab_sel := box(PINK, 12, 0, BORDER, 8.0)
	tab_sel.content_margin_left = 16.0
	tab_sel.content_margin_right = 16.0
	tab_sel.border_width_bottom = 0
	tab_sel.corner_radius_bottom_left = 0
	tab_sel.corner_radius_bottom_right = 0
	var tab_unsel := tab_sel.duplicate() as StyleBoxFlat
	tab_unsel.bg_color = CREAM_DARK
	tab_unsel.expand_margin_top = -4.0
	var tab_hover := tab_unsel.duplicate() as StyleBoxFlat
	tab_hover.bg_color = PINK.lerp(Color.WHITE, 0.5)
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_font("font", "TabContainer", font(800))
	t.set_font_size("font_size", "TabContainer", 15)
	t.set_constant("side_margin", "TabContainer", 10)
	t.set_constant("tab_separation", "TabContainer", 6)

	# --- cards (PanelContainer variations)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(CARD, 16, 4, BORDER, 12.0))
	t.set_type_variation("NoteCard", "PanelContainer")
	t.set_stylebox("panel", "NoteCard", box(NOTE, 16, 4, BORDER, 12.0))
	t.set_type_variation("TimerCard", "PanelContainer")
	t.set_stylebox("panel", "TimerCard", box(PINK, 20, DEPTH, BORDER, 12.0))
	t.set_type_variation("Badge", "Label")
	var badge := box(LEMON, 10, 0, 2, 3.0)
	badge.content_margin_left = 10.0
	badge.content_margin_right = 10.0
	t.set_stylebox("normal", "Badge", badge)
	t.set_font("font", "Badge", font(900))
	t.set_font_size("font_size", "Badge", 12)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", font(900))
	t.set_font_size("font_size", "Heading", 17)
	t.set_type_variation("Hint", "Label")
	t.set_font("font", "Hint", font(600))
	t.set_font_size("font_size", "Hint", 13)
	t.set_color("font_color", "Hint", MUTED)

	# --- scrollbars
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(CREAM_DARK, 0.6)
	scroll_bg.set_corner_radius_all(6)
	scroll_bg.content_margin_left = 6.0
	scroll_bg.content_margin_right = 6.0
	var grab := StyleBoxFlat.new()
	grab.bg_color = PINK
	grab.border_color = INK
	grab.set_border_width_all(2)
	grab.set_corner_radius_all(6)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = PINK_DARK
	t.set_stylebox("scroll", "VScrollBar", scroll_bg)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)

	# --- popups, tooltips, dialogs
	var popup := box(CARD, 12, 0, BORDER, 6.0)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = PINK.lerp(Color.WHITE, 0.45)
	popup_hover.set_corner_radius_all(8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_stylebox("panel", "TooltipPanel", box(NOTE, 10, 0, 2, 8.0))
	t.set_color("font_color", "TooltipLabel", INK)
	var dlg := StyleBoxFlat.new()
	dlg.bg_color = BG
	dlg.set_content_margin_all(14)
	t.set_stylebox("panel", "AcceptDialog", dlg)
	var sep := StyleBoxLine.new()
	sep.color = Color(MUTED, 0.35)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	return t
