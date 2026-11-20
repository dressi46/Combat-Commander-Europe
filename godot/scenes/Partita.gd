## Schermata di gioco.
##
## È un «lettore di decisioni»: a ogni momento mostra CHI deve fare COSA
## (riquadro Guida), evidenzia sulla mappa e nella mano solo ciò che è legale
## toccare, elenca le alternative come pulsanti e racconta in Cronaca tutto
## quello che accade, comprese le mosse dell'avversario una alla volta.
extends Control

const CARD_W := 112.0
const CARD_H := 155.0
const SIDE_W := 390.0

var board: Board2D
var board_holder: Control
var view3d: SubViewportContainer = null
var status_strip := BattleStatus.new()
var who_lbl: Label
var guide: RichTextLabel
var opts_box: VBoxContainer
var info: RichTextLabel
var log_box: RichTextLabel
var hand_box: HBoxContainer
var foe_lbl: Label
var title_lbl: Label
var skip_btn: Button
var preview: Control
var preview_card: CardView
var preview_lbl: Label
var dice_box: PanelContainer
var dice_col: VBoxContainer
var dice_row: HBoxContainer
var dice_a: TextureRect
var dice_b: TextureRect
var dice_lbl: Label
var played_box: PanelContainer
var played_card: CardView
var played_lbl: Label
var overlay: Control
var stack_pop: PopupPanel
var help_panel: PanelContainer
var step_btn: Button
var controls := MenuButton.new()

var mobile_panels: Array[Control] = []
var mobile_tabs := HBoxContainer.new()
var mobile_page := 0

const BattleReport = preload("res://scenes/BattleReport.gd")
var active_report: BattleReport
var side_scroll := ScrollContainer.new()
var option_scroll := ScrollContainer.new()
var side_column := VBoxContainer.new()
var log_heading: Label
var turn_banner := Label.new()
var mobile := false

func _layout_for_screen() -> void:
	var window := get_window()
	var changed := mobile != L10n.small_screen()
	mobile = L10n.small_screen()
	window.content_scale_size = Vector2i(480, 460) if mobile else Vector2i(1280, 800)
	mobile_tabs.visible = mobile
	for i in mobile_tabs.get_child_count():
		mobile_tabs.get_child(i).set_pressed_no_signal(i == mobile_page)
	title_lbl.visible = not mobile
	status_strip.compact = mobile
	status_strip.refresh()
	for i in mobile_panels.size():
		mobile_panels[i].visible = not mobile or i == mobile_page
	mobile_panels[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_SHRINK_END
	mobile_panels[2].size_flags_vertical = Control.SIZE_EXPAND_FILL if mobile else Control.SIZE_SHRINK_END
	mobile_panels[0].get_parent().visible = not mobile or mobile_page != 2
	foe_lbl.visible = not mobile
	turn_banner.visible = mobile
	log_heading.visible = not mobile
	log_box.visible = not mobile
	side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if mobile else ScrollContainer.SCROLL_MODE_DISABLED
	if mobile and opts_box.get_parent() == option_scroll:
		opts_box.reparent(side_column, false)
		side_column.move_child(opts_box, option_scroll.get_index())
		option_scroll.hide()
	elif not mobile and opts_box.get_parent() == side_column:
		opts_box.reparent(option_scroll, false)
		option_scroll.show()
	# Dadi: su mobile la scritta va sotto i dadi (niente sovrapposizioni con
	# la carta giocata); su desktop resta la riga unica.
	if mobile:
		if dice_lbl.get_parent() == dice_row:
			dice_lbl.reparent(dice_col, false)
		dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
		dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dice_lbl.custom_minimum_size.x = 190
		dice_lbl.add_theme_font_size_override("font_size", 16)
		played_card.custom_minimum_size = Vector2(110, 153)
		played_lbl.custom_minimum_size.x = 110
		played_lbl.add_theme_font_size_override("font_size", 13)
		latest.add_theme_font_size_override("font_size", 14)
	else:
		if dice_lbl.get_parent() == dice_col:
			dice_lbl.reparent(dice_row, false)
		dice_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dice_lbl.custom_minimum_size.x = 250
		dice_lbl.remove_theme_font_size_override("font_size")
		played_card.custom_minimum_size = Vector2(150, 208)
		played_lbl.custom_minimum_size.x = 150
		played_lbl.add_theme_font_size_override("font_size", 15)
		latest.remove_theme_font_size_override("font_size")
	if changed:
		_refresh.call_deferred()



func _exit_tree() -> void:
	get_window().content_scale_size = Vector2i(1280, 800)


var _sel_card := -1
var _dice_until := 0
var _played_until := 0
var _log_lines := 0
var latest := Label.new()


func _ready() -> void:
	theme = Tema.get_theme()
	if Game.flow == null:
		Game.start_new_game(Flow.AX, 1, 1)
	_build()
	_layout_for_screen()
	get_window().size_changed.connect(_layout_for_screen)
	Game.decision_changed.connect(_refresh)
	Game.state_changed.connect(_refresh_status)
	Game.chronicle.connect(_on_event)
	Game.stack_offered.connect(_on_stack)
	Game.game_over.connect(_on_game_over)
	_refresh()
	_refresh_status()
	if Game.mode == Game.Mode.ONLINE:
		Online.show_events()


# ═══ Costruzione ═════════════════════════════════════════════════════════════

func _btn(text: String, tip: String = "", min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	return b


func _rich(min_h: float = 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = min_h <= 0.0
	r.scroll_active = min_h > 0.0
	r.custom_minimum_size = Vector2(SIDE_W - 40.0, min_h)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Tema.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 6
	root.offset_top = 6
	root.offset_right = -6
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# ── Riga 1: titolo e comandi ────────────────────────────────────────────
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	root.add_child(turn_banner)
	turn_banner.add_theme_color_override("font_color", Tema.BRASS)
	root.add_child(mobile_tabs)
	for caption in ["Board", "Decisions", "Hand"]:
		var tab := _btn(L10n.t(caption))
		tab.toggle_mode = true
		tab.custom_minimum_size.y = 48
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := mobile_tabs.get_child_count()
		tab.pressed.connect(func():
			mobile_page = idx
			_layout_for_screen())
		mobile_tabs.add_child(tab)
	title_lbl = Tema.title("", 20)
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.custom_minimum_size.x = 230
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title_lbl)
	var dispatch := PanelContainer.new()
	dispatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper := Tema.box(Color("#302e22"), Tema.BRASS, 0, 2, 7)
	paper.border_width_left = 3
	dispatch.add_theme_stylebox_override("panel", paper)
	bar.add_child(dispatch)
	latest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	latest.max_lines_visible = 3
	latest.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	latest.add_theme_color_override("font_color", Tema.INK)
	dispatch.add_child(latest)
	controls.flat = false
	controls.text = L10n.t("Controls")
	controls.custom_minimum_size.y = 44
	bar.add_child(controls)
	controls.about_to_popup.connect(_fill_controls)
	controls.get_popup().id_pressed.connect(_control_action)
	root.add_child(status_strip)
	status_strip.inspected.connect(func(heading: String, body: String, key: String): _reading_dialog(heading, body, false, false, key))

	# ── Centro: mappa + pannello laterale ───────────────────────────────────
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	root.add_child(mid)
	board_holder = Control.new()
	board_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_holder.custom_minimum_size = Vector2(320, 200)
	board_holder.clip_contents = true
	mid.add_child(board_holder)
	board = Board2D.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_holder.add_child(board)
	board.hex_info.connect(_show_hex_info)
	_build_overlays()

	var side := PanelContainer.new()
	side.custom_minimum_size.x = SIDE_W
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(side)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	var sv := side_column
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 6)
	side_scroll.add_child(sv)
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", Tema.box(Tema.PANEL_HI, Tema.BRASS, 2, 4, 8))
	sv.add_child(gp)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	gp.add_child(gv)
	who_lbl = Tema.title("", 20)
	who_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who_lbl.custom_minimum_size.x = SIDE_W - 40.0
	gv.add_child(who_lbl)
	guide = _rich()
	guide.add_theme_font_size_override("normal_font_size", 19)
	guide.add_theme_font_size_override("bold_font_size", 19)
	gv.add_child(guide)
	skip_btn = _btn(L10n.t("Mostra subito (SPAZIO)"), L10n.t("Salta l'attesa e mostra subito l'esito"))
	skip_btn.pressed.connect(func() -> void: Game.skip())
	gv.add_child(skip_btn)
	var osc := option_scroll
	osc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	osc.custom_minimum_size.y = 40
	osc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	osc.size_flags_stretch_ratio = 1.1
	sv.add_child(osc)
	opts_box = VBoxContainer.new()
	opts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_box.add_theme_constant_override("separation", 5)
	osc.add_child(opts_box)
	info = _rich()
	info.add_theme_font_size_override("normal_font_size", 16)
	info.add_theme_font_size_override("bold_font_size", 16)
	info.add_theme_color_override("default_color", Tema.DIM.lightened(0.2))
	sv.add_child(info)
	log_heading = Tema.title(L10n.t("CRONACA"), 16)
	sv.add_child(log_heading)
	log_box = _rich(120)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 16)
	log_box.add_theme_font_size_override("bold_font_size", 16)
	sv.add_child(log_box)

	# ── In basso: la mano ───────────────────────────────────────────────────
	var hp := PanelContainer.new()
	hp.custom_minimum_size.y = CARD_H + 20
	root.add_child(hp)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hp.add_child(hh)
	foe_lbl = Label.new()
	foe_lbl.custom_minimum_size.x = 190
	foe_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foe_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foe_lbl.add_theme_font_size_override("font_size", 16)
	foe_lbl.add_theme_color_override("font_color", Tema.DIM.lightened(0.15))
	hh.add_child(foe_lbl)
	var hsc := ScrollContainer.new()
	hsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hsc)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 8)
	hsc.add_child(hand_box)
	mobile_panels.assign([board_holder, side, hp])
	title_lbl.text = L10n.t(Game.state.scenario_name).to_upper()
	if Game.state.scenario_number < 1000:
		title_lbl.text = "%d · %s" % [Game.state.scenario_number, title_lbl.text]
	title_lbl.tooltip_text = title_lbl.text


func _build_overlays() -> void:
	# Dadi dell'ultimo tiro.
	dice_box = PanelContainer.new()
	dice_box.add_theme_stylebox_override("panel", Tema.box(Color(0.05, 0.05, 0.04, 0.92), Tema.BRASS, 2, 6, 8))
	dice_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dice_box.offset_top = 8
	dice_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_box.visible = false
	board_holder.add_child(dice_box)
	dice_col = VBoxContainer.new()
	dice_col.add_theme_constant_override("separation", 4)
	dice_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_box.add_child(dice_col)
	dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 8)
	dice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_col.add_child(dice_row)
	dice_a = TextureRect.new()
	dice_b = TextureRect.new()
	for d: TextureRect in [dice_a, dice_b]:
		d.custom_minimum_size = Vector2(54, 54)
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dice_row.add_child(d)
	dice_lbl = Label.new()
	dice_lbl.custom_minimum_size.x = 250
	dice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_lbl.add_theme_font_override("font", Tema.bold_font())
	dice_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_row.add_child(dice_lbl)

	# Carta appena giocata.
	played_box = PanelContainer.new()
	played_box.add_theme_stylebox_override("panel", Tema.box(Color(0.05, 0.05, 0.04, 0.92), Tema.BRASS, 2, 6, 6))
	played_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	played_box.offset_left = 8
	played_box.offset_top = 8
	played_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_box.visible = false
	board_holder.add_child(played_box)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_box.add_child(pv)
	played_lbl = Label.new()
	played_lbl.custom_minimum_size.x = 150
	played_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	played_lbl.add_theme_font_override("font", Tema.bold_font())
	played_lbl.add_theme_font_size_override("font_size", 15)
	played_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(played_lbl)
	played_card = CardView.new()
	played_card.custom_minimum_size = Vector2(150, 208)
	played_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_card.playable = true
	played_card.selected = true
	pv.add_child(played_card)

	# Anteprima grande della carta scelta in mano.
	preview = PanelContainer.new()
	(preview as PanelContainer).add_theme_stylebox_override("panel", Tema.box(Color(0.05, 0.05, 0.04, 0.95), Tema.BRASS, 2, 6, 8))
	preview.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	preview.offset_left = 8
	preview.offset_bottom = -8
	preview.grow_vertical = Control.GROW_DIRECTION_BEGIN
	preview.visible = false
	board_holder.add_child(preview)
	var pvv := VBoxContainer.new()
	preview.add_child(pvv)
	preview_card = CardView.new()
	preview_card.custom_minimum_size = Vector2(236, 327)
	preview_card.playable = true
	preview_card.selected = true
	preview_card.tapped.connect(func(_v: CardView) -> void: _select_card(-1))
	pvv.add_child(preview_card)
	preview_lbl = Label.new()
	preview_lbl.custom_minimum_size.x = 236
	preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_lbl.add_theme_font_size_override("font_size", 16)
	pvv.add_child(preview_lbl)

	# Passo manuale dell'IA: resta sulla mappa, visibile anche da mobile.
	step_btn = _btn(L10n.t("Next AI step"), L10n.t("Manual mode: advance the AI by one decision (SPACE)"))
	step_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	step_btn.offset_right = -8
	step_btn.offset_bottom = -8
	step_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	step_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	step_btn.custom_minimum_size = Vector2(210, 52)
	step_btn.add_theme_stylebox_override("normal", Tema.box(Tema.BRASS.darkened(0.55), Tema.BRASS, 2, 4, 8))
	step_btn.visible = false
	step_btn.pressed.connect(func() -> void: Game.manual_step())
	board_holder.add_child(step_btn)

	# Scelta fra più pedine/opzioni nello stesso esagono.
	stack_pop = PopupPanel.new()
	add_child(stack_pop)

	# Aiuto.
	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", Tema.box(Color(0.07, 0.08, 0.06, 0.97), Tema.BRASS, 2, 6, 14))
	help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_panel.offset_left = 20
	help_panel.offset_top = 20
	help_panel.offset_right = -20
	help_panel.offset_bottom = -20
	help_panel.visible = false
	board_holder.add_child(help_panel)
	var hv := VBoxContainer.new()
	help_panel.add_child(hv)
	var hr := RichTextLabel.new()
	hr.bbcode_enabled = true
	hr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hr.custom_minimum_size = Vector2(280, 120)
	hr.text = _help_text()
	hv.add_child(hr)
	var hc := _btn(L10n.t("Chiudi"))
	hc.pressed.connect(func() -> void: help_panel.visible = false)
	hv.add_child(hc)

	# Fine partita.
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)


func _help_text() -> String:
	var t := L10n.t("[b]COME SI GIOCA — in breve[/b]\n\n")
	t += L10n.t("[b]Il turno.[/b] Nel tuo turno giochi carte dalla mano come ORDINI (il numero massimo è indicato nello scenario), uno alla volta, vedendo l'esito prima di decidere il successivo. In alternativa, se non dai ordini, puoi SCARTARE carte. A fine turno ripeschi fino a riempire la mano.\n\n")
	t += L10n.t("[b]Attivare.[/b] Mossa, Fuoco e Avanzata attivano un'unità. Se attivi un COMANDANTE, lui attiva anche gli uomini entro il suo raggio di Comando (il numero nell'esagono sulla pedina): è il modo per far agire più unità con una carta sola. Ogni unità si attiva una sola volta per turno.\n\n")
	t += L10n.t("[b]Mossa.[/b] Ogni unità attivata muove un esagono alla volta spendendo Punti Movimento. A ogni esagono l'avversario può reagire col FUOCO DI OPPORTUNITÀ.\n\n")
	t += L10n.t("[b]Fuoco.[/b] Scegli il bersaglio, componi il gruppo di fuoco (il pezzo più forte dà il suo FP, ogni altro +1), aggiungi eventuali Azioni e tira: FP + dadi contro Morale + copertura + dadi di ogni difensore. Se l'attacco è più alto l'unità si rompe (se già rotta è eliminata); se è pari viene soppressa.\n\n")
	t += L10n.t("[b]Avanzata.[/b] Un solo esagono, senza subire fuoco, anche dentro un esagono nemico: lì si risolve il CORPO A CORPO (FP + dadi, chi perde è eliminato).\n\n")
	t += L10n.t("[b]Recupero e Ritirata.[/b] Il Recupero toglie le soppressioni e fa tirare le tue unità rotte per riprendersi. La Ritirata fa arretrare le unità rotte (di solito quelle nemiche) verso il loro bordo.\n\n")
	t += L10n.t("[b]Dadi e inneschi.[/b] Ogni tiro è una carta pescata dal mazzo: può far scattare TEMPO!, CECCHINO!, EVENTO! o INCEPPAMENTO!. Chi ha la carta INIZIATIVA può far ripetere un tiro cedendola all'avversario.\n\n")
	t += L10n.t("[b]Vittoria.[/b] Punti Vittoria da obiettivi, unità eliminate e unità uscite dal bordo nemico. Quando il Tempo raggiunge la Morte Subitanea, a ogni avanzamento si tira per chiudere la partita. Chi supera il proprio limite di perdite si arrende.\n")
	var sr := ScenarioRules.as_bbcode(Game.state.scenario_number)
	if sr != "":
		t += L10n.t("\n[b]REGOLE SPECIALI DELLO SCENARIO[/b]\n") + sr
	return t


# ═══ Plancia in alto ═════════════════════════════════════════════════════════

func _refresh_status() -> void:
	status_strip.refresh()


func _fill_controls() -> void:
	var popup := controls.get_popup()
	popup.clear()
	popup.add_item(L10n.t("CRONACA"), 0)
	popup.add_item(L10n.t("Vista 2D" if view3d != null and view3d.visible else "Vista 3D"), 1)
	popup.add_item(L10n.t("Centra"), 2)
	if Game.mode != Game.Mode.ONLINE:
		popup.add_item(L10n.t("Ritmo: %s") % L10n.t(Game.SPEED_LABELS[Game.speed_index()]), 3)
		popup.add_item(L10n.t("Riprendi" if Game.paused else "Pausa"), 4)
		popup.add_item(L10n.t("Manual AI steps"), 7)
		popup.set_item_checked(popup.get_item_index(7), Game.manual)
	popup.add_item(L10n.t("Come si gioca"), 5)
	popup.add_separator()
	popup.add_item(L10n.t("Torna al menu degli scenari"), 6)


func _control_action(id: int) -> void:
	match id:
		0: _open_history()
		1: _toggle_3d()
		2:
			board.reset_view()
			if view3d != null and view3d.visible:
				var scene := view3d.get_child(0).get_child(0)
				scene._reset_camera()
				scene._update_camera()
		3: _cycle_speed()
		4: _toggle_pause()
		5: help_panel.visible = not help_panel.visible
		6: _exit_board()
		7: Game.set_manual(not Game.manual)


# ═══ Decisione corrente ══════════════════════════════════════════════════════

func _refresh() -> void:
	var fl := Game.flow
	if fl == null:
		return
	var p := Game.pending()
	for c in opts_box.get_children():
		opts_box.remove_child(c)
		c.queue_free()
	skip_btn.visible = Game.busy and not fl.over
	step_btn.visible = Game.manual_waiting()
	if fl.over:
		who_lbl.text = L10n.t("PARTITA FINITA")
		guide.text = L10n.t("Vincono i [b]%s[/b].\n%s") % [fl.side_name(fl.winner), fl.end_reason]
	elif Game.mode == Game.Mode.ONLINE and Online.disconnected_player:
		who_lbl.text = L10n.t("Match paused")
		guide.text = L10n.t("Waiting for the other player to reconnect")
	elif p.is_empty():
		var who := int(fl.pending.get("who", fl.s.active_faction))
		who_lbl.text = L10n.t("%s IN AZIONE") % fl.side_name(who).to_upper()
		who_lbl.add_theme_color_override("font_color", Tema.side_color(who))
		guide.text = L10n.t("Segui in Cronaca e sulla mappa che cosa succede.")
		if Game.is_human(who):
			guide.text = L10n.t("Risoluzione in corso...")
		if Game.manual_waiting():
			guide.text = L10n.t("Manual mode: the AI is waiting. Press «Next AI step» to see its next move.")
	else:
		var who2 := int(p["who"])
		who_lbl.text = L10n.t("TOCCA A TE — %s") % fl.side_name(who2).to_upper()
		if fl.s.active_faction != who2 and not String(p["kind"]).begins_with("setup"):
			who_lbl.text = L10n.t("REAGISCI — %s") % fl.side_name(who2).to_upper()
		who_lbl.add_theme_color_override("font_color", Tema.side_color(who2))
		guide.text = String(p["title"])
		var order := int(p.get("order", OrderNotes.DECISIONS.get(p.kind, -1)))
		if order >= 0:
			guide.text += "\n" + OrderNotes.describe(order)
		_build_options(p)
	turn_banner.text = who_lbl.text
	if not p.is_empty() and String(p.kind) == "turn":
		turn_banner.text += "   ·   " + L10n.t("Orders %d/%d") % [fl.orders_done, fl.orders_max[p.who]]
	if mobile:
		if not p.is_empty():
			mobile_page = 1
			side_scroll.scroll_vertical = 0
		elif Game.busy:
			mobile_page = 0
		_layout_for_screen()
	_refresh_hand(p)
	_refresh_status()
	board.queue_redraw()


func _build_options(p: Dictionary) -> void:
	var opts: Array = p["options"]
	var kind := String(p["kind"])
	var hex_n := 0
	var unit_n := 0
	for o: Dictionary in opts:
		if o.has("hex"):
			hex_n += 1
		elif o.has("unit"):
			unit_n += 1
	if kind == "move":
		opts_box.add_child(_hint(L10n.t("O21 · Each hex shows MP cost → MP left after entry.")))
		if hex_n == 1:
			for option: Dictionary in opts:
				if option.get("id") == "step":
					opts_box.add_child(_hint(String(option.label)))
	elif hex_n > 0:
		opts_box.add_child(_hint(L10n.t("Tocca sulla mappa uno degli esagoni evidenziati (%d).") % hex_n))
	if unit_n > 0 and kind in ["activate", "pick_mover", "sniper", "ambush_victim", "spotter", "deploy", "setup"]:
		opts_box.add_child(_hint(L10n.t("Tocca sulla mappa una delle pedine col bordo dorato, oppure scegli dall'elenco.")))
	for i in opts.size():
		var o: Dictionary = opts[i]
		# Gli esagoni si scelgono sulla mappa; le carte dalla mano (tranne le
		# Azioni proposte in una finestra, che compaiono anche qui).
		if not mobile and o.has("hex") and not o.has("card"):
			continue
		if not mobile and o.has("card") and kind in ["turn", "discard"]:
			continue
		if not mobile and kind == "setup" and o.has("unit"):
			continue
		var b := _btn(String(o.get("label", o.get("id", "?"))))
		if mobile and o.has("card"):
			b.text = "#%d   %s" % [Game.flow.hand(p.who)[o.card].number, b.text]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(SIDE_W - 44.0, 52 if mobile else 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := String(o.get("id", ""))
		if id in ["confirm", "go", "end", "pass", "stop", "no", "stay", "keep"]:
			b.add_theme_stylebox_override("normal", Tema.box(Tema.BRASS.darkened(0.55), Tema.BRASS, 2, 4, 8))
		if o.has("on") and bool(o["on"]):
			b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
		b.pressed.connect(func() -> void: _choose_if_current.call_deferred(p, i))
		opts_box.add_child(b)
	if kind == "turn":
		var blocked: Dictionary = p.get("blocked", {})
		opts_box.add_child(_hint(L10n.t("Tocca una carta in mano per vederla in grande e giocarla. Le carte col bordo dorato sono giocabili ora; di quelle scurite ti dico il perché.")))
		if not blocked.is_empty() and blocked.size() == Game.flow.hand(int(p["who"])).size():
			opts_box.add_child(_hint(L10n.t("Nessuna carta è giocabile come Ordine in questo momento: scarta per pescarne di nuove.")))
	elif kind == "discard":
		opts_box.add_child(_hint(L10n.t("Tocca le carte in mano per segnarle da scartare.")))


func _choose_if_current(decision: Dictionary, index: int) -> void:
	if is_same(decision, Game.pending()):
		Game.choose(index)


func _hint(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = SIDE_W - 44.0
	l.add_theme_color_override("font_color", Tema.DIM.lightened(0.25))
	l.add_theme_font_size_override("font_size", 16)
	return l


# ═══ Mano ════════════════════════════════════════════════════════════════════

func _refresh_hand(p: Dictionary) -> void:
	var fl := Game.flow
	var me := Game.viewer()
	var foe := fl.opp(me)
	for c in hand_box.get_children():
		c.queue_free()
	var h := fl.hand(me)
	var playable := {}
	var marked: Array = p.get("selected_cards", [])
	if not p.is_empty() and int(p["who"]) == me:
		for o: Dictionary in p["options"]:
			if o.has("card"):
				playable[int(o["card"])] = true
	if _sel_card >= h.size():
		_sel_card = -1
	for i in h.size():
		var cv := CardView.new()
		cv.custom_minimum_size = Vector2(CARD_W, CARD_H)
		cv.setup(h[i], i)
		cv.playable = playable.has(i)
		cv.selected = i == _sel_card
		cv.marked = marked.has(i)
		cv.face_down = Game.mode == Game.Mode.DEMO
		cv.tapped.connect(_on_card_tapped)
		hand_box.add_child(cv)
	foe_lbl.text = L10n.t("%s\nin mano %d carte · mazzo %d\n\n%s (tu)\nmazzo %d · scarti %d\nOrdini: %d di %d") % [
		fl.side_name(foe).to_upper(), _pile_count(foe, 0), _pile_count(foe, 1),
		fl.side_name(me).to_upper(), _pile_count(me, 1), _pile_count(me, 2),
		fl.orders_done if fl.s.active_faction == me else 0, int(fl.orders_max[me])]
	_refresh_preview(p)


func _on_card_tapped(v: CardView) -> void:
	var p := Game.pending()
	if mobile:
		var reason := String(p.get("blocked", {}).get(v.index, ""))
		var dialog := _reading_dialog("#%d · %s" % [v.card.number, L10n.t("Hand")], reason, false)
		var col := dialog.contents
		var face := CardView.new()
		face.custom_minimum_size = Vector2(182, 254)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		face.setup(v.card, v.index)
		face.playable = true
		col.add_child(face)
		for index: int in _card_options(p, v.index):
			var action := _btn(p.options[index].label)
			action.custom_minimum_size.y = 52
			action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action.pressed.connect(func():
				dialog.hide()
				dialog.confirmed.emit()
				if is_same(p, Game.pending()):
					Game.choose(index))
			col.add_child(action)
			col.move_child(action, 0)
		return
	if not p.is_empty() and String(p["kind"]) == "discard":
		var opts: Array = p["options"]
		for i in opts.size():
			if String(opts[i].get("id", "")) == "toggle" and int(opts[i].get("card", -1)) == v.index:
				Game.choose(i)
				return
		return
	# Secondo tocco sulla stessa carta: se c'è un solo modo di giocarla, giocala.
	if v.index == _sel_card:
		var mine := _card_options(p, v.index)
		if mine.size() == 1:
			_sel_card = -1
			Game.choose(mine[0])
			return
	_select_card(v.index)


func _card_options(p: Dictionary, card_index: int) -> Array:
	var out: Array = []
	if p.is_empty():
		return out
	var opts: Array = p["options"]
	for i in opts.size():
		if opts[i].has("card") and int(opts[i]["card"]) == card_index:
			out.append(i)
	return out


func _select_card(i: int) -> void:
	_sel_card = -1 if i == _sel_card else i
	_refresh_hand(Game.pending())


func _refresh_preview(p: Dictionary) -> void:
	var h := Game.flow.hand(Game.viewer())
	if _sel_card < 0 or _sel_card >= h.size() or Game.mode == Game.Mode.DEMO:
		preview.visible = false
		return
	preview.visible = true
	preview_card.setup(h[_sel_card], _sel_card)
	for c in preview.get_child(0).get_children():
		if c is Button:
			c.queue_free()
	var mine := _card_options(p, _sel_card)
	if mine.is_empty():
		var why := String((p.get("blocked", {}) as Dictionary).get(_sel_card, ""))
		if why == "":
			why = L10n.t("Ora non c'è modo di giocare questa carta. Le Azioni si giocano quando il gioco te le propone (durante un fuoco, una mossa, una difesa...).")
		preview_lbl.text = why
	else:
		preview_lbl.text = L10n.t("Tocca di nuovo la carta o il pulsante per giocarla.")
		for oi: int in mine:
			var b := _btn(L10n.t("GIOCA — %s") % String(p["options"][oi].get("label", "")))
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(236, 40)
			b.add_theme_stylebox_override("normal", Tema.box(Tema.BRASS.darkened(0.55), Tema.BRASS, 2, 4, 8))
			b.pressed.connect(func() -> void:
				_sel_card = -1
				Game.choose(oi))
			preview.get_child(0).add_child(b)


# ═══ Cronaca, dadi, carta giocata ════════════════════════════════════════════

const KIND_COL := {
	"turn": "#e0c060", "order": "#f0e8c8", "fire": "#f0a070", "roll": "#b8c8d8",
	"bad": "#f08070", "kill": "#ff6050", "good": "#90d890", "vp": "#f0d040",
	"time": "#e0b040", "fate": "#90c0f0", "melee": "#f09050", "end": "#ffffff",
	"miss": "#a8a8a0", "move": "#c8c8b8", "init": "#d0a0f0",
}


func _on_event(ev: Dictionary) -> void:
	var kind := String(ev.get("kind", ""))
	if kind == "event_report":
		if Game.tutorial_enabled and Game.mode == Game.Mode.VS_AI:
			_show_event_report(ev)
		return
	var col := String(KIND_COL.get(kind, "#c8c8b8"))
	var line := String(ev.get("text", ""))
	if ev.has("order"):
		line += " · " + OrderNotes.describe(int(ev.order))
	elif ev.has("rule"):
		line += " · " + str(ev.rule)
	if kind == "move":
		line += " · O21"
	latest.text = _plain(line)
	latest.tooltip_text = latest.text
	if kind == "turn":
		log_box.append_text("\n")
	log_box.append_text("[color=#aba99b]%d[/color]  [color=%s]%s[/color]\n" % [_log_lines + 1, col, line])
	_log_lines += 1
	if kind == "roll" and ev.has("dice"):
		var d: Array = ev["dice"]
		dice_a.texture = load("res://assets/dice/w%d.png" % clampi(int(d[0]), 1, 6))
		dice_b.texture = load("res://assets/dice/r%d.png" % clampi(int(d[1]), 1, 6))
		dice_lbl.text = _plain(String(ev.get("text", "")))
		dice_box.visible = true
		# Più tempo per leggere col ritmo lento; mai meno di ~2,6 s.
		_dice_until = Time.get_ticks_msec() + clampi(int(3600.0 / maxf(0.55, Game.speed)), 2600, 8000)
	if ev.has("card") and ev["card"] is Card:
		played_card.setup(ev["card"], -1)
		played_card.queue_redraw()
		var who := int(ev.get("who", -1))
		played_lbl.text = L10n.t("%s: carta giocata") % (Game.flow.side_name(who) if who >= 0 else "")
		played_box.visible = true
		_played_until = Time.get_ticks_msec() + 2600


func _show_event_report(ev: Dictionary) -> void:
	var title := L10n.t(String(ev.name)).capitalize()
	var note: Array = OrderNotes.EVENT_RULES.get(ev.name, ["E42", "E42 · The Event trigger reveals the event on the next Fate card."])
	var details := PackedStringArray(ev.outcomes)
	if details.is_empty():
		details.append(L10n.t("No further effect was recorded."))
	var description := "[b]%s · %s[/b]\n%s\n\n%s\n\n%s" % [note[0], title,
		Game.flow.side_name(int(ev.who)), L10n.t(note[1]),
		"\n".join(details)]
	_reading_dialog(L10n.t("Event resolution"), description, true)


func _open_history() -> void:
	_reading_dialog(L10n.t("CRONACA"), log_box.get_parsed_text(), false, true)


func _reading_dialog(title: String, content: String, formatted: bool, scroll_end: bool = false, key: String = "") -> BattleReport:
	if is_instance_valid(active_report):
		active_report.confirmed.emit()
	var pause_here := Game.mode != Game.Mode.ONLINE and not Game.paused
	if pause_here:
		Game.set_paused(true)
	var dialog := BattleReport.new()
	active_report = dialog
	add_child(dialog)
	var layout := mobile_tabs.get_parent() as Control
	layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	dialog.setup(title)
	var col := dialog.contents
	_status_counters(col, key)
	var body := RichTextLabel.new()
	body.bbcode_enabled = formatted
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.text = content
	col.add_child(body)
	var resume := func():
		dialog.hide()
		active_report = null
		layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		if pause_here:
			Game.set_paused(false)
		dialog.queue_free()
	dialog.confirmed.connect(resume)
	if scroll_end:
		dialog.scroll.set_deferred("scroll_vertical", 100000)
	return dialog


func _status_counters(col: VBoxContainer, key: String) -> void:
	var s := Game.state
	var row := HFlowContainer.new()
	col.add_child(row)
	match key:
		"Clock":
			for n in range(maxi(12, maxi(s.time_marker, s.sudden_death_space)) + 1):
				var cell := Button.new()
				cell.text = str(n)
				cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.focus_mode = Control.FOCUS_NONE
				cell.custom_minimum_size = Vector2(58, 46)
				var fill := Tema.RED.darkened(0.55) if n >= s.sudden_death_space else Tema.PANEL_HI
				cell.add_theme_stylebox_override("normal", Tema.box(fill, Tema.BRASS if n == s.time_marker else Tema.EDGE, 3 if n == s.time_marker else 1, 0, 3))
				if n == s.time_marker:
					cell.icon = preload("res://assets/track/time.svg")
					cell.add_theme_constant_override("icon_max_width", 20)
				row.add_child(cell)
		"Objectives":
			var viewer := Game.viewer()
			var private_chits := s.objective_chits.filter(func(t): return not t.revealed and int(t.owner) == viewer)
			if private_chits.is_empty() or Game.mode == Game.Mode.DEMO:
				return
			col.add_child(_hint("%s (%d)" % [L10n.t("Private objectives · %s") % Game.flow.side_name(viewer), private_chits.size()]))
			for i in private_chits.size():
				var chit: Dictionary = private_chits[i]
				var back := L10n.t("Inspect secret counter %d") % (i + 1)
				var tile := _btn(back)
				tile.icon = preload("res://assets/track/objective.svg")
				tile.toggle_mode = true
				tile.custom_minimum_size.y = 48
				tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				tile.toggled.connect(func(open: bool):
					tile.text = ObjectiveChits._describe(ObjectiveChits._find(chit.letter)) if open and viewer == Game.viewer() else back)
				col.add_child(tile)
		"Initiative":
			_counter_image(row, preload("res://assets/track/initiative.svg"), Game.flow.side_name(s.initiative_holder))
		"Axis losses", "Allied losses":
			for u: Unit in s.graves:
				if u.faction == (Flow.AX if key == "Axis losses" else Flow.AL):
					_counter_image(row, board._counter_tex(u), L10n.unit_label(u.display_name))


func _counter_image(row: Container, texture: Texture2D, caption: String) -> void:
	if texture == null:
		return
	var pic := TextureRect.new()
	pic.texture = texture
	pic.tooltip_text = caption
	pic.accessibility_name = caption
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(72, 72)
	row.add_child(pic)


func _plain(bb: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	return re.sub(bb, "", true)


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec()
	# Mentre si legge un rapporto (gioco in pausa) dadi e carta restano visibili.
	if Game.paused:
		if dice_box.visible:
			_dice_until = now + 1500
		if played_box.visible:
			_played_until = now + 1500
	if dice_box.visible and now > _dice_until:
		dice_box.visible = false
	if played_box.visible and now > _played_until:
		played_box.visible = false
	if skip_btn.visible != (Game.busy and not Game.flow.over):
		skip_btn.visible = Game.busy and not Game.flow.over
	if step_btn.visible != Game.manual_waiting():
		step_btn.visible = Game.manual_waiting()


# ═══ Informazioni su esagono e pedine ════════════════════════════════════════

func _show_hex_info(q: int, r: int) -> void:
	var s := Game.state
	var hd: GameState.HexData = s.hex_at(q, r)
	if hd == null:
		return
	var t := L10n.t("[b]%s[/b] · %s · copertura %+d") % [Domain.qr_to_label(q, r),
		L10n.t(Domain.TERRAIN_NAMES.get(hd.terrain, "?")), Rules.cover_at(s, q, r, false)]
	if hd.has_road:
		t += L10n.t(" · strada")
	if hd.elevation > 0:
		t += L10n.t(" · quota %d") % hd.elevation
	if hd.has_foxhole:
		t += L10n.t(" · buche")
	if hd.fortification != Domain.Fort.NONE:
		t += " · " + L10n.t(Domain.FORT_NAMES.get(hd.fortification, ""))
	if hd.has_smoke:
		t += L10n.t(" · fumo")
	for u in s.units_at(q, r):
		if u.is_weapon():
			continue
		t += L10n.t("\n[b]%s[/b] — FP %d · gittata %d · mov. %d · morale %d") % [u.display_name, u.fp, u.range, u.move, u.morale]
		if u.is_leader():
			t += L10n.t(" · comando %d") % u.command
		var st: Array = []
		if not u.efficient:
			st.append(L10n.t("rotta"))
		if u.suppressed:
			st.append(L10n.t("soppressa"))
		if u.activated:
			st.append(L10n.t("già attivata"))
		if not st.is_empty():
			t += " (" + ", ".join(st) + ")"
		var w := s.weapon_carried_by(u.id)
		if w != null:
			t += L10n.t("\n     con %s — FP %d · gittata %d%s") % [w.display_name, w.fp, w.range, "" if w.efficient else L10n.t(" (guasta)")]
	info.text = t


# ═══ Comandi vari ════════════════════════════════════════════════════════════

func _on_stack(indices: Array) -> void:
	var p := Game.pending()
	if p.is_empty():
		return
	for c in stack_pop.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	stack_pop.add_child(v)
	var l := Label.new()
	l.text = L10n.t("Più scelte in questo esagono:")
	v.add_child(l)
	for i: int in indices:
		var b := _btn(String(p["options"][i].get("label", "?")))
		b.custom_minimum_size = Vector2(300, 40)
		b.pressed.connect(func() -> void:
			stack_pop.hide()
			Game.choose(i))
		v.add_child(b)
	stack_pop.popup_centered()


func _toggle_3d() -> void:
	if view3d == null:
		view3d = SubViewportContainer.new()
		view3d.stretch = true
		view3d.set_anchors_preset(Control.PRESET_FULL_RECT)
		var vp := SubViewport.new()
		vp.handle_input_locally = false
		vp.physics_object_picking = false
		view3d.add_child(vp)
		var scene: PackedScene = load("res://scenes/Map3D.tscn")
		vp.add_child(scene.instantiate())
		board_holder.add_child(view3d)
		board_holder.move_child(view3d, 1)
		view3d.visible = false
	view3d.visible = not view3d.visible
	board.visible = not view3d.visible


func _cycle_speed() -> void:
	Game.select_speed((Game.speed_index() + 1) % Game.SPEEDS.size())


func _toggle_pause() -> void:
	Game.set_paused(not Game.paused)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if is_instance_valid(active_report):
		if k.keycode == KEY_ESCAPE:
			active_report.confirmed.emit()
		return
	if k.keycode == KEY_SPACE:
		if Game.manual_waiting():
			Game.manual_step()
		elif Game.busy:
			Game.skip()
		else:
			for id in ["confirm", "go", "pass", "no", "keep"]:
				if Game.choose_id(id):
					break
	elif k.keycode == KEY_ESCAPE:
		if _sel_card >= 0:
			_select_card(-1)


func _on_game_over(w: int) -> void:
	overlay.visible = true
	for c in overlay.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var pn := PanelContainer.new()
	pn.add_theme_stylebox_override("panel", Tema.box(Tema.PANEL, Tema.BRASS, 3, 8, 24))
	cc.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pn.add_child(v)
	var fl := Game.flow
	var mine := Game.mode in [Game.Mode.VS_AI, Game.Mode.ONLINE]
	var head := L10n.t("VITTORIA!") if (mine and w == Game.human) else (L10n.t("SCONFITTA") if mine else L10n.t("FINE PARTITA"))
	var t := Tema.title(head, 44, Tema.BRASS if (not mine or w == Game.human) else Tema.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := Label.new()
	l.text = L10n.t("Vincono i %s.\n%s") % [fl.side_name(w), fl.end_reason]
	l.custom_minimum_size.x = 460
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var again := _btn(L10n.t("Rigioca lo scenario"), "", 190)
	again.pressed.connect(func() -> void:
		Game.start_new_game(Game.human, fl.s.scenario_number, Game.difficulty, Game.mode)
		get_tree().reload_current_scene())
	again.visible = Game.mode != Game.Mode.ONLINE
	hb.add_child(again)
	var look := _btn(L10n.t("Guarda la mappa"), "", 160)
	look.pressed.connect(func() -> void: overlay.visible = false)
	hb.add_child(look)
	var back := _btn(L10n.t("Menu"), "", 110)
	back.pressed.connect(_exit_board)
	hb.add_child(back)

func _pile_count(side: int, pile: int) -> int:
	if Game.mode == Game.Mode.ONLINE:
		return Online.counts[side][pile]
	match pile:
		0: return Game.flow.hand(side).size()
		1: return Game.flow.deck(side).size()
		_: return Game.flow.pile(side).size()


func _exit_board() -> void:
	if Game.mode != Game.Mode.ONLINE:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return
	if Game.flow.over:
		Online.leave()
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = L10n.t("Leave and end the match for both players?")
	dialog.ok_button_text = L10n.t("Leave room")
	dialog.cancel_button_text = L10n.t("Annulla")
	dialog.confirmed.connect(Online.leave)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
