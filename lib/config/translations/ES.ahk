#Requires AutoHotkey v2.0

TM_Lang_ES() {
    return Map(
        ; --- EXISTING UI ---
        "Set Launch Path", "Ruta de Juego",
        "Profiles", "Perfiles",
        "Delete Game", "Borrar",
        "Emulators", "Emuladores",
        "Clear Path", "Limpiar",
        "Restore Path", "Restaurar",
        "Window Manager", "Ventanas",
        "Focus", "Enfocar", "Music",
        "Música", "Video", "Video",
        "Gallery", "Galería",
        "Database", "Base de Datos",
        "Notes", "Notas",
        "Browser", "Explorador",
        "Rec Audio", "Grabar Audio",
        "Rec Video", "Grabar Video",
        "Icon Manager", "Iconos",
        "Idle", "Inactivo",
        "Normal", "Normal",
        "High", "Alto",
        "Realtime", "Tiempo Real",
        "Clone Wizard", "Clonar",
        "Patch Manager", "Parches",
        "Purge Logs", "Borrar Logs",
        "Purge List", "Borrar Lista",
        "Wipe List", "Borrar Lista",
        "View Logs", "Ver Logs",
        "Show Games Config", "Config Juegos",
        "View System Config", "Config Sistema",
        "AT3 Convert", "Conv. AT3",
        "RPCS3 Audio Fix", "Reparar Audio",
        "Pad Test", "Test Mando",
        "Hash Calc / Validator", "Validar Hash",
        "Wipe Full List", "Borrar Todo",
        "Hide Advanced", "Ocultar Avanzado",
        "Show Advanced Utilities", "Mostrar Utilidades",
        "Patch Game", "Parchear",

        ; --- NEW GALLERY KEYS ---
        "Previous", "Anterior", "Next", "Siguiente", "Slideshow", "Presentación", "Browse", "Explorar", "Delete", "Borrar",
        "Image", "Imagen", "Path", "Ruta", "Size", "Tamaño",
        "GALLERY_HELP_1", "Pulsa Espacio para iniciar la presentación.",
        "GALLERY_HELP_2", "Doble clic para pantalla completa.",
        "GALLERY_HELP_3", "Pulsa M en pantalla completa para cambiar monitor.",
        "GALLERY_HELP_4", "Pulsa DELETE para borrar la imagen.",

            "HELP_TEXT_GAMEPAD", "
            (
         EXPLICACIÓN DE EJES (Emulación Xbox 360)

         X y Y: Stick Izquierdo
         • X: Horizontal (0=Izquierda, 50=Centro, 100=Derecha)
         • Y: Vertical (0=Arriba, 50=Centro, 100=Abajo)

         R: Stick Derecho (Vertical)
         • En reposo está en 50; se mueve hacia 0 o 100.

         Z: Gatillos L2 / R2
         • Ambos gatillos comparten este único eje.
         • 50 = Ninguno pulsado (o ambos pulsados por igual)
         • 100 = Gatillo Izquierdo (L2) totalmente pulsado
         • 0 = Gatillo Derecho (R2) totalmente pulsado

         POV: D-Pad (Hat de Punto de Vista)
         • Muestra el ángulo en grados x 100.
         • -1 = Nada pulsado
         • 0 = Arriba
         • 9000 = Derecha
         • 18000 = Abajo
         • 27000 = Izquierda
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. AÑADIR JUEGOS:
   - Clic en 'Ruta de Juego' para el ejecutable principal.
   - Para TeknoParrot selecciona un perfil en 'Perfiles'.

2. EMULADORES:
   - Clic en 'Emuladores' para configurar rutas.

3. EJECUTAR JUEGOS:
   - Al seleccionar .ISO/EBOOT.BIN preguntará qué emulador usar.
   - O selecciona de la lista y pulsa ▶️.

4. JUEGO ACTIVO:
   - Usa 'Ventanas' para manipular la ventana del juego.
   - Usa botones CPU para corregir lag.
   - Ráfaga toma capturas rápidas (max 99).

5. GRABACIÓN:
   - Graba solo audio o video con sonido.

6. HERRAMIENTAS:
   - Convertidor Atrac3: Convierte audio a WAV.
   - Validador: Comprueba hash MD5/SHA1.
   - Base de datos de juegos.

7. TECLAS RÁPIDAS:
   - Escape: Salir del juego.
  - Escape+1: Hard reset.
  - Control+L: Ver registro en vivo.
   - F8: Activa el catálogo de comandos de voz.
  - Ctrl+Alt+F9: En modo captura muestra la terminal de ffmpeg.
  - Ctrl+Alt+F10: Muestra los logs de ffmpeg.
   - CTRL+SHIFT+A: Abre el Gestor de Audio.

8. INICIO RÁPIDO:
   - Clic derecho en icono de bandeja.
   - Doble clic en barra de título para modo texto.

9. VENTANAS MAGNÉTICAS:
   - Mantén Control para separar la ventana principal.

T. SOLUCIÓN DE PROBLEMAS:
   - Para reiniciar usa 'Reiniciar'.
   - Usa 'Ver Logs' para errores.
        )"
    )
}
