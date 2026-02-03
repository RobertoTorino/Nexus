#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Dictionary for UI Translation (EN, CN, JP, IT, ES).
; * @class TranslationManager
; * @location lib/config/TranslationManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class TranslationManager {
    static CurrentLang := "EN"
    static Languages := ["EN", "CN", "JP", "IT", "ES", "FR"]

    static Cycle() {
        currentIndex := 0
        for i, lang in this.Languages {
            if (lang == this.CurrentLang) {
                currentIndex := i
                break
            }
        }
        nextIndex := currentIndex + 1
        if (nextIndex > this.Languages.Length)
            nextIndex := 1
        this.CurrentLang := this.Languages[nextIndex]
        return this.CurrentLang
    }

    static GetCurrentCode() => this.CurrentLang

static T(text) {
        ; 1. ENGLISH LOGIC
        if (this.CurrentLang == "EN") {
            ; Special Case: Long Blocks of Text or Special Keys
            if (text == "HELP_TEXT_MAIN")
                return this.GetEnglishHelp()

            ; NEW: Handle Gallery Help Keys for English
            if (text == "GALLERY_HELP_1")
            return "Press Spacebar to start fullscreen slideshow."
            if (text == "GALLERY_HELP_2")
            return "Double click image for fullscreen."
            if (text == "GALLERY_HELP_3")
            return "Press M in fullscreen to switch monitors."
            if (text == "GALLERY_HELP_4")
            return "Press DELETE to recycle image."

            ; Otherwise, return the text as-is (e.g. "Previous", "Next")
            return text
        }

        ; 2. OTHER LANGUAGES (Dictionary Lookup)
        clean := Trim(text)
        if (this.Dictionary.Has(this.CurrentLang) && this.Dictionary[this.CurrentLang].Has(clean)) {
            translation := this.Dictionary[this.CurrentLang][clean]
            return StrReplace(text, clean, translation)
        }
        return text
    }

    static GetEnglishHelp() {
        return "
        (
    1. ADDING GAME PATHS:
       - Click Set Launch Path to add the main game executable.
       - For TeknoParrot select a game profile in Profiles.

    2. EMULATORS:
       - Click Emulator to set the paths.

    3. RUNNING GAMES:
       - Selecting an .ISO/'EBOOT.BIN will ask you which emulator to use.
       - Or select a game from the list and click ▶️

    4. WHEN THE GAME IS ACTIVE:
       - Use Window Manager to manipulate the game window.
       - Use CPU buttons to fix lag/stutter.
       - Burst takes rapid screenshots (max. 99).

    5. RECORDING:
       - Record only the audio or record a video including sound.

    6. TOOLS:
       - Atrac3 Converter: Convert ATRAC3 audio format to WAV.
       - File Validator: Check MD5/SHA1 hashes of ISOs.
       - Game Search Database.

    7. HOTKEYS:
       - Escape button, exit the game.
       - Escape+1, hard reset.
       - Control+L opens live log trail.

    8. QUICK LAUNCH
       - Right click on the tray icon for quick launch.
       - Double click on the title bar to switch to text mode.

    9. MAGNETIC WINDOWS
       - Hold Control on the Main UI to detach it.

    T. TROUBLESHOOTING:
       - To reboot a game use Restart Game.
       - Use View Logs to look for errors.
       - Audio related, check Audio Manager.
        )"
    }

static Dictionary := Map(
        "CN", Map(
            ; --- EXISTING UI ---
            "Set Launch Path", "设置启动路径",
            "Profiles", "配置文件",
            "Delete Game", "删除游戏",
            "Emulators", "模拟器",
            "Clear Path", "清除路径",
            "Restore Path", "恢复路径",
            "Window Manager", "窗口管理",
            "Focus", "聚焦窗口", "Music",
            "音乐", "Video", "视频",
            "Gallery", "画廊",
            "Database", "数据库",
            "Notes", "备注",
            "Browser", "浏览器",
            "Rec Audio", "录制音频",
            "Rec Video", "录制视频",
            "Icon Manager", "图标管理",
            "Idle", "空闲",
            "Normal", "正常",
            "High", "高优",
            "Realtime", "实时",
            "Clone Wizard", "克隆向导",
            "Patch Manager", "补丁管理",
            "Purge Logs", "清除日志",
            "Purge List", "清空列表",
            "Wipe List", "清空列表",
            "View Logs", "查看日志",
            "Show Games Config", "游戏配置",
            "View System Config", "系统配置",
            "AT3 Convert", "AT3 转换",
            "RPCS3 Audio Fix", "RPCS3 音频修复",
            "Hash Calc / Validator", "哈希校验",
            "Wipe Full List", "清空完整列表", ; <--- NEW
            "Hide Advanced", "隐藏高级",
            "Show Advanced Utilities", "显示高级工具",
            "Patch Game", "应用补丁",

            ; --- NEW GALLERY KEYS ---
            "Previous", "上一张", "Next", "下一张", "Slideshow", "幻灯片", "Browse", "浏览", "Delete", "删除",
            "Image", "图片", "Path", "路径", "Size", "大小",
            "GALLERY_HELP_1", "按空格键开始全屏幻灯片。",
            "GALLERY_HELP_2", "双击图片进入全屏模式。",
            "GALLERY_HELP_3", "全屏时按 M 键切换显示器。",
            "GALLERY_HELP_4", "按 DELETE 键删除图片。",

            ; --- HELP TEXT ---
            "HELP_TEXT_MAIN", "
            (
    1. 添加游戏路径:
       - 点击 '设置启动路径' 添加游戏主程序。
       - 对于 TeknoParrot，请在 '配置文件' 中选择游戏。

    2. 模拟器:
       - 点击 '模拟器' 设置路径。

    3. 运行游戏:
       - 选择 .ISO 或 EBOOT.BIN 时会询问使用哪个模拟器。
       - 或从列表中选择游戏并点击 ▶️。

    4. 游戏运行时:
       - 使用 '窗口管理' 操作游戏窗口。
       - 使用 CPU 按钮修复卡顿。
       - '连拍' 可快速截图（最多99张）。

    5. 录制:
       - 仅录制音频或录制带声音的视频。

    6. 工具:
       - Atrac3 转换器：将 ATRAC3 音频转换为 WAV。
       - 文件验证器：检查 ISO 的 MD5/SHA1 哈希值。
       - 游戏搜索数据库。

    7. 热键:
       - Escape 键：退出游戏。
       - Escape + 1：硬重置。
       - Control + L：打开实时日志。

    8. 快速启动:
       - 右键点击托盘图标进行快速启动。
       - 双击标题栏切换到文本模式。

    9. 磁性窗口:
       - 按住 Control 键可将主界面分离。

    T. 故障排除:
       - 要重启游戏，请使用 '重启游戏'。
       - 使用 '查看日志' 查找错误。
       - 音频相关问题，请检查 '音频管理器'。
            )"
        ),
        "JP", Map(
            ; --- EXISTING UI ---
            "Set Launch Path", "起動パス設定",
            "Profiles", "プロファイル",
            "Delete Game", "削除",
            "Emulators", "エミュレータ",
            "Clear Path", "パス消去",
            "Restore Path", "パス復元",
            "Window Manager", "ウィンドウ管理",
            "Focus", "フォーカス",
            "Music", "音楽",
            "Video", "ビデオ",
            "Gallery", "ギャラリー",
            "Database", "データベース",
            "Notes", "メモ",
            "Browser", "ブラウザ",
            "Rec Audio", "録音",
            "Rec Video", "録画",
            "Icon Manager", "アイコン",
            "Idle", "低",
            "Normal", "通常",
            "High", "高",
            "Realtime", "リアルタイム",
            "Clone Wizard", "クローン作成",
            "Patch Manager", "パッチ管理",
            "Purge Logs", "ログ消去",
            "Purge List", "リスト消去",
            "Wipe List", "リスト消去",
            "View Logs", "ログ表示",
            "Show Games Config", "ゲーム設定",
            "View System Config", "システム設定",
            "AT3 Convert", "AT3 変換",
            "RPCS3 Audio Fix", "RPCS3 音声修正",
            "Hash Calc / Validator", "ハッシュ計算",
            "Wipe Full List", "リスト完全消去", ; <--- NEW
            "Hide Advanced", "詳細を隠す",
            "Show Advanced Utilities", "詳細ツールを表示",
            "Patch Game", "パッチ適用",

            ; --- NEW GALLERY KEYS ---
            "Previous", "前へ", "Next", "次へ", "Slideshow", "スライドショー", "Browse", "参照", "Delete", "削除",
            "Image", "画像", "Path", "パス", "Size", "サイズ",
            "GALLERY_HELP_1", "スペースキーでスライドショーを開始。",
            "GALLERY_HELP_2", "ダブルクリックで全画面表示。",
            "GALLERY_HELP_3", "全画面時に M でモニター切替。",
            "GALLERY_HELP_4", "DELETE キーで画像を削除。",

            ; --- HELP TEXT ---
            "HELP_TEXT_MAIN", "
            (
    1. ゲームパスの追加:
       - '起動パス設定' をクリックして実行ファイルを追加します。
       - TeknoParrot の場合は 'プロファイル' を選択してください。

    2. エミュレータ:
       - 'エミュレータ' をクリックしてパスを設定します。

    3. ゲームの実行:
       - .ISO/EBOOT.BIN を選択するとエミュレータを尋ねられます。
       - リストから選択して ▶️ をクリックします。

    4. ゲーム中:
       - 'ウィンドウ管理' でウィンドウを操作します。
       - CPUボタンでラグを修正します。
       - バースト機能で連続スクリーンショットを撮影できます。

    5. 録画・録音:
       - 音声のみ、または音声付きビデオを録画します。

    6. ツール:
       - Atrac3 変換: 音声を WAV に変換。
       - ファイル検証: ISO のハッシュチェック。
       - データベース検索。

    7. ホットキー:
       - Escape: ゲーム終了。
       - Escape + 1: ハードリセット。
       - Control + L: ログ表示。

    8. クイック起動:
       - トレイアイコンを右クリック。
       - タイトルバーをダブルクリックでテキストモード切替。

    9. マグネットウィンドウ:
       - Controlキーを押しながらドラッグで分離。

    T. トラブルシューティング:
       - 再起動ボタンでリブート。
       - エラーはログを確認してください。
       - 音声の問題はオーディオマネージャーを確認。
            )"
        ),
        "IT", Map(
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
       - Escape + 1: Hard reset.
       - Control + L: Apre il log live.

    8. AVVIO RAPIDO:
       - Tasto destro sull'icona della tray.
       - Doppio click sulla barra del titolo per modalità testo.

    9. FINESTRE MAGNETICHE:
       - Tieni premuto Ctrl per staccare la finestra principale.

    T. RISOLUZIONE PROBLEMI:
       - Usa 'Riavvia' per riavviare il gioco.
       - Controlla i Log per errori.
       - Per problemi audio, controlla 'Musica'.
            )"
        ),
        "ES", Map(
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
       - Escape + 1: Hard reset.
       - Control + L: Ver registro en vivo.

    8. INICIO RÁPIDO:
       - Clic derecho en icono de bandeja.
       - Doble clic en barra de título para modo texto.

    9. VENTANAS MAGNÉTICAS:
       - Mantén Control para separar la ventana principal.

    T. SOLUCIÓN DE PROBLEMAS:
       - Para reiniciar usa 'Reiniciar'.
       - Usa 'Ver Logs' para errores.
       - Problemas de audio, revisa 'Música'.
            )"
        ),
        "FR", Map(
            ; --- MAIN UI BUTTONS ---
            "Set Launch Path", "Définir Chemin",
            "Profiles", "Profils",
            "Delete Game", "Supprimer",
            "Emulators", "Émulateurs",
            "Clear Path", "Effacer",
            "Restore Path", "Restaurer",
            "Window Manager", "Fenêtres",
            "Focus", "Focus",
            "Music", "Musique",
            "Video", "Vidéo",
            "Gallery", "Galerie",
            "Database", "Base de Données",
            "Notes", "Notes",
            "Browser", "Navigateur",
            "Rec Audio", "Enr. Audio",
            "Rec Video", "Enr. Vidéo",
            "Icon Manager", "Icônes",
            "Idle", "Inactif",
            "Normal", "Normal",
            "High", "Haut",
            "Realtime", "Temps Réel",
            "Clone Wizard", "Assistant Clone",
            "Patch Manager", "Gestion Patchs",
            "Purge Logs", "Vider Logs",
            "Purge List", "Vider Liste",
            "View Logs", "Voir Logs",
            "Show Games Config", "Config Jeux",
            "View System Config", "Config Système",
            "Hide Advanced", "Masquer Avancé",
            "Show Advanced Utilities", "Outils Avancés",
            "Patch Game", "Patcher Jeu",

            ; --- ADVANCED UTILITIES ---
            "AT3 Convert", "Conv. AT3",
            "RPCS3 Audio Fix", "Fix Audio RPCS3",
            "Hash Calc / Validator", "Calc. Hash",
            "Wipe List", "Vider Liste",
            "Wipe Full List", "Tout Effacer",

            ; --- GALLERY ---
            "Previous", "Précédent", "Next", "Suivant", "Slideshow", "Diaporama", "Browse", "Parcourir", "Delete", "Supprimer",
            "Image", "Image", "Path", "Chemin", "Size", "Taille",
            "GALLERY_HELP_1", "Appuyez sur Espace pour lancer le diaporama.",
            "GALLERY_HELP_2", "Double-cliquez pour le plein écran.",
            "GALLERY_HELP_3", "Appuyez sur M en plein écran pour changer d'écran.",
            "GALLERY_HELP_4", "Appuyez sur SUPPR pour supprimer l'image.",

            ; --- HELP TEXT ---
            "HELP_TEXT_MAIN", "
            (
    1. AJOUTER DES JEUX :
       - Cliquez sur 'Définir Chemin' pour ajouter l'exécutable principal.
       - Pour TeknoParrot, sélectionnez un profil dans 'Profils'.

    2. ÉMULATEURS :
       - Cliquez sur 'Émulateurs' pour configurer les chemins.

    3. LANCER DES JEUX :
       - Sélectionner un .ISO/.BIN vous demandera quel émulateur utiliser.
       - Ou sélectionnez un jeu dans la liste et cliquez sur ▶️.

    4. QUAND LE JEU EST ACTIF :
       - Utilisez 'Fenêtres' pour manipuler la fenêtre du jeu.
       - Utilisez les boutons CPU pour corriger les ralentissements.
       - 'Rafale' prend des captures d'écran rapides (max. 99).

    5. ENREGISTREMENT :
       - Enregistrez uniquement l'audio ou la vidéo avec le son.

    6. OUTILS :
       - Convertisseur AT3 : Convertit l'audio ATRAC3 en WAV.
       - Validateur de Fichier : Vérifie les hashs MD5/SHA1.
       - Base de données de recherche de jeux.

    7. RACCOURCIS :
       - Échap : Quitter le jeu.
       - Échap + 1 : Réinitialisation matérielle (Reset).
       - Ctrl + L : Ouvrir le journal en direct.

    8. LANCEMENT RAPIDE :
       - Clic droit sur l'icône de la barre des tâches.
       - Double-clic sur la barre de titre pour le mode texte.

    9. FENÊTRES MAGNÉTIQUES :
       - Maintenez Ctrl sur l'interface principale pour la détacher.

    T. DÉPANNAGE :
       - Pour redémarrer un jeu, utilisez 'Redémarrer'.
       - Utilisez 'Voir Logs' pour chercher des erreurs.
       - Problèmes audio, vérifiez 'Musique'.
            )"
        )
    )
}