extends Node

const DIRECTORY := "res://assets/i18n/"
const SETTINGS := "user://language.cfg"

var languages: Dictionary = {}
var locale := "en"
var messages: Dictionary = {}
var english: Dictionary = {}
var originals: Dictionary = {}
var edits: Dictionary = {}
var match_text: MatchText
var local_two_player := false


func _ready() -> void:
	var registry := FileAccess.get_file_as_string(DIRECTORY + "languages.json")
	languages = JSON.parse_string(registry)
	english = _read_catalog("en")
	var config := ConfigFile.new()
	config.load(SETTINGS)
	var preferred := String(config.get_value("display", "language", TranslationServer.get_locale().get_slice("_", 0)))
	_select(preferred if languages.has(preferred) else "en")


func _read_catalog(code: String) -> Dictionary:
	var path := DIRECTORY + code + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _select(code: String) -> void:
	originals = english if code == "en" else _read_catalog(code)
	locale = "en" if originals.is_empty() else code
	if locale == "en":
		originals = english
	edits = {}
	var path := _edits_path()
	if FileAccess.file_exists(path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if saved is Dictionary:
			for key in saved:
				if english.has(key) and saved[key] is String and _valid_edit(key, saved[key]):
					edits[key] = saved[key]
	messages = originals.duplicate()
	messages.merge(edits, true)
	TranslationServer.set_locale(locale)


func set_language(code: String) -> void:
	if not languages.has(code):
		return
	_select(code)
	var config := ConfigFile.new()
	config.set_value("display", "language", locale)
	if config.save(SETTINGS) != OK:
		push_warning("Could not save language preference")


func t(source: String) -> String:
	if match_text != null and english.has(source):
		return match_text.template(source)
	return messages.get(source, english.get(source, source))


func unit_label(source: String) -> String:
	if messages.has(source) or english.has(source):
		return t(source)
	var last_space := source.rfind(" ")
	if last_space > 0 and source.substr(last_space + 1).is_valid_int():
		return t(source.left(last_space)) + source.substr(last_space)
	return source


func support(item: Dictionary) -> String:
	var unit := unit_label(item.get("unita", ""))
	var weapon := t(item.get("arma", ""))
	if unit.is_empty():
		return weapon
	return unit if weapon.is_empty() else "%s + %s" % [unit, weapon]


func small_screen() -> bool:
	var physical := Vector2(get_window().size)
	if OS.has_feature("web"):
		var browser = JavaScriptBridge.get_interface("window")
		physical = Vector2(browser.innerWidth, browser.innerHeight)
	return minf(physical.x, physical.y) < 650


func scale_menu() -> void:
	get_window().content_scale_size = Vector2i(420, 460) if small_screen() else Vector2i(1280, 800)

func _edits_path() -> String:
	return "user://translations-%s.json" % locale


func _tokens(value: String, pattern: String) -> Array[String]:
	var regex := RegEx.create_from_string(pattern)
	var result: Array[String] = []
	for token in regex.search_all(value):
		result.append(token.get_string())
	return result


func _valid_edit(key: String, value: String) -> bool:
	var base: String = originals.get(key, english.get(key, key))
	if value.strip_edges().is_empty():
		return false
	var formats := "%(?:[-+0-9.*]*[a-zA-Z]|%|)"
	var tags := "\\[/?[a-z]+(?:=[^\\]]*)?\\]"
	return (_tokens(base, formats) == _tokens(value, formats)
		and _tokens(base, tags) == _tokens(value, tags))


func save_edit(key: String, value: String) -> String:
	if not english.has(key) or not _valid_edit(key, value):
		return "Keep the formatting tags and placeholders in their original order."
	var next := edits.duplicate()
	var base: String = originals.get(key, english[key])
	if value == base:
		next.erase(key)
	else:
		next[key] = value
	var path := _edits_path()
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(next)):
		return "Could not save the translation."
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return "Could not save the translation."
	edits = next
	messages[key] = value
	return ""
