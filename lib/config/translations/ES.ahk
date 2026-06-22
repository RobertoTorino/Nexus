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
      "Sound Manager", "Gestor de Sonido",
      "Emulator Audio Config", "Configuración de Audio del Emulador",
      "Hardware Output Mapping", "Mapeo de Salida de Hardware",
      "Route Game Audio (Strip 3)", "Enrutar audio del juego (Pista 3)",
      "Capture Backend", "Backend de captura",
      "Backend:", "Backend:",
      "Save", "Guardar",
      "Refresh Device List ↻", "Actualizar lista de dispositivos ↻",
      "Clear", "Borrar",
      "Mute", "Silencio",
      "Hard Reset (Relaunch VoiceMeeter App)", "Reinicio duro (Reabrir VoiceMeeter)",
      "Out A1", "Salida A1",
      "Out A2", "Salida A2",
      "Out A3", "Salida A3",
      "Install Loopback Helper", "Instalar asistente de loopback",
      "Test Loopback 3s", "Probar loopback 3 s",
      "Help", "Ayuda",
      "Check for Updates", "Buscar actualizaciones",
      "Choose an option", "Elige una opción",
      "Status:", "Estado:",
      "Ready", "Listo",
      "Saved backend:", "Backend guardado:",
      "Capture backend saved:", "Backend de captura guardado:",
      "Loopback helper installed", "Asistente de loopback instalado",
      "Loopback install failed", "Error al instalar el asistente de loopback",
      "Install Error", "Error de instalación",
      "Could not install loopback helper.", "No se pudo instalar el asistente de loopback.",
      "FFmpeg missing", "Falta FFmpeg",
      "Capture Test", "Prueba de captura",
      "FFmpeg missing:", "Falta FFmpeg:",
      "Loopback helper missing", "Falta asistente de loopback",
      "Loopback helper is missing and could not be installed.", "Falta el asistente de loopback y no pudo instalarse.",
      "Running 3s loopback test...", "Ejecutando prueba de loopback de 3 s...",
      "Loopback test saved:", "Prueba de loopback guardada:",
      "Loopback test capture saved", "Captura de prueba de loopback guardada",
      "Loopback test failed", "Prueba de loopback fallida",
      "Loopback test failed. No valid output file was generated.", "La prueba de loopback falló. No se generó un archivo de salida válido.",
      "Update check finished", "Comprobación de actualizaciones finalizada",
      "Update Check", "Comprobar actualizaciones",
      "Update Decision", "Decisión de actualización",
      "Apply All Updates", "Aplicar todas las actualizaciones",
      "Install Helper", "Instalar asistente",
      "Download FFmpeg", "Descargar FFmpeg",
      "Download Nexus", "Descargar Nexus",
      "Skip", "Omitir",
      "Helper local", "Helper local",
      "FFmpeg local", "FFmpeg local",
      "Nexus local", "Nexus local",
      "Latest", "Última",
      "Stable", "Estable",
      "Nightly", "Nocturna",
      "Selected release", "Versión seleccionada",
      "None", "Ninguna",
      "AT3 Convert", "Conv. AT3",
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

        "HELP_TEXT_SOUND_MANAGER", "
        (
1. MODO DE SONIDO:
   - Auto usa primero el asistente de loopback.
   - Loopback captura el dispositivo de reproducción de Windows actual.
   - DShow usa el dispositivo de entrada directo configurado.
   - Voicemeeter mantiene el flujo de enrutado clásico.

2. CONFIGURACIÓN DE SONIDO DE WINDOWS:
   - Configura como salida predeterminada los altavoces o auriculares que quieres escuchar.
   - Deja el micrófono como dispositivo de entrada para los comandos de voz.
   - Si el audio sale por un dispositivo no predeterminado, cambia a DShow o Voicemeeter.

3. ASISTENTE DE LOOPBACK:
   - Pulsa Instalar asistente de loopback si el helper integrado falta.
   - Pulsa Probar loopback 3 s para verificar que el audio del sistema se captura.

4. ACTUALIZACIONES:
   - Usa el botón de comprobación para comparar el helper, FFmpeg y Nexus.

5. RUTEO LEGADO:
   - Voicemeeter sigue disponible para usuarios que necesiten ruteo manual por buses.
        )",

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
