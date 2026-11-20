# Matriz de conformidad — Fase 3

**Estado actual:** 11 `IMPLEMENTED`, 5 `PARTIAL`, 4 `MISSING`.

La fuente de verdad es `godot/assets/docs/conformance.json`; el test
`godot/tests/ConformanceCheck.tscn` la lee y la imprime. Con `--strict` falla si
queda alguna fila `PARTIAL` o `MISSING`, de modo que sirve de puerta de calidad
cuando la Fase 1 y la Fase 2 estén cerradas.

## Cómo ejecutarla

```sh
# Informe (no falla)
godot --headless --path godot res://tests/ConformanceCheck.tscn

# Puerta estricta (falla mientras haya lagunas)
godot --headless --path godot res://tests/ConformanceCheck.tscn -- --strict
```

## Matriz

| Área | Estado | Evidencia |
|---|---|---|
| Secuencia de turno y órdenes | IMPLEMENTED | `Flow._turn`, `_discard_turn` |
| Activación (unidad suelta y comandante) | IMPLEMENTED | `Flow._choose_activation` |
| Movimiento, PM, carreteras y alambre | IMPLEMENTED | `HexGrid.step_cost`, `Flow._move_stack` |
| Fuego y acciones de fuego | IMPLEMENTED | `Flow._fire_attack`, `_fire_mods` |
| Cuerpo a cuerpo y avance | IMPLEMENTED | `Rules.resolve_melee` |
| Recuperación y retirada | IMPLEMENTED | órdenes de `Flow` |
| Artillería: petición, negada y humo | PARTIAL | núcleo hecho; falta el humo de la Radio (SSR 24) |
| Innescos del Fato (tiempo, cecchino, evento, inceppamento) | IMPLEMENTED | `Flow.roll`, `_apply_trigger` |
| Objetivos, PV, salida, rendición y muerte súbita | IMPLEMENTED | `Flow`, `GameState` |
| LOS, terreno, colinas y humo | PARTIAL | cresta por hexágono; humo variable pendiente |
| Armas portadas y averiadas | PARTIAL | traspaso O21.1.1 implementado; faltan rangos Fix/Elim 11.4 |
| Tablas de Apoyo | PARTIAL | faltan excepciones finlandesas/belgas/polacas y lanzallamas/carga |
| Reglas especiales de escenario | PARTIAL | 22 automatizadas; ~75 solo mostradas |
| Despliegues ocultos/diferidos | MISSING | escenarios 2, 3, 15, 18, 21 |
| Nieve con coste 1½ | MISSING | requiere PM fraccionarios |
| Motti (despliegue del 20) | IMPLEMENTED | `ScenarioLoader._motti_filter` |
| Cecchinos y artillería negada (23) | MISSING | pendiente |
| Humo de la Radio italiana (24) | MISSING | pendiente |
| Salas online y reconexión | IMPLEMENTED | `Server.gd`, `Online.gd` |
| Guardado y replay determinista | IMPLEMENTED | `ReplayCheck`, `SaveCheck` |

## Interpretación

- `IMPLEMENTED`: la regla se aplica en el motor y tiene prueba automatizada o
  evidencia directa en el código.
- `PARTIAL`: el núcleo funciona, pero falta una parte del reglamento o una
  excepción.
- `MISSING`: no se aplica todavía.

La Fase 3 no se considera cerrada mientras quede algún `MISSING` y mientras los
`PARTIAL` no se hayan revisado uno a uno.
