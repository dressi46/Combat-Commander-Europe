extends Node

const DIRECTORY := "res://assets/i18n/"
const SETTINGS := "user://language.cfg"

var languages: Dictionary = {}
var locale := "en"
var messages: Dictionary = {}
var english: Dictionary = {}
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
	messages = english if code == "en" else _read_catalog(code)
	locale = "en" if messages.is_empty() else code
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
