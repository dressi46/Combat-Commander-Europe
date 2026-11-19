extends CenterContainer

var column := VBoxContainer.new()


func _ready() -> void:
	if "--lobby-server" in OS.get_cmdline_user_args() and DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred("res://online/Server.tscn")
		return
	L10n.scale_menu()
	get_window().size_changed.connect(_scale)
	theme = Tema.get_theme()
	column.custom_minimum_size.x = 330
	column.add_theme_constant_override("separation", 12)
	add_child(column)
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
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.t(key)
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _home() -> void:
	_page("Combat Commander: Europe")
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
	_button("Back", _home)


func _scale() -> void:
	L10n.scale_menu()
