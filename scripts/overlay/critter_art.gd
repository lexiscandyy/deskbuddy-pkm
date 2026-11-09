extends RefCounted
## Vector art for the DeskBuddy critter: a round, cat-eared buddy with a
## sprout on its head, drawn with thick cartoon outlines.
##
## Everything is drawn in "critter units" with the origin at the feet (ground
## contact, y grows downward). The caller sets the canvas transform (position,
## scale, squash & stretch) before calling draw(). Used by the overlay mascot
## and by the small icon in the control panel header.

const OUTLINE := Color("3b2433")
const LINE_W := 3.4
## Distance from the feet to the top of the ears/sprout, in units.
const TOP := 92.0
const HALF_WIDTH := 52.0
const LEAF := Color("7ed69a")

## Body colours for the "Warna maskot" setting.
const COLORS := {
	"pink": Color("ff9ec4"),
	"peach": Color("ffb98f"),
	"lemon": Color("ffd96a"),
	"mint": Color("8fe0bf"),
	"sky": Color("8ec9ff"),
	"lilac": Color("c9a8ff"),
}
const COLOR_ORDER := ["pink", "peach", "lemon", "mint", "sky", "lilac"]
const COLOR_LABELS := ["Stroberi", "Persik", "Lemon", "Mint", "Langit", "Lilac"]


static func color_for(color_name: String) -> Color:
	return COLORS.get(color_name, COLORS["pink"])


## p keys (all optional):
##  color: Color         body colour
##  look: float          -1..1, where the face looks (walking direction)
##  t: float             time in seconds (wobble of ears/sprout/tail)
##  step: float          -1..1 walking leg phase
##  eyes: String         open | blink | happy | sleep | wow
##  mouth: String        smile | open | talk | o
##  wave: float          0..1 raised-arm amount (waving)
static func draw(ci: CanvasItem, p: Dictionary) -> void:
	var col: Color = p.get("color", COLORS["pink"])
	var look: float = p.get("look", 0.0)
	var t: float = p.get("t", 0.0)
	var step: float = p.get("step", 0.0)
	var wave: float = p.get("wave", 0.0)
	var dark := col.darkened(0.22)
	var light := col.lerp(Color.WHITE, 0.55)
	var c := Vector2(0, -38)
	var side := -1.0 if look < -0.05 else 1.0

	# ground shadow
	ci.draw_colored_polygon(_ellipse(Vector2(0, -1), 34, 6), Color(0, 0, 0, 0.16))

	# tail (behind the body, opposite to the look direction)
	var sway := sin(t * 3.0) * 4.0
	var tail := PackedVector2Array()
	var p0 := c + Vector2(-side * 26, 20)
	var p1 := c + Vector2(-side * (56 + sway * 0.3), 16)
	var p2 := c + Vector2(-side * (46 + sway), -14)
	for i in 11:
		var k := i / 10.0
		tail.append(p0.lerp(p1, k).lerp(p1.lerp(p2, k), k))
	ci.draw_polyline(tail, OUTLINE, 11.0, true)
	ci.draw_polyline(tail, dark, 11.0 - LINE_W * 1.6, true)

	# sprout
	var wob := sin(t * 2.2) * 0.12
	var stem_top := c + Vector2(2 + wob * 20, -50)
	ci.draw_line(c + Vector2(0, -28), stem_top, OUTLINE, 5.5, true)
	ci.draw_line(c + Vector2(0, -28), stem_top, Color("5bbf7a"), 2.2, true)
	_shape(ci, _ellipse(stem_top + Vector2(-8, -2), 9, 5, -0.5 + wob), LEAF)
	_shape(ci, _ellipse(stem_top + Vector2(8, -4), 10, 5.5, 0.55 + wob), LEAF)

	# ears
	var ew := sin(t * 2.6 + 1.0) * 1.5
	for s in [-1.0, 1.0]:
		var ear := PackedVector2Array([
			c + Vector2(s * 32, -12),
			c + Vector2(s * (31 + ew), -50 + ew),
			c + Vector2(s * 8, -31),
		])
		_shape(ci, ear, col)
		var inner := PackedVector2Array([
			c + Vector2(s * 27, -18),
			c + Vector2(s * (28 + ew), -42 + ew),
			c + Vector2(s * 15, -30),
		])
		ci.draw_colored_polygon(inner, light.lerp(Color("ff8fb0"), 0.35))

	# feet
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, step * s) * 5.0
		_shape(ci, _ellipse(Vector2(s * 16 + step * s * 4, -7 - lift), 11, 7.5), dark)

	# back arm (waving one is drawn after the body)
	_shape(ci, _ellipse(c + Vector2(-side * 34, 10), 7, 9.5, -side * 0.4), col)

	# body
	_shape(ci, _ellipse(c, 37, 33), col)
	ci.draw_colored_polygon(_ellipse(c + Vector2(look * 3, 14), 22, 14), light)
	ci.draw_colored_polygon(_ellipse(c + Vector2(-19, -17), 7, 4.5, -0.6), Color(1, 1, 1, 0.75))

	# front arm (waves when wave > 0)
	var arm_angle := lerpf(side * 0.4, side * -2.3 + sin(t * 14.0) * 0.35 * wave, wave)
	var arm_pos := c + Vector2(side * 34, lerpf(10.0, -10.0, wave))
	_shape(ci, _ellipse(arm_pos, 7, 9.5, arm_angle), col)

	# face
	var f := c + Vector2(look * 7.0, 2)
	ci.draw_colored_polygon(_ellipse(f + Vector2(-21, 9), 6.5, 4), Color(1, 0.35, 0.5, 0.42))
	ci.draw_colored_polygon(_ellipse(f + Vector2(21, 9), 6.5, 4), Color(1, 0.35, 0.5, 0.42))
	_draw_eyes(ci, f, str(p.get("eyes", "open")))
	_draw_mouth(ci, f + Vector2(0, 10), str(p.get("mouth", "smile")), t)


static func _draw_eyes(ci: CanvasItem, f: Vector2, mode: String) -> void:
	for s in [-1.0, 1.0]:
		var e := f + Vector2(s * 13, -2)
		match mode:
			"blink", "sleep":
				ci.draw_arc(e + Vector2(0, -2), 5.5, 0.25, PI - 0.25, 10, OUTLINE, 2.8, true)
			"happy":
				ci.draw_arc(e + Vector2(0, 3), 5.5, PI + 0.25, TAU - 0.25, 10, OUTLINE, 3.0, true)
			"wow":
				ci.draw_colored_polygon(_ellipse(e, 6.5, 8), OUTLINE)
				ci.draw_circle(e + Vector2(-1.8, -3), 2.4, Color.WHITE, true, -1.0, true)
				ci.draw_circle(e + Vector2(2, 2.6), 1.1, Color.WHITE, true, -1.0, true)
			_:
				ci.draw_colored_polygon(_ellipse(e, 5, 6.5), OUTLINE)
				ci.draw_circle(e + Vector2(-1.4, -2.4), 1.9, Color.WHITE, true, -1.0, true)
				ci.draw_circle(e + Vector2(1.6, 2.2), 0.9, Color.WHITE, true, -1.0, true)


static func _draw_mouth(ci: CanvasItem, m: Vector2, mode: String, t: float) -> void:
	match mode:
		"open", "talk":
			var h := 5.0 if mode == "open" else 2.5 + absf(sin(t * 11.0)) * 3.5
			var pts := _ellipse(m + Vector2(0, 1), 5.5, h)
			ci.draw_colored_polygon(pts, Color("7a2840"))
			ci.draw_colored_polygon(_ellipse(m + Vector2(0, 1 + h * 0.5), 3.5, h * 0.4), Color("ff7f9f"))
			_outline(ci, pts, 2.4)
		"o":
			ci.draw_arc(m + Vector2(0, 1), 2.6, 0, TAU, 12, OUTLINE, 2.2, true)
		_:
			ci.draw_arc(m + Vector2(-3, -1), 3, 0.15, PI - 0.15, 8, OUTLINE, 2.4, true)
			ci.draw_arc(m + Vector2(3, -1), 3, 0.15, PI - 0.15, 8, OUTLINE, 2.4, true)


## Filled shape with the cartoon outline.
static func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	_outline(ci, pts, LINE_W)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	closed.append(pts[1])
	ci.draw_polyline(closed, OUTLINE, width, true)


static func _ellipse(center: Vector2, rx: float, ry: float, rot := 0.0, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
	return pts
