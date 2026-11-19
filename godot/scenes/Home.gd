extends ScrollContainer

var column := VBoxContainer.new()
var layout := BoxContainer.new()
var art := TextureRect.new()
var editing := false


func _ready() -> void:
	if "--lobby-server" in OS.get_cmdline_user_args() and DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred("res://online/Server.tscn")
		return
	L10n.scale_menu()
	get_window().size_changed.connect(_scale)
	theme = Tema.get_theme()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Tema.box(Tema.PANEL, Tema.EDGE, 1, 3, 0))
	center.add_child(panel)
	panel.add_child(layout)
	layout.add_theme_constant_override("separation", 0)
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/artwork/scenario_01.jpg")
	crop.region = Rect2(22, 180, 461, 415)
	art.texture = crop
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layout.add_child(art)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 18)
	layout.add_child(padding)
	_scale()
	column.add_theme_constant_override("separation", 12)
	padding.add_child(column)
	if OS.has_feature("web"):
		var launch: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('mission')", true)
		if launch is String and launch.is_valid_int() and int(launch) >= 1000 and not ScenarioLoader.entry(int(launch)).is_empty():
			var side := Flow.AL if ScenarioLoader.entry(int(launch)).get("human") == "allies" else Flow.AX
			JavaScriptBridge.eval("history.replaceState(null, '', location.pathname)", true)
			Game.start_new_game(side, int(launch))
			get_tree().change_scene_to_file.call_deferred("res://scenes/Partita.tscn")
			return
	_home()


func _page(title: String) -> void:
	editing = false
	_scale()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_override("font", Tema.title_font())
	heading.add_theme_color_override("font_color", Tema.BRASS)
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.t(key)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _home() -> void:
	_page("Combat Commander\nEurope")
	_button("Single player", _scenarios.bind(false)).grab_focus()
	_button("Multiplayer", _multiplayer_menu)
	_button("Mission and card workshop", _workshop)
	_button("Settings", _settings)


func _workshop() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").location.assign("workshop/?lang=" + L10n.locale)
	else:
		OS.shell_open("http://localhost:8781/workshop/?lang=" + L10n.locale)


func _multiplayer_menu() -> void:
	_page(L10n.t("Multiplayer"))
	_button("Online lobby", func(): get_tree().change_scene_to_file("res://online/Lobby.tscn")).grab_focus()
	_button("Due giocatori, un tavolo", _scenarios.bind(true))
	_button("Back", _home)


func _scenarios(local_multiplayer: bool) -> void:
	L10n.local_two_player = local_multiplayer
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _settings() -> void:
	_page(L10n.t("Settings"))
	var label := Label.new()
	label.text = L10n.t("Language")
	column.add_child(label)
	var picker := OptionButton.new()
	var codes := L10n.languages.keys()
	for code in codes:
		picker.add_item(L10n.languages[code])
	picker.select(codes.find(L10n.locale))
	picker.item_selected.connect(func(index: int) -> void:
		L10n.set_language(codes[index])
		_settings())
	column.add_child(picker)
	picker.grab_focus()
	var pace := _setting_picker("Action playback speed")
	for key in Game.SPEED_LABELS:
		pace.add_item(L10n.t(key))
	pace.select(Game.speed_index())
	pace.item_selected.connect(Game.select_speed)
	var volume := _setting_picker("Sound effects volume")
	for percent in [0, 25, 50, 75, 100]:
		volume.add_item(L10n.t("Muted") if percent == 0 else "%d%%" % percent, percent)
	volume.select(volume.get_item_index(Game.sound_percent))
	volume.item_selected.connect(func(index: int): Game.set_sound_percent(volume.get_item_id(index)))
	_button("Quick translation", _translation)
	_button("Back", _home)


func _translation() -> void:
	_page(L10n.t("Quick translation"))
	editing = true
	_scale()
	column.add_child(preload("res://scenes/QuickTranslation.gd").new())
	_button("Back", _settings)


func _setting_picker(key: String) -> OptionButton:
	var label := Label.new()
	label.text = L10n.t(key)
	column.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 44
	column.add_child(picker)
	return picker


func _scale() -> void:
	L10n.scale_menu()
	var compact := L10n.small_screen()
	layout.vertical = compact
	art.visible = not editing
	art.custom_minimum_size = Vector2(0, 104) if compact else Vector2(330, 345)
	column.custom_minimum_size.x = 330 if compact else (590 if editing else 385)
