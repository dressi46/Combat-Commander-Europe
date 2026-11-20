extends Node
## Reglas especiales de escenario (Fase 1): comprueba los efectos ya aplicados
## en el motor y su integración con el estado de partida.
## Uso: godot --headless --path godot res://tests/ScenarioRulesCheck.tscn

var total := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	total += 1
	if not cond:
		fails += 1
		print("  FALLITO: ", what)


func _ready() -> void:
	# ── 2 · Bocage: la siepe cuesta +1 PM extra ────────────────────────────
	var s2 := GameState.new()
	s2.scenario_number = 2
	s2.map_cols = 2
	s2.map_rows = 1
	s2.hexes["0,0"] = GameState.HexData.new(Domain.TerrainType.OPEN, 0)
	s2.hexes["1,0"] = GameState.HexData.new(Domain.TerrainType.OPEN, 0)
	s2.side_features = [{ "a": Vector2i(0, 0), "b": Vector2i(1, 0), "feature": Domain.HexsideFeature.HEDGE }]
	s2.scenario_number = 1
	ok(HexGrid.step_cost(s2, 0, 0, 1, 0) == 2, "escenario normal: siepe +1")
	s2.scenario_number = 2
	ok(HexGrid.step_cost(s2, 0, 0, 1, 0) == 3, "escenario 2: siepe +2 (bocage)")

	# ── 5 · Gelo profondo: no se pueden jugar nuevas fortificaciones ───────
	ok(ScenarioEffects.fortifications_locked(5), "escenario 5: fortificaciones bloqueadas")
	var s5 := GameState.new()
	s5.scenario_number = 5
	var lines: Array[String] = []
	Actions._place_fort(s5, Domain.Faction.GERMAN, Domain.Fort.TRENCH, lines)
	ok(not lines.is_empty() and String(lines[0]).contains("Confusione"), "escenario 5: acción de fortificación anulada")

	# ── 7/8/13 · Salidas que eliminan en vez de dar PV ─────────────────────
	ok(ScenarioEffects.exit_eliminates(7, Domain.Faction.GERMAN) and ScenarioEffects.exit_eliminates(7, Domain.Faction.RUSSIAN), "escenario 7: ambas salidas eliminan")
	ok(ScenarioEffects.exit_eliminates(8, Domain.Faction.RUSSIAN) and not ScenarioEffects.exit_eliminates(8, Domain.Faction.GERMAN), "escenario 8: solo los rusos son eliminados")
	ok(ScenarioEffects.exit_eliminates(13, Domain.Faction.GERMAN) and not ScenarioEffects.exit_eliminates(13, Domain.Faction.RUSSIAN), "escenario 13: solo los alemanes son eliminados")

	# ── 8 · Acción nocturna: descarte 1 y penalización por distancia ───────
	var f8 := Flow.new_game(8, Flow.AX, 123)
	ok(f8.discard_limit(Flow.AX) == 1, "escenario 8: descarte del Eje = 1")
	ok(f8.discard_limit(Flow.AL) >= 2, "escenario 8: descarte aliado normal")
	var u8: Unit = f8.men(Flow.AX)[0]
	var h8 := Vector2i(u8.q + 3, u8.r)
	ok(Flow.night_penalty([u8], h8) == 3, "escenario 8: penalización nocturna = distancia (3)")

	# ── 10 · Commandos: +1 al cuerpo a cuerpo aliado ───────────────────────
	ok(ScenarioEffects.melee_bonus(10, Domain.Faction.RUSSIAN) == 1, "escenario 10: +1 melee aliado")
	ok(ScenarioEffects.melee_bonus(10, Domain.Faction.GERMAN) == 0, "escenario 10: sin bonus para el Eje")

	# ── 12 · Cuevas: cecchinos del Eje a 2 hexágonos ───────────────────────
	ok(ScenarioEffects.sniper_range(12, Domain.Faction.GERMAN) == 2, "escenario 12: cecchino del Eje a 2 hexágonos")
	ok(ScenarioEffects.sniper_range(12, Domain.Faction.RUSSIAN) == 1, "escenario 12: cecchino aliado a 1 hexágono")

	# ── 22 · Fuego de fijación y crepúsculo ────────────────────────────────
	ok(ScenarioEffects.initial_suppressed(22, Domain.Faction.RUSSIAN), "escenario 22: británicos empiezan suprimidos")
	var f22 := Flow.new_game(22, Flow.AX, 321)
	var any_suppressed := false
	for u in f22.s.units.values():
		if u.faction == Flow.AL and u.type == Domain.UnitType.SQUAD:
			if not u.suppressed:
				any_suppressed = false
				break
			any_suppressed = true
	ok(any_suppressed, "escenario 22: al menos una escuadra aliada sale suprimida")
	f22.s.time_marker = 4
	ok(HexGrid.los_hindrance(0, 0, 0, 2, f22.s) >= 4, "escenario 22: crepúsculo = marcador de tiempo")

	# ── 20 · Incursión: el Eje no puede salir con un arma aliada en juego ──
	var s20 := GameState.new()
	s20.scenario_number = 20
	var w20 := Unit.new("w", Domain.Faction.RUSSIAN, Domain.UnitType.WEAPON, Domain.UnitClass.MG, "MG")
	s20.units[w20.id] = w20
	ok(ScenarioEffects.exit_blocked(s20, Domain.Faction.GERMAN), "escenario 20: salida del Eje bloqueada por arma aliada")
	s20.units.clear()
	ok(not ScenarioEffects.exit_blocked(s20, Domain.Faction.GERMAN), "escenario 20: salida permitida sin armas aliadas")

	# ── 23 · Minas de fuerza 7 ─────────────────────────────────────────────
	ok(ScenarioEffects.mine_strength(23) == 7, "escenario 23: minas de fuerza 7")
	ok(ScenarioEffects.mine_strength(1) == 6, "escenario normal: minas de fuerza 6")

	# ── 5 · Mimetización invernal ─────────────────────────────────────────
	ok(ScenarioEffects.winter_camouflage(5), "escenario 5: camuflaje invernal activo")

	# ── 7 · Partisanos: todo terreno cuesta 1 ─────────────────────────────
	ok(ScenarioEffects.partisan_terrain(7, Domain.Faction.RUSSIAN), "escenario 7: partisanos aliados")
	var s7 := GameState.new()
	s7.scenario_number = 7
	s7.map_cols = 2
	s7.map_rows = 1
	s7.hexes["0,0"] = GameState.HexData.new(Domain.TerrainType.OPEN, 0)
	s7.hexes["1,0"] = GameState.HexData.new(Domain.TerrainType.WOODS, 0)
	ok(HexGrid.step_cost(s7, 0, 0, 1, 0, null, 1) == 1, "escenario 7: bosque cuesta 1 con partisanos")
	ok(HexGrid.step_cost(s7, 0, 0, 1, 0) > 1, "escenario normal: bosque cuesta más de 1")

	# ── 7 · Mortero capturado: se elimina al averiarse ────────────────────
	var w7 := Unit.new("m7", Domain.Faction.RUSSIAN, Domain.UnitType.WEAPON, Domain.UnitClass.MORTAR, "Light Mortar")
	ok(ScenarioEffects.captured_weapon_eliminates(7, w7), "escenario 7: mortero capturado se elimina")
	ok(not ScenarioEffects.captured_weapon_eliminates(8, w7), "otro escenario: mortero normal")

	# ── 12 · Brezza reduce la niebla ──────────────────────────────────────
	var f12 := Flow.new_game(12, Flow.AX, 7)
	var fog_before := f12.s.global_hindrance
	var breeze_lines: Array[String] = []
	Events._breeze(f12.s, breeze_lines)
	ok(f12.s.global_hindrance == fog_before - 1, "escenario 12: Brezza reduce la niebla")

	# ── 16 · Defensa fanática y camino hundido ────────────────────────────
	ok(ScenarioEffects.fanatic_defense(16), "escenario 16: defensa fanática activa")
	var s16 := GameState.new()
	s16.scenario_number = 16
	s16.map_cols = 3
	s16.map_rows = 1
	s16.hexes["0,0"] = GameState.HexData.new(Domain.TerrainType.GULLY, 0)
	s16.hexes["1,0"] = GameState.HexData.new(Domain.TerrainType.WOODS, 0)
	s16.hexes["2,0"] = GameState.HexData.new(Domain.TerrainType.GULLY, 0)
	ok(HexGrid.has_los(0, 0, 2, 0, s16), "escenario 16: LOS libre entre fosas")
	s16.scenario_number = 1
	ok(not HexGrid.has_los(0, 0, 2, 0, s16), "escenario normal: el bosque bloquea")

	# ── 20 · Sissu ────────────────────────────────────────────────────────
	ok(ScenarioEffects.sissu(20), "escenario 20: Sissu activo")

	print("SCENARIO_RULES_RESULT: %s (%d controlli, %d falliti)" % ["PASS" if fails == 0 else "FAIL", total, fails])
	get_tree().quit(0 if fails == 0 else 1)
