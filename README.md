# Combat Commander: Europe

**Español** · [English](README.en.md)

Adaptación digital del juego de mesa táctico de GMT Games, hecha con Godot 4.6.3. Proyecto de aficionados para uso personal.

## Jugar en el navegador

En Ubuntu, abre una terminal en la carpeta del **paquete para Linux** que contiene el lanzador y ejecuta:

```sh
./iniciar-local.sh
```

Deja la terminal abierta y entra en [el juego local](http://localhost:8781/) desde Brave. En el mismo equipo también puedes abrir [el taller de misiones y cartas](http://localhost:8781/workshop/?lang=es). Para jugar desde otro dispositivo, abre la dirección HTTPS donde se haya alojado el juego. [Guía del servidor y del lobby](online/README.md).

## Menú principal

- **Un solo jugador** permite jugar contra la IA o ver una demostración.
- **Multijugador** ofrece juego en el mismo dispositivo y salas en línea públicas o privadas. Cada participante puede usar su propio idioma.
- **Taller de misiones y cartas** permite editar y generar escenarios, adjuntar documentos y jugar misiones personalizadas contra la IA. Para importar una carta, elige su idioma, mazo y número. En un PDF también puedes elegir página y casilla. El navegador guarda los archivos en el dispositivo.
- **Configuración** guarda el idioma, el ritmo de las acciones y el volumen de los efectos. El ritmo lento da más tiempo para leer la crónica.

En una partida contra la IA, la flecha del tablero marca el paso de origen a destino. Al mover, cada casilla indica **coste → PM restantes**. Pulsa **Crónica** para leer la secuencia completa. El resumen de cada evento muestra la regla y su resultado, y espera a que pulses **Continuar partida**. Puedes desactivar esa pausa en Configuración.

En el tablero, **Controles** reúne la vista 3D, el centrado, el ritmo, la pausa, la ayuda y el registro. Pulsa un indicador de la cabecera para consultar el tiempo y la muerte súbita, el origen de los PV, quién tiene la iniciativa o las fichas eliminadas de un bando. **Objetivos** muestra las fichas públicas, las secretas del jugador que consulta y el control de los objetivos del mapa.

## Abrir o exportar el proyecto

Abre [godot/project.godot](godot/project.godot) con Godot 4.6.3 y pulsa **F5** para jugar. Para crear la versión web desde el repositorio, instala las plantillas de exportación de esa versión y ejecuta desde la raíz:

```sh
mkdir -p godot/build
godot --headless --path godot --import
godot --headless --path godot --export-release Web build/index.html
python3 online/prepare-workshop.py godot/build
python3 -m http.server 8781 --bind 127.0.0.1 --directory godot/build
```

Abre [localhost:8781](http://localhost:8781/). Esta última orden sirve el juego y el taller. Para las partidas en línea, arranca también el servidor Godot con la variable `PORT=8791` al probar en ese puerto web. [Instrucciones del lobby](online/README.md).

## Traducir el juego

Español, inglés e italiano están disponibles en **Configuración → Idioma**. Para empezar otro idioma, pulsa **Añadir idioma**, escribe su nombre y elige una lengua de partida. Al crearlo se abre **Traducción rápida**. También puedes buscar las frases del taller. Cada navegador o instalación conserva sus idiomas y correcciones. En partidas en línea, los mensajes que envía el servidor usan la lengua de partida.

En **Configuración → Traducción rápida** puedes buscar una frase por su texto en inglés o en el idioma activo, corregirla y restaurar su versión original. Los cambios se guardan en ese dispositivo para el idioma elegido.

Copia `godot/assets/i18n/en.json`, usa el código del nuevo idioma como nombre de archivo y regístralo en `languages.json` del mismo directorio. Traduce los valores y conserva las claves, los marcadores como `%s` y `%d` y las etiquetas de formato. El inglés sirve de respaldo cuando falta un texto. Los textos del taller están en `online/workshop/`.

Para incluir ilustraciones en el proyecto, usa rutas como `godot/assets/cards_es/german/01.webp`. Godot importa la imagen al abrir el proyecto. Si falta la ilustración, el juego dibuja la carta a partir de los datos del mazo.

## Organización

| Carpeta | Contenido |
|---|---|
| `godot/engine/` | Motor de decisiones (`Flow.gd`), IA (`Bot.gd`), coordinación de la partida (`Game.gd`) y reglas de combate, terreno, eventos y objetivos. La IA elige entre las mismas jugadas legales que el jugador. |
| `godot/assets/` | 24 mapas, seis mazos de 72 cartas, escenarios, anversos y reversos de unidades, traducciones y fuentes Black Ops One y Barlow Condensed (OFL). |
| `godot/scenes/` | Menús, mapas 2D y 3D, mano, ayuda y crónica. El tema visual está en `godot/engine/Tema.gd`. |
| `online/` | Taller web, lanzador local y archivos para alojar el lobby. |
| `docs/` | [Estado del proyecto](docs/STATO.md), auditorías y [archivo histórico](docs/archivio/), con código de la v0.48 y pruebas gráficas. |

## Verificación y publicación

Desde la raíz del repositorio:

```sh
godot --headless --path godot --import
godot --headless --path godot res://tests/RulesCheck.tscn
godot --headless --path godot res://tests/SelfPlay.tscn -- all 1
godot --path godot --resolution 1024x768 res://tests/UiTour.tscn -- /tmp/cc-ui 2 160
python3 tools/controlla_glifi.py
```

Estas comprobaciones cubren las reglas, partidas entre dos IA en todos los escenarios, capturas de las decisiones y cobertura de caracteres. Para publicar en GitHub Pages, ejecuta manualmente `deploy.yml` o incluye `[pubblica]` en el mensaje de un commit a `main`. [Versión web del proyecto original](https://tannoiser2.github.io/Combat-Commander-Europe/).

*Combat Commander: Europe* es © GMT Games. Los materiales originales pertenecen a sus respectivos titulares.
