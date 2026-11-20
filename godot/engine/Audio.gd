## Effetti sonori e musica della partita (autoload).
##
## Due bus separati («Music» e «SFX») permettono di regolare i volumi in modo
## indipendente. Ogni fase del gioco ha il suo suono: turno, ordine/carta,
## scarto, fuoco, mischia, movimento, dado, evento, tempo, soppressione,
## eliminazione, vittoria e sconfitta. I suoni di interfaccia sono agganciati
## a tutti i pulsanti tramite `node_added`, senza doverli cablare uno per uno.
extends Node

const SOUNDS := {
	"rifle": "res://assets/sounds/RIFLE.wav",
	"mg": "res://assets/sounds/MACH_GUN.wav",
	"artillery": "res://assets/sounds/Artillery.wav",
	"time": "res://assets/sounds/time.wav",
	"morse": "res://assets/sounds/morse.wav",
	"reload": "res://assets/sounds/reload.wav",
	"deck": "res://assets/sounds/Deck Depleted.wav",
	"click": "res://assets/sounds/ui_click.wav",
	"card": "res://assets/sounds/card_play.wav",
	"discard": "res://assets/sounds/card_discard.wav",
	"dice": "res://assets/sounds/dice_roll.wav",
	"step": "res://assets/sounds/move_step.wav",
	"melee": "res://assets/sounds/melee_clash.wav",
	"drum": "res://assets/sounds/turn_drum.wav",
	"order": "res://assets/sounds/order_bark.wav",
	"alarm": "res://assets/sounds/alarm_low.wav",
	"chime": "res://assets/sounds/good_chime.wav",
	"fate": "res://assets/sounds/fate_event.wav",
	"explosion": "res://assets/sounds/explosion.wav",
	"impact": "res://assets/sounds/impact.wav",
	"victory": "res://assets/sounds/victory.wav",
	"defeat": "res://assets/sounds/defeat.wav",
}
const MUSIC := {
	"menu": "res://assets/music/menu_theme.wav",
	"battle": "res://assets/music/battle_theme.wav",
}

var enabled := true
var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ui_player: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active := 0
var _music_current := ""


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for key in SOUNDS:
		var path: String = SOUNDS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for key in MUSIC:
		var stream := _load_music(String(MUSIC[key]))
		if stream != null:
			_music_streams[key] = stream
	for _i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_a)
	add_child(_music_b)
	# Eventi di gioco → suoni.
	Game.chronicle.connect(_on_event)
	Game.game_over.connect(_on_game_over)
	# Un solo clic per ogni pulsante, anche quelli creati dopo.
	get_tree().node_added.connect(_on_node_added)
	for child in get_tree().root.find_children("*", "Button", true, false):
		_hook_button(child)
	apply_volumes()


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func apply_volumes() -> void:
	_apply_bus("Music", Game.music_percent)
	_apply_bus("SFX", Game.sound_percent if enabled else 0)


func _apply_bus(bus_name: String, percent: int) -> void:
	var idx := _ensure_bus(bus_name)
	var value := clampi(percent, 0, 100)
	AudioServer.set_bus_mute(idx, value <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, value / 100.0)))


## Riproduce un effetto sul primo player libero del pool (round-robin).
func play(key: String) -> void:
	if not enabled or not _streams.has(key) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key]
	p.play()


func toggle_mute() -> bool:
	enabled = not enabled
	apply_volumes()
	return enabled


# ─── Musica ──────────────────────────────────────────────────────────────────

func _load_music(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var bytes_per_frame := 2 * (2 if wav.stereo else 1)
		if wav.data.size() > 0:
			wav.loop_end = wav.data.size() / bytes_per_frame
	return stream


## Cambia tema con dissolvenza incrociata. Se è già in riproduzione, non fa nulla.
func play_music(track: String) -> void:
	if track == _music_current or not _music_streams.has(track):
		return
	_music_current = track
	var next := _music_b if _music_active == 0 else _music_a
	var prev := _music_a if _music_active == 0 else _music_b
	next.stream = _music_streams[track]
	next.volume_db = -40.0
	next.play()
	var t := create_tween()
	t.tween_property(next, "volume_db", 0.0, 1.4)
	if prev.playing:
		var t2 := create_tween()
		t2.tween_property(prev, "volume_db", -40.0, 1.4)
		t2.tween_callback(prev.stop)
	_music_active = 1 - _music_active


func stop_music() -> void:
	_music_current = ""
	for p in [_music_a, _music_b]:
		if p != null and p.playing:
			p.stop()


# ─── Handler ──────────────────────────────────────────────────────────────────

func _on_event(ev: Dictionary) -> void:
	match String(ev.get("kind", "")):
		"turn":
			play("drum")
		"order":
			if String(ev.get("rule", "")) == "O15":
				play("discard")
			elif ev.has("card"):
				play("card")
			else:
				play("order")
		"fire":
			_play_fire(ev)
		"roll":
			play("dice")
		"move":
			play("step")
		"melee":
			play("melee")
		"kill":
			play("explosion")
		"bad":
			play("alarm")
		"good", "vp":
			play("chime")
		"time":
			play("time")
		"fate":
			if String(ev.get("fx", "")) == "sniper":
				play("rifle")
			else:
				play("fate")
		"init":
			play("morse")
		"miss":
			play("impact")


func _play_fire(ev: Dictionary) -> void:
	if String(ev.get("fx", "")) == "arty":
		play("artillery")
		return
	var mg := false
	for id in ev.get("pieces", []):
		var u: Unit = Game.state.unit_by_id(String(id)) if Game.state != null else null
		if u != null and u.is_weapon():
			mg = true
			if u.ordnance:
				play("artillery")
				return
	play("mg" if mg else "rifle")


func _on_game_over(winner: int) -> void:
	play("victory" if winner == Game.human else "defeat")


func _on_node_added(node: Node) -> void:
	if node is Button:
		_hook_button(node)


func _hook_button(node: Node) -> void:
	var b := node as Button
	if b != null and not b.pressed.is_connected(_on_click):
		b.pressed.connect(_on_click)


func _on_click() -> void:
	play("click")
