#Requires AutoHotkey v2.0

TM_Lang_IT() {
    return Map(
        ; --- EXISTING UI ---
        "Set Launch Path", "Imposta Percorso",
        "Profiles", "Profili",
        "Delete Game", "Elimina",
        "Emulators", "Emulatori",
        "Clear Path", "Pulisci",
        "Restore Path", "Ripristina",
        "Window Manager",
        "Gestione Finestre",
        "Focus", "Focus",
        "Music", "Musica",
        "Video", "Video",
        "Gallery", "Galleria",
        "Database", "Database",
        "Notes", "Note",
        "Browser", "Esplora",
        "Rec Audio", "Reg. Audio",
        "Rec Video", "Reg. Video",
        "Icon Manager", "Icone",
        "Idle", "Minimo",
        "Normal", "Normale",
        "High", "Alto",
        "Realtime", "Realtime",
        "Clone Wizard", "Clonazione",
        "Patch Manager", "Gestione Patch",
        "Purge Logs", "Pulisci Log",
        "Purge List", "Svuota Lista",
        "Wipe List", "Svuota Lista",
        "View Logs", "Vedi Log",
        "Show Games Config", "Config Giochi",
        "View System Config", "Config Sistema",
        "AT3 Convert", "Conv. AT3",
        "RPCS3 Audio Fix", "Fix Audio RPCS3",
        "Pad Test", "Test Pad",
        "Hash Calc / Validator", "Validatore Hash",
        "Wipe Full List", "Svuota Tutto",
        "Hide Advanced", "Nascondi Avanzate",
        "Show Advanced Utilities", "Mostra Utilità",
        "Patch Game", "Applica Patch",

        ; --- NEW GALLERY KEYS ---
        "Previous", "Prec", "Next", "Succ", "Slideshow", "Presentazione", "Browse", "Sfoglia", "Delete", "Elimina",
        "Image", "Immagine", "Path", "Percorso", "Size", "Dimensione",
        "GALLERY_HELP_1", "Premi Spazio per avviare la presentazione.",
        "GALLERY_HELP_2", "Doppio clic per schermo intero.",
        "GALLERY_HELP_3", "Premi M a schermo intero per cambiare monitor.",
        "GALLERY_HELP_4", "Premi DELETE per eliminare l'immagine.",

            "HELP_TEXT_GAMEPAD", "
            (
         SPIEGAZIONE ASSI (Emulazione Xbox 360)

         X e Y: Stick Sinistro
         • X: Orizzontale (0=Sinistra, 50=Centro, 100=Destra)
         • Y: Verticale (0=Su, 50=Centro, 100=Giù)

         R: Stick Destro (Verticale)
         • A riposo è 50, poi si muove verso 0 o 100.

         Z: Trigger L2 / R2
         • Entrambi i trigger condividono questo asse unico.
         • 50 = Nessuno premuto (o entrambi premuti in modo uguale)
         • 100 = Trigger Sinistro (L2) premuto al massimo
         • 0 = Trigger Destro (R2) premuto al massimo

         POV: D-Pad (Hat Point of View)
         • Mostra l'angolo in gradi x 100.
         • -1 = Nessuna direzione premuta
         • 0 = Su
         • 9000 = Destra
         • 18000 = Giù
         • 27000 = Sinistra
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. AGGIUNGERE GIOCHI:
   - Clicca 'Imposta Percorso' per l'eseguibile principale.
   - Per TeknoParrot seleziona un profilo in 'Profili'.

2. EMULATORI:
   - Clicca 'Emulatori' per impostare i percorsi.

3. AVVIARE GIOCHI:
   - Selezionando .ISO/EBOOT.BIN chiederà quale emulatore usare.
   - Oppure seleziona dalla lista e clicca ▶️.

4. QUANDO IL GIOCO È ATTIVO:
   - Usa 'Gestione Finestre' per manipolare la finestra.
   - Usa i tasti CPU per correggere lag/stuttering.
   - Burst scatta screenshot rapidi (max 99).

5. REGISTRAZIONE:
   - Registra solo audio o video con audio.

6. STRUMENTI:
   - Convertitore Atrac3: Converte audio in WAV.
   - Validatore File: Controlla hash MD5/SHA1.
   - Database Ricerca Giochi.

7. TASTI RAPIDI:
   - Escape: Esci dal gioco.
  - Escape+1: Hard reset.
  - Control+L: Apre il log live.
   - F8: Abilita il catalogo dei comandi vocali.
  - Ctrl+Alt+F9: In modalità cattura mostra il terminale ffmpeg.
  - Ctrl+Alt+F10: Mostra i log di ffmpeg.
   - CTRL+SHIFT+A: Apre Audio Manager.

8. AVVIO RAPIDO:
   - Tasto destro sull'icona della tray.
   - Doppio click sulla barra del titolo per modalità testo.

9. FINESTRE MAGNETICHE:
   - Tieni premuto Ctrl per staccare la finestra principale.

T. RISOLUZIONE PROBLEMI:
   - Usa 'Riavvia' per riavviare il gioco.
   - Controlla i Log per errori.
        )"
    )
}
