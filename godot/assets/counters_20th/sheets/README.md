# Losas originales (20th Anniversary)

Copiadas desde `~/Descargas/CCEM/` para que el arte quede dentro del proyecto.
Esta carpeta lleva `.gdignore`: **Godot no las importa ni las mete en el
export**; son fuente para trocear.

| Archivo | Cara | Contenido principal |
|---|---|---|
| `sheet_01_front.webp` | Hoja 1 frente | controles, OB, búnkeres, alambre, minas, objetivos, armas |
| `sheet_01_back.webp` | Hoja 1 reverso | humo, objetivos, **reversos de armas con Fix/Elim** |
| `sheet_02_front.webp` | Hoja 2 frente | armas específicas por nación |
| `sheet_02_back.webp` | Hoja 2 reverso | **reversos de armas específicas con Fix/Elim** |
| `sheet_03_front.webp` / `_back` | Hoja 3 | unidades alemanas/soviéticas y líderes |
| `sheet_04_front.webp` / `_back` | Hoja 4 | unidades de varias naciones (Guards, Assault, SMG...) |
| `sheet_05_front.webp` / `_back` | Hoja 5 | italianos, finlandeses, etc. |
| `sheet_06_front.webp` / `_back` | Hoja 6 | británicos, canadienses, franceses |
| `sheet_07_front.webp` / `_back` | Hoja 7 | Polonia, Yugoslavia, Grecia, Finlandia, Nueva Zelanda, Rumanía, Holanda |

## Relación con lo ya troceado

`assets/counters/` ya contiene **429 fichas individuales 192×192** de las seis
naciones mayores, con el mismo arte y con `_Half` para el reverso de las
unidades. No hace falta volver a trocear esas seis.

Lo que falta y justifica estas losas:

1. **Reversos de armas** (las carpetas `_Half` no incluyen armas).
2. **Naciones menores** que hoy usan arte *stand-in*.
3. Armas específicas y radios para completar Fix/Elim.

## Herramienta

`tools/cut_counters.py` trocea por rejilla uniforme o por cajas explícitas
(recomendado para estas losas, que mezclan tamaños):

```sh
python3 tools/cut_counters.py assets/counters_20th/sheets/sheet_07_front.webp \
    /tmp/fichas --boxes boxes.json
```
