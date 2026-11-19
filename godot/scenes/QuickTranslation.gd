extends VBoxContainer
## A local correction for the active game language. All entries retain their stable keys.
var search := LineEdit.new()
var matches := OptionButton.new()
var english_text := Label.new()
var editor := TextEdit.new()
var notice := Label.new()
var keys: Array = []
var current := ""
var save := Button.new()
var restore := Button.new()


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	search.placeholder_text = L10n.t("Search game text")
	search.clear_button_enabled = true
	add_child(search)
	search.text_changed.connect(_filter)
	matches.fit_to_longest_item = false
	matches.clip_text = true
	add_child(matches)
	matches.item_selected.connect(_select)
	english_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(english_text)
	var language := Label.new()
	language.text = L10n.languages[L10n.locale]
	add_child(language)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.custom_minimum_size.y = 100
	add_child(editor)
	for b in [save, restore]:
		b.custom_minimum_size.y = 42
		add_child(b)
	save.text = L10n.t("Save translation")
	restore.text = L10n.t("Restore original text")
	save.pressed.connect(_commit.bind(false))
	restore.pressed.connect(_commit.bind(true))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	_filter("")
	search.grab_focus()


func _filter(query: String) -> void:
	keys.clear()
	matches.clear()
	var needle := query.strip_edges().to_lower()
	for key in L10n.english:
		var words: String = str(key) + "\n" + str(L10n.english[key]) + "\n" + L10n.t(key)
		if not needle.is_empty() and not words.to_lower().contains(needle):
			continue
		keys.append(key)
		matches.add_item(str(L10n.t(key)).replace("\n", " ").strip_edges().left(78))
	var index := keys.find("Single player") if needle.is_empty() else 0
	index = maxi(0, index)
	if not keys.is_empty():
		matches.select(index)
	_select(index)


func _select(index: int) -> void:
	current = "" if keys.is_empty() else keys[index]
	matches.disabled = keys.is_empty()
	save.disabled = keys.is_empty()
	restore.disabled = not L10n.edits.has(current)
	editor.editable = not keys.is_empty()
	english_text.text = "" if keys.is_empty() else "English · " + str(L10n.english[current])
	editor.text = "" if keys.is_empty() else L10n.t(current)
	notice.text = L10n.t("No matching text") if keys.is_empty() else ""


func _commit(reset: bool) -> void:
	var value: String = L10n.originals.get(current, L10n.english[current]) if reset else editor.text
	var issue := L10n.save_edit(current, value)
	if issue == "":
		editor.text = value
		matches.set_item_text(matches.selected, value.replace("\n", " ").strip_edges().left(78))
		restore.disabled = not L10n.edits.has(current)
	notice.text = L10n.t("Saved on this device" if issue == "" else issue)
