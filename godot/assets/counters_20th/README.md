# Fichas 20th Anniversary — estructura de troceado

Objetivo: pasar de las 7 losas (frente/reverso) a fichas individuales con un
manifiesto que una **nombre → frente/reverso → estadísticas → Fix/Elim**.

## Estructura

```
assets/counters_20th/
  german/
    leader/
    squad/
    team/
    weapon/
    fortification/
    marker/
  russian/ ...
  american/ ...
  british/ ...
  french/ ...
  italian/ ...
  romanian/ ...
  canadian/ ...
  brazilian/ ...
  polish/ ...
  yugoslav/ ...
  anzac/ ...
  manifest.json
```

Convención de nombre:

```
<nation>/<type>/<slug>_front.png
<nation>/<type>/<slug>_back.png
```

`slug` en minúsculas, sin espacios ni acentos (`light_mg`, `sgt_kovalev`,
`rifle_1`). El reverso solo existe para unidades con dos caras (eficiente/rota)
y para armas (normal/averiada).

## Manifiesto

Cada entrada de `manifest.json`:

```json
{
  "id": "german/weapon/light_mg",
  "nation": "german",
  "type": "weapon",
  "name": "Light MG",
  "front": "german/weapon/light_mg_front.png",
  "back": "german/weapon/light_mg_back.png",
  "source_sheet": "sheet_1",
  "stats": { "fp": 3, "range": 6, "move": 1, "morale": null, "command": null },
  "fix": [1, 2],
  "elim": [7, 10]
}
```

Los campos `fix`/`elim` de las armas ya están volcados en
`assets/units/weapons.json` a partir del reverso de la Hoja 1 y los usa la
regla 11.4. Las armas específicas (50mm/60mm/81mm, Brandt, Brixia, IG 18/33,
25-Pounder, Mountain Gun) y las Radios (A.R./A.D.) quedan por completar.

## Estado

- [x] Datos Fix/Elim de las armas comunes.
- [x] Regla 11.4 aplicada en `Flow.random_hex`.
- [x] Las 14 caras originales copiadas a `assets/counters_20th/sheets/`.
- [x] Herramienta de troceado `tools/cut_counters.py`.
- [x] Marcador de minas real (`assets/markers/Mines.png`).
- [ ] Troceado físico de las caras que faltan (reversos de armas y naciones menores).
- [ ] Manifiesto completo y sustitución de la arte stand-in.

## Naciones menores que siguen en stand-in

| Escenario | Nación real | Stand-in actual |
|---|---|---|
| 12 | Brasileña | US |
| 13 | ANZAC | GB |
| 14 | Polaca | FR |
| 15 | Rumana | IT |
| 17 | Canadiense | GB |
| 18 | Yugoslava | FR |
| 19 | Griega | catálogo: `french` |
| 20 | Finlandesa | catálogo: `italian` |

Las cartas ilustradas solo existen para alemanes, rusos y americanos
(`assets/cards_it/`); británicos, italianos y franceses se dibujan por código.
Las losas no incluyen cartas, así que eso queda fuera del troceado de fichas.

