## Tema grafico «carta da campo» (anni '40): verde oliva scuro, kaki e ottone,
## titoli a stencil e testi in un condensato ben leggibile.
class_name Tema
extends RefCounted

const BG := Color(0.086, 0.098, 0.078)
const PANEL := Color(0.145, 0.160, 0.125)
const PANEL_HI := Color(0.205, 0.225, 0.170)
const EDGE := Color(0.42, 0.40, 0.27)
const BRASS := Color(0.86, 0.72, 0.36)
const PAPER := Color(0.90, 0.87, 0.76)
const INK := Color(0.93, 0.91, 0.82)
const DIM := Color(0.66, 0.66, 0.56)
const RED := Color(0.80, 0.22, 0.16)
const AXIS := Color(0.55, 0.63, 0.66)
const ALLIES := Color(0.80, 0.60, 0.36)

const PAPER_TEX := "res://assets/ui/paper.png"
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform sampler2D paper : hint_default_white;
uniform vec4 tint : source_color = vec4(0.075, 0.085, 0.065, 1.0);
uniform float texture_strength = 0.42;
uniform float vignette_strength = 0.58;
void fragment() {
	vec3 p = texture(paper, UV).rgb;
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.28, 0.95, length(d) * 1.32);
	vec3 col = mix(tint.rgb, p, texture_strength);
	col *= 1.0 - v * vignette_strength;
	COLOR = vec4(col, 1.0);
}
"""

static var _theme: Theme = null
static var _backdrop: ShaderMaterial = null
static var _title_font: Font = null
static var _body_font: Font = null
static var _bold_font: Font = null
static var _type_font: Font = null


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/BlackOpsOne-Regular.ttf")
	return _title_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
	return _body_font

static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	return _bold_font

## Macchina da scrivere per cronaca e rapporti: dà il tono «documento militare».
static func typewriter_font() -> Font:
	if _type_font == null:
		_type_font = load("res://assets/fonts/Typewriter.ttf")
	return _type_font

## Sfondo unico (carta + viñeta) per menú e tabellone. Viene creato una volta
## sola e condiviso: pochi shader, nessuna copia della texture.
static func backdrop_material() -> ShaderMaterial:
	if _backdrop != null:
		return _backdrop
	var shader := Shader.new()
	shader.code = BACKDROP_SHADER
	_backdrop = ShaderMaterial.new()
	_backdrop.shader = shader
	if ResourceLoader.exists(PAPER_TEX):
		_backdrop.set_shader_parameter("paper", load(PAPER_TEX))
	return _backdrop

## Fondo a tutta finestra su un CanvasLayer dietro l'interfaccia.
static func attach_backdrop(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = -8
	parent.add_child(layer)
	var bg := ColorRect.new()
	bg.name = "FieldBackdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = backdrop_material()
	layer.add_child(bg)
	return layer

## Dissolvenza in apertura: evita il «taglio» fra una schermata e l'altra.
static func fade_in(node: Node, duration: float = 0.32) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	node.add_child(layer)
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.022, 0.016, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var tween := node.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)
	tween.tween_callback(layer.queue_free)


static func box(bg: Color, border: Color, bw: int = 2, radius: int = 4, pad: int = 8, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.38)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	return sb


## Pannello «importante» con ombra: ficha de misión, informes y diálogos.
static func paper_box(bg: Color = PANEL, border: Color = EDGE, bw: int = 2, radius: int = 4, pad: int = 8) -> StyleBoxFlat:
	return box(bg, border, bw, radius, pad, true)


static func side_color(f: int) -> Color:
	return AXIS if f == Flow.AX else ALLIES


## Bandera histórica de la nación (1936–1946). Alemania usa el Balkenkreuz,
## no la bandera oficial con la esvástica.
static func flag(nation: String) -> Texture2D:
	var path := "res://assets/flags/%s.svg" % nation
	return load(path) if ResourceLoader.exists(path) else null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var symbols := preload("res://assets/fonts/BoardSymbols.ttf")
	for font in [body_font(), bold_font(), title_font()]:
		font.fallbacks.assign([symbols])
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18
	# Pulsanti
	t.set_stylebox("normal", "Button", box(PANEL_HI, EDGE, 2, 4, 8))
	t.set_stylebox("hover", "Button", box(PANEL_HI.lightened(0.12), BRASS, 2, 4, 8))
	t.set_stylebox("pressed", "Button", box(PANEL.darkened(0.2), BRASS, 2, 4, 8))
	t.set_stylebox("disabled", "Button", box(PANEL.darkened(0.1), EDGE.darkened(0.4), 2, 4, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS, 2, 4, 8))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", BRASS)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", 18)
	for cls in ["OptionButton", "CheckButton", "CheckBox"]:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(st, cls, t.get_stylebox(st, "Button"))
		t.set_color("font_color", cls, INK)
		t.set_font("font", cls, bold_font())
	# Pannelli
	t.set_stylebox("panel", "PanelContainer", box(PANEL, EDGE, 2, 4, 8))
	t.set_stylebox("panel", "Panel", box(PANEL, EDGE, 2, 4, 8))
	t.set_stylebox("panel", "PopupPanel", box(PANEL, BRASS, 2, 4, 10))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.05, 0.04, 0.96), BRASS, 1, 3, 6))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 16)
	# Testi
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", body_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	# Barre di scorrimento
	var grab := box(EDGE, EDGE, 0, 4, 0)
	var track := box(PANEL.darkened(0.3), EDGE.darkened(0.5), 0, 4, 0)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", cls, grab)
		t.set_stylebox("grabber_highlight", cls, box(BRASS, BRASS, 0, 4, 0))
		t.set_stylebox("grabber_pressed", cls, box(BRASS, BRASS, 0, 4, 0))
		t.set_stylebox("scroll", cls, track)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	# Liste del menu
	t.set_stylebox("panel", "ItemList", box(PANEL.darkened(0.15), EDGE, 2, 4, 6))
	t.set_stylebox("selected", "ItemList", box(BRASS.darkened(0.45), BRASS, 1, 3, 2))
	t.set_stylebox("selected_focus", "ItemList", box(BRASS.darkened(0.45), BRASS, 1, 3, 2))
	t.set_stylebox("hovered", "ItemList", box(PANEL_HI, EDGE, 1, 3, 2))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", INK)
	t.set_color("font_selected_color", "ItemList", Color(1, 1, 1))
	t.set_font_size("font_size", "ItemList", 18)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, BRASS, 2, 4, 6))
	t.set_stylebox("hover", "PopupMenu", box(PANEL_HI, BRASS, 1, 3, 4))
	t.set_color("font_color", "PopupMenu", INK)
	_theme = t
	return t


## Etichetta-titolo a stencil.
static func title(text: String, size: int = 22, col: Color = BRASS) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
