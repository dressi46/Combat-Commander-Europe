# Lobby de Combat Commander

## Jugar

Abre el juego y entra en **Multijugador → Sala de juego en línea**. Conecta con el servidor. Al crear la sala, elige escenario y bando. Comparte el código con tu rival o marca **Mostrar esta sala en la lista pública**. La partida empieza cuando entra la segunda persona. Cada jugador elige el idioma en la configuración de su juego.

El servidor ejecuta el motor de reglas de la versión individual y usa el despliegue automático del modo para dos jugadores. Cada movimiento se valida contra el bando, la decisión y las opciones actuales. Cada participante recibe la mano propia y el número de cartas del adversario. Las identidades de las cartas que quedan en los mazos se quedan en el servidor.

Una desconexión pausa la partida durante cinco minutos. Pulsa **Conectar** de nuevo desde la misma instancia del juego para recuperar tu asiento. Mantén abierta la pestaña o aplicación. Salir expresamente de la sala termina la partida para ambos. Las salas viven en memoria y caducan si se reinicia el servidor.

## Probar en Ubuntu

En el paquete distribuido, ejecuta `./iniciar-local.sh` y abre <http://localhost:8781>. También puedes abrir dos pestañas para probar ambos bandos. El servidor web y el de partidas escuchan solo en la interfaz local. Cierra el script con Ctrl+C.

## Desplegar en lobby.dressi.es

El paquete para Linux x86-64 incluye las carpetas `linux` y `web` con el motor y la exportación del juego. Copia todo su contenido a una carpeta del servidor que tenga Docker y Docker Compose. Apunta el registro DNS del subdominio a esa máquina. Con los puertos 80 y 443 disponibles, ejecuta desde esa carpeta:

```sh
docker compose up -d
docker compose logs -f
```

Caddy sirve el juego en **https://lobby.dressi.es** y reenvía las conexiones WebSocket al servicio de partidas. Solicita y renueva el certificado HTTPS. El contenedor de partidas escucha en el puerto 8790 de la red interna. Si ya tienes un proxy que ocupa los puertos públicos, integra estas dos rutas en ese proxy. Para parar los servicios usa `docker compose down`.

## Ejecutar desde el repositorio

Con Godot 4.6.3, desde la raíz del repositorio:

```sh
godot --headless --path godot --import
LOBBY_BIND=127.0.0.1 PORT=8790 godot --headless --path godot res://online/Server.tscn
```

La prueba de integración abre conexiones WebSocket reales a un lobby de pruebas. En otra terminal, ejecuta:

```sh
godot --headless --path godot res://tests/OnlineCheck.tscn -- ws://127.0.0.1:8790
```

Los textos del lobby comparten los catálogos de `godot/assets/i18n` con el resto del juego. El cliente indica su idioma al conectar. El servidor presenta cada decisión y mensaje del motor en el idioma de su destinatario.

## Taller y perfiles

En **Taller de misiones y cartas** puedes guardar misiones, adjuntarles fotos o PDF y jugarlas contra la IA en el navegador. El generador usa las tiradas de los pasos RS.1–RS.3. Consulta las tablas de cada nación para elegir las fuerzas, líderes y apoyos y registrar sus costes. Al seleccionar una formación compatible, el taller carga las fuerzas, sortea los líderes y rellena órdenes, iniciativa y rendición de la tabla. El taller calcula postura, profundidad de despliegue, mano inicial y muerte súbita. En **Cartas**, elige idioma, mazo y número. Para recortar una hoja, indica la página, el número de filas y columnas y la casilla contando desde la esquina superior izquierda. Los documentos y las ilustraciones se guardan en ese navegador y dirección web.

La primera conexión con un nombre reserva ese nombre y devuelve una ID permanente. El navegador o instalación guarda la credencial del jugador. Borrar sus datos o cambiar de dispositivo impide recuperar el nombre desde ese dispositivo sin una copia de la credencial. En Docker los perfiles se conservan en el volumen `players`.

Después de exportar el proyecto a HTML, ejecuta `python3 online/prepare-workshop.py RUTA_DE_LA_EXPORTACION` desde la raíz del repositorio para incluir el taller, el lector PDF y las tablas. Para traducir el taller, añade el catálogo correspondiente en `online/workshop/` y registra el idioma en el juego.
