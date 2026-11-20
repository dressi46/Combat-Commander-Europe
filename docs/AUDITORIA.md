# Auditoría de reglas — Combat Commander: Europe

**Fecha:** 20 de noviembre de 2026
**Commit auditado:** `3f704f1`
**Alcance:** motor de reglas, eventos, acciones, escenarios 1–24, guardado y audio.
**Método:** ejecución de la suite automática + self-play de los 24 escenarios + revisión del código y de la documentación de estado del propio proyecto.

## 1. Resultado de las pruebas automáticas

| Prueba | Resultado | Qué cubre |
|---|---|---|
| `PlaybackCheck` | PASS | reproducción de crónica, pausa, informes, previsualización de movimiento |
| `StatusCheck` | PASS | contadores de estado, objetivos privados, pista de tiempo |
| `ManualCheck` | PASS | modo manual de la IA, límites de paso, layout móvil |
| `SaveCheck` | PASS | guardar, recargar, comparar estado y continuar |
| `ReplayCheck` | PASS | 6 partidas completas reproducidas exactamente por semilla + decisiones |
| `RulesCheck` | PASS | 26 comprobaciones de LOS, terreno, altura y tablas de apoyo |
| `AudioCheck` | PASS | buses de música/efectos, volúmenes y mapeo de eventos |
| `ProfileCheck` | PASS | perfiles locales |
| `SelfPlay` (24 escenarios × 2 partidas) | **PASS — 48/48, 0 fallos** | estabilidad: ninguna partida se bloquea, ninguna elección es ilegal |

**Conclusión de estabilidad:** el motor es estable y no se bloquea en 48 partidas completas.

## 2. Veredicto de cumplimiento

**No se puede certificar el 100% del reglamento.** El propio proyecto documenta lagunas sustanciales, y el código contiene simplificaciones explícitas. La estabilidad de las pruebas no equivale a conformidad reglamentaria: `SelfPlay` comprueba que las partidas terminan y que las opciones son legales, no que cada regla se aplique como en el reglamento.

## 3. Cobertura por área

| Área | Estado | Evidencia |
|---|---|---|
| Secuencia de turno, órdenes, activación, fuego, cuerpo a cuerpo, recuperación, retirada, artillería, descarte, tiempo, objetivos, victoria | Implementado y probado en partidas | `Flow.gd`, `Rules.gd`, `SelfPlay` |
| LOS, altura, cresta, carreteras, cobertura, obstáculos | Implementado; 26 comprobaciones | `RulesCheck.gd` |
| 35 eventos del Mazo del Fato | Todos tienen rama de código; varios simplificados | `Events.gd`, `Flow._event_native` |
| 20 acciones | Todas tienen tratamiento; varias simplificadas | `Actions.gd`, `Flow.gd` |
| 24 escenarios: zonas, fortificaciones iniciales, chits, cartas iniciales, refuerzos, niebla global | Automatizado | `ScenarioEffects.gd`, `STATO_SCENARI.md` |
| **Reglas especiales de escenario** | **Mayoría solo mostradas, no aplicadas** | `STATO_SCENARI.md`: **90 elementos 👁️** frente a 58 ✅ |
| Mazos de 72 cartas por nación | Datos reales cargados | `assets/cards/*_deck.json` |
| Guardado, replay determinista, online persistente | Implementado y probado | `SaveGame.gd`, `ReplayCheck`, `RoomPersistCheck` |
| Audio por fase y música | Implementado y probado | `Audio.gd`, `AudioCheck` |

## 4. Lagunas concretas

### 4.0 Progreso de la Fase 1 (primer lote)

Ya aplicadas y cubiertas por `tests/ScenarioRulesCheck.gd` (32 comprobaciones):

- Escenario 2: coste de siepe +2 PM (Bocage).
- Escenario 5: fortificaciones bloqueadas tras el inicio y camuflaje invernal.
- Escenarios 7, 8 y 13: salidas que eliminan en vez de dar PV.
- Escenario 7: partisanos (todo terreno cuesta 1) y mortero capturado.
- Escenario 8: descarte del Eje = 1 y penalización nocturna por distancia.
- Escenario 10: +1 al cuerpo a cuerpo aliado.
- Escenario 12: cecchinos del Eje a 2 hexágonos y niebla reducida por Brezza.
- Escenario 16: defensa fanática y camino hundido.
- Escenario 20: salida del Eje bloqueada, Sissu y Motti.
- Escenario 22: escuadras británicas suprimidas y crepúsculo = marcador de Tiempo.
- Escenario 23: minas de fuerza 7.

Quedan ~75 reglas 👁️ por automatizar (nieve 1½, despliegues ocultos, observador avanzado, artillería negada, humo de la Radio italiana, etc.).

**Fase 3 iniciada:** `docs/CONFORMANCE.md` y `tests/ConformanceCheck.tscn` con la matriz (11 implementadas, 5 parciales, 4 ausentes) y modo `--strict` como puerta de calidad.

**Estabilidad tras el lote:** suite completa en verde y `SelfPlay` **48/48 partidas, 0 fallos**.

### 4.1 Reglas especiales de escenario (crítico)

`docs/STATO_SCENARI.md` marca **90 reglas especiales como 👁️ “mostradas pero no automatizadas”** y solo 58 elementos de setup como ✅. Ejemplos:

- Escenario 2: Bocage (setos con +1 movimiento y cobertura 2).
- Escenario 5: Nieve (coste de terreno abierto 1½) y Mimetización invernal.
- Escenario 8: Acción nocturna (límite de descarte 1, modificador de fuego).
- Escenario 10: Commandos (+1 a cuerpo a cuerpo) y genieros con lanzallamas/carga.
- Escenario 12: Cuevas (cecchinos a 2 hexágonos), niebla variable.
- Escenario 16: Puestos ocultos, defensa fanática, camino hundido.
- Escenario 20: Tácticas Motti, Sissu, Incursión.
- Escenario 22: Fuego de fijación (unidades británicas empiezan suprimidas), crepúsculo variable.
- Escenario 23: Campo minado a 7 hexágonos, grupo de cecchinos, fuego de hostigamiento.

`ScenarioRules.gd` lo confirma: las reglas son **datos de solo lectura**; las mecánicas “se aplican en otro lugar a medida que se implementan”. `ScenarioEffects.gd` solo aplica cuatro tipos de efecto: chits excluidos, cartas iniciales, obstáculo global y refuerzos.

### 4.2 Núcleo del reglamento simplificado

`docs/STATO.md` (sección «Semplificazioni e cose ancora da fare») reconoce:

1. **Schieramento**: las reglas particulares de despliegue de algunas fichas no se imponen.
2. **Tablas de Apoyo**: comandantes con valores de grado en vez de los impresos; excepciones finlandesas/belgas/polacas omitidas; lanzallamas y carga explosiva sin sus reglas especiales.
3. **Colinas**: la cresta se trata por hexágono entero, no por línea interna.
4. **Armas averiadas**: no se reparan/eliminan con el Hexágono Aleatorio (11.4); falta el traspaso de arma (O21.1.1).
5. **Terreno**: objetivos en edificios de varios hexágonos; humo de valor variable (hoy siempre 3).
6. **Búnker/Pillbox**: `Rules.gd` indica que no están modelados en cuerpo a cuerpo.
7. **Acciones**: `Actions._place_fort` es una versión simplificada de la colocación “oculta” (A35); algunas acciones se resuelven con flujos especiales en `Flow.gd`.
8. **Eventos**: `Events._field_promotion` está marcado como simplificado; varios eventos solo registran un texto cuando no hay efecto aplicable.

### 4.3 Cobertura de pruebas insuficiente para “100%”

- `RulesCheck` tiene **26 comprobaciones**, centradas en LOS/terreno/tablas de apoyo. No cubre la secuencia completa, el combate, los eventos, las acciones ni las 90 reglas de escenario.
- `SelfPlay` verifica estabilidad y legalidad de opciones, **no conformidad reglamentaria**.
- No existe una matriz de conformidad que falle cuando una regla del reglamento no está implementada.

## 5. Plan para llegar al 100%

### Fase 1 — Motor de reglas especiales de escenario (prioridad máxima)

- Convertir las 90 reglas 👁️ en efectos data-driven de `ScenarioEffects` (modificadores de terreno, límites de descarte, modificadores de fuego/cuerpo a cuerpo, despliegues especiales, unidades ocultas, refuerzos condicionales, etc.).
- Añadir una prueba por escenario que verifique cada regla especial.
- Actualizar `STATO_SCENARI.md` automáticamente desde la matriz de cobertura.

### Fase 2 — Lagunas del núcleo

- Reparación/eliminación de armas averiadas (11.4) y traspaso de arma (O21.1.1).
- Colocación oculta de fortificaciones (A35) y reglas de lanzallamas/carga explosiva.
- Excepciones de las Tablas de Apoyo y valores impresos de comandantes.
- Humo variable, edificios multi-hexágono y Búnker/Pillbox en cuerpo a cuerpo.
- Cresta de colina por línea interna.

### Fase 3 — Conformidad estricta y regresión

- Una prueba por capítulo del reglamento (secuencia, órdenes, fuego, cuerpo a cuerpo, artillería, eventos, acciones, terreno, victoria).
- Matriz de cobertura que marque `IMPLEMENTADO`, `PARCIAL`, `FALTA` y falle si queda algún `FALTA` en una regla obligatoria.
- Repetición de `SelfPlay` con aserciones de reglas, no solo de estabilidad.

## 6. Conclusión

- **Estabilidad:** excelente (48/48 partidas, suite completa en verde).
- **Cumplimiento del reglamento:** **no es del 100%**. El núcleo está muy desarrollado, pero las reglas especiales de los 24 escenarios y varias reglas de detalle están pendientes o simplificadas.
- **Riesgo:** dar por válida una partida puede llevar a resultados distintos de los del reglamento oficial, sobre todo en escenarios con SSR que hoy solo se muestran.

Para certificar el 100% hay que ejecutar el plan de las tres fases y mantener la matriz de conformidad como puerta de calidad.
