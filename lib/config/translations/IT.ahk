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
      "Sound Manager", "Gestore Audio",
      "Emulator Audio Config", "Configurazione Audio Emulatore",
      "Hardware Output Mapping", "Mappatura Uscite Hardware",
      "Route Game Audio (Strip 3)", "Instrada audio gioco (Traccia 3)",
      "Capture Backend", "Backend acquisizione",
      "Backend:", "Backend:",
      "Save", "Salva",
      "Refresh Device List ↻", "Aggiorna elenco dispositivi ↻",
      "Clear", "Pulisci",
      "Mute", "Muto",
      "Hard Reset (Relaunch VoiceMeeter App)", "Reset forzato (riavvia VoiceMeeter)",
      "Out A1", "Uscita A1",
      "Out A2", "Uscita A2",
      "Out A3", "Uscita A3",
      "Install Loopback Helper", "Installa helper loopback",
      "Test Loopback 3s", "Test loopback 3 s",
      "Help", "Aiuto",
      "Check for Updates", "Controlla aggiornamenti",
      "Choose an option", "Scegli un'opzione",
      "Status:", "Stato:",
      "Ready", "Pronto",
      "Saved backend:", "Backend salvato:",
      "Capture backend saved:", "Backend acquisizione salvato:",
      "Loopback helper installed", "Helper loopback installato",
      "Loopback install failed", "Installazione helper loopback fallita",
      "Install Error", "Errore di installazione",
      "Could not install loopback helper.", "Impossibile installare l'helper loopback.",
      "FFmpeg missing", "FFmpeg mancante",
      "Capture Test", "Test acquisizione",
      "FFmpeg missing:", "FFmpeg mancante:",
      "Loopback helper missing", "Helper loopback mancante",
      "Loopback helper is missing and could not be installed.", "L'helper loopback manca e non può essere installato.",
      "Running 3s loopback test...", "Esecuzione test loopback di 3 s...",
      "Loopback test saved:", "Test loopback salvato:",
      "Loopback test capture saved", "Acquisizione test loopback salvata",
      "Loopback test failed", "Test loopback fallito",
      "Loopback test failed. No valid output file was generated.", "Il test loopback è fallito. Nessun file di output valido è stato generato.",
      "Update check finished", "Controllo aggiornamenti completato",
      "Update Check", "Controllo aggiornamenti",
      "Update Decision", "Scelta aggiornamento",
      "Apply All Updates", "Applica tutti gli aggiornamenti",
      "Install Helper", "Installa helper",
      "Download FFmpeg", "Scarica FFmpeg",
      "Download Nexus", "Scarica Nexus",
      "Skip", "Salta",
      "Helper local", "Helper locale",
      "FFmpeg local", "FFmpeg locale",
      "Nexus local", "Nexus locale",
      "Latest", "Ultima",
      "Stable", "Stabile",
      "Nightly", "Nightly",
      "Selected release", "Release selezionata",
      "None", "Nessuna",
      "AT3 Convert", "Conv. AT3",
        "Pad Test", "Test Pad",
        "Hash Calc / Validator", "Validatore Hash",
        "Wipe Full List", "Svuota Tutto",
        "Hide Advanced", "Nascondi Avanzate",
        "Show Advanced Utilities", "Mostra Utilità",
      "Patch", "Applica Patch",
      "Wizard", "Procedura Guidata",
      "Build PS5 Linux Image", "Crea immagine PS5 Linux",
      "Open Balena Etcher", "Apri Balena Etcher",
      "Open Build Guide", "Apri guida build",
      "Build PS5 Linux image subtitle", "Compila l'immagine PS5 Linux in WSL, poi scrivi il file .img con Balena Etcher.",

        ; --- NEW GALLERY KEYS ---
        "Previous", "Prec", "Next", "Succ", "Slideshow", "Presentazione", "Browse", "Sfoglia", "Delete", "Elimina",
        "Image", "Immagine", "Path", "Percorso", "Size", "Dimensione",
        "GALLERY_HELP_1", "Premi Spazio per avviare la presentazione.",
        "GALLERY_HELP_2", "Doppio clic per schermo intero.",
        "GALLERY_HELP_3", "Premi M a schermo intero per cambiare monitor.",
        "GALLERY_HELP_4", "Premi DELETE per eliminare l'immagine.",

        "HELP_TEXT_SOUND_MANAGER", "
        (
1. MODALITÀ AUDIO:
   - Auto usa prima l'helper loopback.
   - Loopback cattura il dispositivo di riproduzione Windows corrente.
   - DShow usa il dispositivo di ingresso diretto configurato.
   - Voicemeeter mantiene il flusso di routing legacy.

2. IMPOSTAZIONI AUDIO DI WINDOWS:
   - Imposta come uscita predefinita gli altoparlanti o le cuffie che vuoi ascoltare.
   - Lascia il microfono come ingresso per i comandi vocali.
   - Se l'audio passa da un dispositivo non predefinito, passa a DShow o Voicemeeter.

3. HELPER LOOPBACK:
   - Clicca su Installa helper loopback se l'helper integrato manca.
   - Clicca su Test loopback 3 s per verificare che l'audio di sistema venga catturato.

4. AGGIORNAMENTI:
   - Usa il pulsante di controllo per confrontare helper, FFmpeg e Nexus.

5. ROUTING LEGACY:
   - Voicemeeter resta disponibile per chi ha bisogno del routing manuale dei bus.
        )",

      "HELP_TEXT_PS5_LINUX_IMAGE", "
      (
Per creare la tua immagine su Windows, esegui prima questo comando in PowerShell come amministratore per installare WSL:

   wsl --install

Installa Ubuntu. Prima controlla le distro disponibili:

   wsl --list --online

Poi installa:

   wsl --install Ubuntu-26.04

Installa Docker:

   sudo apt update
   sudo apt install docker.io -y
   sudo service docker start
   sudo usermod -aG docker $USER

Quindi clona e compila:

   cd ~/
   git clone https://github.com/ps5-linux/ps5-linux-image
   cd ps5-linux-image
   chmod +x ./build_image.sh
   sudo bash ./build_image.sh --distro ubuntu2604

L'immagine finale viene salvata in:

   output/ps5-ubuntu2604.img

Scrivi l'immagine su USB:

- Dimensione minima unità: 64 GB. Un SSD esterno è fortemente consigliato.
- Scarica Balena Etcher (https://etcher.balena.io/), seleziona il file .img,
  seleziona l'unità USB e clicca Flash.
- Ignora il messaggio di formattazione.
      )",

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
