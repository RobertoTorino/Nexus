#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Main GUI. Modern "Superslick" UI.
; * @class GuiBuilder
; * @location lib/ui/GuiBuilder.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include EmulatorConfigGui.ahk
#Include CloneGameWizardGui.ahk
#Include WindowManagerGui.ahk
#Include ..\capture\AudioManager.ahk
#Include ..\capture\CaptureManager.ahk
#Include ..\config\GameRegistrarManager.ahk
#Include ..\config\TeknoParrotManager.ahk
#Include ..\emulator\LauncherFactory.ahk
#Include ..\emulator\types\StandardLauncher.ahk
#Include ..\media\SnapshotGallery.ahk
#Include ..\media\MusicPlayer.ahk
#Include ..\media\VideoPlayer.ahk
#Include ..\process\ProcessManager.ahk
#Include ..\tools\AtracConverterTool.ahk
#Include ..\tools\SystemInfoTool.ahk
#Include ..\tools\FileValidatorTool.ahk
#Include ..\tools\GameDatabaseTool.ahk
#Include ..\tools\PatchServiceTool.ahk
#Include ..\ui\ConfigViewerGui.ahk
#Include ..\ui\IconManagerGui.ahk
#Include ..\ui\PatchManagerGui.ahk
#Include ..\config\TranslationManager.ahk

class GuiBuilder {
    static MainGui := ""
    static UseIcons := true

    ; --- [HELPER] Translation Wrappers ---
    static T(text) => TranslationManager.T(text)

    static Label(icon, text) {
        return this.UseIcons ? " " icon " " : "  " this.T(text) "  "
    }

    ; --- [ACTION] Toggle Translation ---
    static ToggleLanguage() {
        TranslationManager.Cycle()
        this.ReloadUI()
    }

    ; --- [ACTION] Toggle UI Mode ---
    static ToggleUiMode() {
        if HasProp(this, "ToggleTimers")
            this.ToggleTimers(false)
        this.UseIcons := !this.UseIcons
        this.ReloadUI()
    }

    static ReloadUI() {
        ; Stop timers BEFORE destroying window to prevent crashes
        this.ToggleTimers(false)

        x := "", y := ""
        if (this.MainGui) {
            try this.MainGui.GetPos(&x, &y)
            this.MainGui.Destroy()
            this.MainGui := ""
        }

        this.Create(this.StartGameCallback)

        if (x != "" && y != "")
            this.MainGui.Show("x" x " y" y " AutoSize")
    }

    ; --- CONTROL GROUPS ---
    static AdvancedControls := []
    static BannerControl := ""
    static BtnHideAdvanced := ""
    static StartGameCallback := ""
    static LastAudioState := -1
    static LastVideoState := -1
    static TimerStatusObj := "", TimerRecObj := "", TimerTitleObj := ""

    ; --- CONTROLS ---
    static GameSelector := ""
    static TimerAudio := "", TimerVideo := "", BurstInput := ""
    static StatsHeader := 0
    static TitleControl := ""
    static StatusText := ""
    static BtnStart := 0, BtnRestart := 0, BtnExit := 0
    static BtnRecAudio := 0, BtnRecVideo := 0
    static BtnBurstStart := 0
    static BtnCpu := []
    static CachedGameCount := 0
    static CachedTotalTime := "0h"

    ; --- [METHOD] Create ---
    static Create(startCallback := "") {
        loadStart := A_TickCount
        this.LastAudioState := -1
        this.LastVideoState := -1
        Logger.Debug("GUI creation started...")

        if (startCallback)
            this.StartGameCallback := startCallback

        guiW := 805

        this.TimerStatusObj := ObjBindMethod(this, "UpdateStatusBar")
        this.TimerRecObj := ObjBindMethod(this, "UpdateRecordingTimers")
        this.TimerTitleObj := ObjBindMethod(this, "UpdateTitle")

        this.MainGui := Gui("-Caption +AlwaysOnTop +LastFound +Border", "Nexus")
        this.MainGui.MarginX := 0
        this.MainGui.MarginY := 0
        this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")
        this.MainGui.OnEvent("Close", (*) => ExitApp())
        this.MainGui.SetFont("s11 cSilver", "Segoe UI")
        this.MainGui.BackColor := "2A2A2A"

        ; [HOTKEY] F9 Translation Toggle
        Hotkey "F9", (*) => this.ToggleLanguage(), "On"

        ; --- TOOLBAR ---
        titleText := "Nexus :: " Chr(169) "" A_YYYY ""
        DragWin := (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd)
        ToggleMode := (*) => this.ToggleUiMode()

        this.TitleControl := this.MainGui.Add("Text", "x0 y0 w" (guiW - 345) " h30 +0x200 Background2A2A2A", titleText)
        this.TitleControl.OnEvent("Click", DragWin)
        this.TitleControl.OnEvent("DoubleClick", ToggleMode)

        this.MainGui.Add("Text", "x+20 h30 +0x200 Center -Border", "-  A:").OnEvent("Click", DragWin)
        this.TimerAudio := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00  ")
        this.TimerAudio.OnEvent("Click", DragWin)
        this.TimerAudio.OnEvent("DoubleClick", ToggleMode)

        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " -  V:").OnEvent("Click", DragWin)
        this.TimerVideo := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00 ")
        this.TimerVideo.OnEvent("Click", DragWin)
        this.TimerVideo.OnEvent("DoubleClick", ToggleMode)
        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " - ").OnEvent("Click", DragWin)

        ; --- TOOLBAR BUTTONS ---
        this.MainGui.SetFont("s12 cSilver", "Segoe UI")

        BtnAppReload := this.MainGui.Add("Text", "x+10 yp h30 +0x200 +Center Background2A2A2A cSilver", "↻")
        BtnAppReload.OnEvent("Click", (*) => Reload())

        this.AddNavBtn("  ?  ", (*) => this.ShowHelp(), "x+3 yp-3 h35 -Border")
        this.AddNavBtn("  i  ", (*) => SystemInfoTool.Show(), "x+0 yp h35 -Border")

        this.MainGui.Add("Text", "x+0 yp-3 w30 h35 +0x200 Center Background2A2A2A", "_").OnEvent("Click", (*) => this.MainGui.Minimize())
        this.MainGui.Add("Text", "x+-4 yp+5 w30 h30 +0x200 Center cRed", "✕").OnEvent("Click", (*) => ExitApp())
        this.MainGui.Add("Text", "x0 y+2 w" guiW " h1 Background333333")

        ; --- ROW 1 ---
        this.MainGui.SetFont(this.UseIcons ? "s16" : "s12")
        this.AddNavBtn(this.Label("➕", "Set Launch Path"), (btn, *) => (this.FlashButton(btn), this.OnAddGame()), "x5 y40 Background006666")
        this.AddNavBtn(this.Label("🕹️", "Profiles"), (btn, *) => (this.FlashButton(btn), TeknoParrotManager.ShowPicker()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🧹", "Delete Game"), (btn, *) => (this.FlashButton(btn), this.OnDeleteGame()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🛠️", "Emulators"), (btn, *) => (this.FlashButton(btn), EmulatorConfigGui.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🗑️", "Clear Path"), (btn, *) => (this.FlashButton(btn), this.OnClearPath()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🔧", "Restore Path"), (btn, *) => (this.FlashButton(btn), this.OnRefreshPath()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🔲", "Window Manager"), (btn, *) => (this.FlashButton(btn), WindowManagerGui.Show()), "x+10 Background333333")

        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp" : "y+10"
        this.AddNavBtn(this.Label("👁️", "Focus"), (btn, *) => (this.FlashButton(btn), this.OnFocusGame()), NextX " " NextY " Background333333")
        this.AddNavBtn(this.Label("🎵", "Music"), (btn, *) => (this.FlashButton(btn), MusicPlayer.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🎬", "Video"), (btn, *) => (this.FlashButton(btn), VideoPlayer.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🖼️", "Gallery"), (btn, *) => (this.FlashButton(btn), this.OnOpenGallery()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🗄️", "Database"), (btn, *) => (this.FlashButton(btn), GameDatabaseTool.Show()), "x+10 Background006666")
        this.AddNavBtn(this.Label("📝", "Notes"), (btn, *) => (this.FlashButton(btn), this.OnNotes()), "x+10 Background006666")
        this.AddNavBtn(this.Label("📁", "Browser"), (btn, *) => (this.FlashButton(btn), this.OnFileBrowser()), "x+10 Background006666")

        ; --- ROW 2 ---
        this.MainGui.SetFont("s16", "Segoe UI")
        this.BtnStart := this.AddNavBtn("  ▶️  ", (*) => this.OnStartAction(), "x5 y+10 h35")
        this.BtnRestart := this.AddNavBtn(" ♻️ ", (*) => this.OnRestartAction(), "x+10 h35")
        this.BtnExit := this.AddNavBtn(" ❌ ", (*) => this.OnExitAction(), "x+10 h35")

        this.MainGui.SetFont("s12", "Segoe UI")
        this.MainGui.Add("Text", "x+10 yp w476 h35 Background333333")
        this.GameSelector := this.MainGui.Add("Edit", "xp+3 yp+2 w441 h22 Background02A2A2A -E0x200 +ReadOnly -VScroll Center", "")
        this.MainGui.Add("Text", "x+4 yp w25 h22 cSilver Background333333 +0x200 +Center", "▼")
        BtnOverlay := this.MainGui.Add("Text", "xp-521 yp-2 w550 h28 BackgroundTrans")
        BtnOverlay.OnEvent("Click", (*) => this.OpenGameList(ConfigManager.GetSortedList()))

        this.MainGui.SetFont("s16", "Segoe UI")
        this.AddNavBtn(" 📸 ", (*) => CaptureManager.TakeSnapshot(false), "x+10 Background333333 h35")
        this.BurstInput := this.MainGui.Add("Edit", "x+10 h35 w42 Number Center +0x200 Limit2 Background02A2A2A", " 5 ")
        this.BtnBurstStart := this.AddNavBtn("  ▶️ ", (*) => this.OnBurstSnap(), "x+0 Background333333 h35")

        ; --- ROW 3 ---
        size := this.UseIcons ? "s16" : "s12"
        this.MainGui.SetFont(size, "Segoe UI")
        this.BtnRecAudio := this.AddNavBtn(this.Label("🎙️", "Rec Audio"), (btn, *) => this.OnRecAudioClick(btn), "x5 y+10 Background333333")
        this.BtnRecVideo := this.AddNavBtn(this.Label("🎬", "Rec Video"), (btn, *) => this.OnRecVideoClick(btn), "x+10 Background333333")
        this.AddNavBtn(this.Label("🖼️", "Icon Manager"), (*) => IconManagerGui.Show(), "x+10 Background333333")

        this.MainGui.SetFont("s12", "Segoe UI")
        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp" : "y+10"
        cBtn := " Background333333"
        this.BtnCpu := []

        ; [TRANSLATION] Wrapped CPU
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("Idle") "  ", (*) => this.OnCpuClick("Low", 1), NextX " " NextY . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("Normal") " --  ", (*) => this.OnCpuClick("BelowNormal", 2), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("Normal") "  ", (*) => this.OnCpuClick("Normal", 3), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("Normal") " ++  ", (*) => this.OnCpuClick("AboveNormal", 4), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("High") "  ", (*) => this.OnCpuClick("High", 5), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  " this.T("Realtime") "  ", (*) => this.OnCpuClick("Realtime", 6), "x+10" . cBtn))
        this.BtnCpu[3].SetFont("c05FBE4")
        this.AddNavBtn("  GPU  ", (*) => ProcessManager.OpenOverclock(), "x+10 yp Background333333")

        ; --- ADVANCED ---
        this.AdvancedControls := []
        marker := this.MainGui.Add("Text", "x5 y+10 w0 h0", "")
        marker.GetPos(&advX, &advY)
        cAdv := " Background333333"

        ; [TRANSLATION] Wrapped Advanced
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Clone Wizard") "  ", (*) => CloneGameWizardGui.Show(), "x5 y" advY . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Patch Manager") "  ", (*) => PatchManagerGui.Show(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Purge Logs") "  ", (*) => this.OnClearLogs(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Purge List") "  ", (*) => this.OnClearAllGames(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("View Logs") "  ", (*) => this.OnViewLogs(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("View System Config") "  ", (*) => ConfigViewerGui.ShowGui("INI"), "x+10" . cAdv))

        ; ROW 2 ADVANCED
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Show Games Config") "  ", (*) => ConfigViewerGui.ShowGui(), "x5 y+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  RPCS3 Audio Fix  ", (*) => AudioManager.ShowGui(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  AT3 Converter  ", (*) => AtracConverterTool.Show(), "x+10 Background333333" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  Hash Calc / Validator  ", (*) => FileValidatorTool.Show(), "x+10" . cAdv))
        this.BtnHideAdvanced := this.AddNavBtn("  ▲ " this.T("Hide Advanced") "  ", (*) => this.ToggleAdvanced(false), "x+10 c05FBE4" . cAdv)
        this.AdvancedControls.Push(this.BtnHideAdvanced)

        this.BtnHideAdvanced.GetPos(, &lastY, , &lastH)
        totalH := (lastY + lastH) - advY

        this.BannerControl := this.MainGui.Add("Text", "x5 y" advY " w" (guiW - 10) " h" totalH " Border Right Background333333", "▼ " this.T("Show Advanced Utilities") " ▼  ")
        this.BannerControl.OnEvent("Click", (*) => this.ToggleAdvanced(true))

        ; --- FOOTER ---
        this.MainGui.SetFont("s10", "Segoe UI")

        this.MainGui.Add("Text", "x0 y+10 w" guiW " h1 Background333333")
        this.StatsHeader := this.MainGui.Add("Text", "x5 y+0 w" (guiW - 10) " h24 +0x200 vStatsHeader Background333333", "Loading Statistics...")
        this.MainGui.Add("Text", "x0 y+0 w" guiW " h1 Background333333")

        ; [STATUS BAR]
        this.StatusText := this.MainGui.Add("Text", "x5 y+2 w" (guiW - 55) " h22 +0x200 BackgroundTrans", "Ready")

        ; [LANGUAGE TEXT] - Plain Text, No Emojis, No weird fonts
        currentCode := TranslationManager.GetCurrentCode()
        BtnFlag := this.MainGui.Add("Text", "x+20 yp+1 w25 h22 +0x200 Center BackgroundTrans cSilver", currentCode)
        BtnFlag.OnEvent("Click", (*) => this.ToggleLanguage())

        this.MainGui.SetFont("s12", "Segoe UI")
        this.MainGui.Add("Text", "x0 y+5 w0 h0", "")

        ; --- DISPLAY ---
        this.ToggleAdvanced(false)
        this.MainGui.Show("AutoSize w" guiW)
        this.MainGui.Opt("+AlwaysOnTop")

        if (HasProp(this, "ToggleTimers"))
            this.ToggleTimers(true)
        if (HasProp(this, "SelectLastPlayed"))
            this.SelectLastPlayed()
        if (HasProp(this, "RefreshTopPlayed"))
            this.RefreshTopPlayed()
        if (HasProp(this, "UpdateTitle"))
            this.UpdateTitle()

        loadTime := A_TickCount - loadStart
        Logger.Info("Main GUI loaded in " . loadTime . " ms", "GuiBuilder")
        DialogsGui.CustomStatusPop("GUI Load Time: " . loadTime . "ms")
    }

    ; --- HANDLERS ---
    static OnClearPath(btnCtrl := "") {
        if (btnCtrl)
            this.FlashButton(btnCtrl)
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }
        if (DialogsGui.CustomMsgBox("Clear Path", "Remove the executable path for this game?", 300) != "Yes")
            return
        ConfigManager.UpdateGamePath(ConfigManager.CurrentGameId, "")
        this.RefreshDropdown()
        DialogsGui.CustomStatusPop("Path cleared")
    }

    static OnRefreshPath(btnCtrl := "") {
        if (btnCtrl)
            this.FlashButton(btnCtrl)
        id := ConfigManager.CurrentGameId
        if (id == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }
        if (!ConfigManager.Games.Has(id)) {
            DialogsGui.CustomStatusPop("Error: Game ID not found")
            ConfigManager.CurrentGameId := ""
            this.RefreshDropdown()
            return
        }
        gameObj := ConfigManager.Games[id]
        current := (Type(gameObj) == "Map") ? gameObj["ApplicationPath"] : gameObj.ApplicationPath
        newPath := FileSelect(3, current, "Select New Executable")

        if (newPath != "") {
            ConfigManager.UpdateGamePath(id, newPath)
            if (this.StatusText)
                this.StatusText.Text := "Updated path: " . newPath
            DialogsGui.CustomStatusPop("Path updated")
        }
    }

    static ToggleAdvanced(show) {
        if (show) {
            this.BannerControl.Visible := false
            for ctrl in this.AdvancedControls
                ctrl.Visible := true
        } else {
            for ctrl in this.AdvancedControls
                ctrl.Visible := false
            this.BannerControl.Visible := true
        }
        this.MainGui.Opt("+AlwaysOnTop")
    }

    ; --- [FIX] SAFE TIMER METHODS ---
    static UpdateTitle() {
        if !this.MainGui || !this.TitleControl
            return

        status := Utilities.IsInternetAvailable() ? "online" : "offline"
        timestamp := FormatTime(, "MM-dd hh:mm:ss tt")
        statsPart := " :: " . this.CachedGameCount . " Games (" . this.CachedTotalTime . ")"
        this.UpdateButtonState()

        try {
            if (this.TitleControl)
                this.TitleControl.Text := "  Nexus :: " Chr(169) "" A_YYYY " :: " status . statsPart . " :: " timestamp
        }
    }

    static UpdateRecordingTimers() {
        if !this.MainGui || !this.TimerAudio || !this.TimerVideo
            return

        try {
            if CaptureManager.IsRecordingAudio
                this.TimerAudio.Text := "   " . CaptureManager.GetDuration("Audio") . "  "
            if CaptureManager.IsRecordingVideo
                this.TimerVideo.Text := "  " . CaptureManager.GetDuration("Video") . "  "
            if (!CaptureManager.IsRecordingAudio && !CaptureManager.IsRecordingVideo) {
                if (this.TimerRecObj)
                    SetTimer(this.TimerRecObj, 0)
                this.TimerAudio.Text := "   00:00:00  "
                this.TimerVideo.Text := "  00:00:00  "
            }
        }
    }

    static UpdateStatusBar() {
        if !this.MainGui || !this.StatusText
            return

        procName := ConfigManager.ActiveProcessName
        if (procName != "" && ProcessExist(procName)) {
            if (ConfigManager.CurrentGameId != "")
                ConfigManager.AddPlayTime(ConfigManager.CurrentGameId, 1)
            try {
                if (this.StatusText) {
                    stats := ProcessManager.GetMonitorText(procName)
                    this.StatusText.Text := stats
                }
            }
        } else {
            if (ConfigManager.ActiveProcessName != "") {
                report := ProcessManager.EndSession()
                if (report != "")
                    DialogsGui.CustomStatusPop("Session Ended`n" . report)
                ConfigManager.ActiveProcessName := ""
                this.ClearGameGroup()
                this.RefreshTopPlayed()
            }
            try {
                if (this.StatusText)
                    this.StatusText.Text := ProcessManager.GetMonitorText()
            }
        }
    }

    ; --- [HANDLERS] ---

    static SetRecordingStatus(isRecording, activeExe := "") {
        if !this.MainGui
            return
        statusText := isRecording ? "   ⏺ RECORDING ACTIVE" : "   Ready"
        if (this.HasProp("StatusText") && this.StatusText)
            this.StatusText.Text := statusText
    }

    static OnRecAudioClick(btnCtrl) {
        this.FlashButton(btnCtrl)
        CaptureManager.ToggleAudioRecording()
        if (CaptureManager.IsRecordingAudio)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers()
    }

    static OnRecVideoClick(btnCtrl) {
        this.FlashButton(btnCtrl)
        CaptureManager.ToggleVideoRecording()
        if (CaptureManager.IsRecordingVideo)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers()
    }

    static UpdateButtonState() {
        if !this.HasProp("MainGui") || !this.MainGui
            return
        game := ConfigManager.GetCurrentGame()
        isActive := IsObject(game)
        controls := ["BtnSnap", "BtnIdle", "BtnNormalMin", "BtnNormal", "BtnNormalPlus", "BtnHigh", "BtnRealtime"]
        for ctrlName in controls {
            if (this.HasProp(ctrlName) && this.%ctrlName%) {
                ctrl := this.%ctrlName%
                if (ctrl.Enabled != isActive)
                    ctrl.Enabled := isActive
            }
        }
    }

    static OnClearLogs() {
        Logger.ClearLogFile()
        DialogsGui.CustomTrayTip("Logs purged successfully.")
    }

    static OnClearAllGames() {
        if (DialogsGui.CustomMsgBox("Wipe", "Delete ALL games?", 300) == "Yes") {
            ConfigManager.Games := Map()
            ConfigManager.SaveGames()
            this.RefreshDropdown()
            DialogsGui.CustomTrayTip("Database wiped.")
        }
    }

    static AddNavBtn(label, callback, options := "x+10 yp") {
        hBtn := this.UseIcons ? "h35" : "h30"
        btn := this.MainGui.Add("Text", hBtn " +0x200 +Center +Border " options, label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static RefreshTopPlayed() {
        this.CachedGameCount := ConfigManager.Games.Count
        this.CachedTotalTime := ConfigManager.GetTotalLibraryTime()
        topList := ConfigManager.GetTopGames(2)
        topLine := ""
        if (topList.Length == 0) {
            topLine .= "None"
        } else {
            for index, game in topList {
                safeName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                timeStr := (Type(game) == "Map") ? (game.Has("PlayTimeReadable") ? game["PlayTimeReadable"] : "0s")
                    : (game.HasProp("PlayTimeReadable") ? game.PlayTimeReadable : "0s")
                topLine .= index . ". " . safeName . " (" . timeStr . ")  "
                if (index < topList.Length)
                    topLine .= "| "
            }
        }
        if (this.StatsHeader)
            this.StatsHeader.Text := topLine
    }

    static SelectLastPlayed() {
        lastId := IniRead(ConfigManager.IniPath, "LAST_PLAYED", "GameID", "")
        if (lastId == "" || !ConfigManager.Games.Has(lastId)) {
            this.GameSelector.Value := ""
            return
        }
        game := ConfigManager.Games[lastId]
        nameToSelect := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        try {
            if (this.GameSelector)
                this.GameSelector.Value := nameToSelect
            this.OnGameChanged(this.GameSelector, 0)
        } catch {
            if (this.GameSelector)
                this.GameSelector.Value := ""
        }
    }

    static GetGameList() {
        if (ConfigManager.Games.Count == 0)
            ConfigManager.Init()
        list := ["- List Games -"]
        for name in ConfigManager.GetGameList()
            list.Push(name)
        if (list.Length == 1)
            list.Push("ERROR: No games found in JSON")
        list.Push("Available Games...")
        return list
    }

    static OnSelectionChange(selectedName) {
        success := ConfigManager.SetCurrentGameByName(selectedName)
        if (success) {
            Logger.Info("UI: Selection changed to " . selectedName, "GuiBuilder")
            this.UpdateButtonState()
        } else {
            Logger.Warn("UI: Could not find ID for game: " . selectedName)
        }
    }

    static RefreshDropdown() {
        if !this.GameSelector
            return
        targetId := ConfigManager.CurrentGameId
        nameToDisplay := ""
        if (targetId != "" && ConfigManager.Games.Has(targetId)) {
            game := ConfigManager.Games[targetId]
            nameToDisplay := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        }
        this.GameSelector.Value := nameToDisplay
    }

    static OnGameChanged(ctrl, *) {
        selectedName := ctrl.Value
        if (selectedName == "" || selectedName == "No Games Found" || selectedName == "- Select Game -") {
            if (this.HasProp("BtnPatch") && this.BtnPatch)
                this.BtnPatch.Enabled := false
            ConfigManager.CurrentGameId := ""
            this.UpdateButtonState()
            return
        }
        foundId := ""
        for id, game in ConfigManager.Games {
            name := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
            if (name == selectedName) {
                foundId := id
                break
            }
        }
        if (foundId != "") {
            ConfigManager.CurrentGameId := foundId
            IniWrite(foundId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")
            game := ConfigManager.Games[foundId]
            appFile := ""
            if (Type(game) == "Map") {
                if game.Has("GameApplication")
                    appFile := game["GameApplication"]
            } else {
                if game.HasProp("GameApplication")
                    appFile := game.GameApplication
            }
            if (this.HasProp("BtnPatch") && this.BtnPatch) {
                this.BtnPatch.Enabled := PatchServiceTool.KnownPatches.Has(appFile)
            }
            if (this.MainGui) {
                try {
                    this.RefreshTopPlayed()
                    this.UpdateButtonState()
                }
            }
        }
    }

    static OnAddGame() {
        this.ToggleTimers(false)
        this.MainGui.Opt("-AlwaysOnTop")
        try {
            if GameRegistrarManager.AddGame()
                this.RefreshDropdown()
        } finally {
            this.MainGui.Opt("+AlwaysOnTop")
            this.ToggleTimers(true)
        }
    }

    static OnStartAction() {
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }

        game := ConfigManager.GetCurrentGame()
        if (!game)
            return

        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnStart, true)

        GetProp := (key) => (Type(game) == "Map" ? (game.Has(key) ? game[key] : "") : (game.HasOwnProp(key) ? game.%key% : ""))

        launcherType := GetProp("LauncherType")

        ; --- NEW FACTORY LOGIC ---
        try {
            ; 1. Ask Factory for the correct class (Yuzu, Dolphin, Standard, etc.)
            launcherInstance := LauncherFactory.GetLauncher(launcherType)

            Logger.Info("UI Launching: " . GetProp("SavedName") . " via " . Type(launcherInstance), "GuiBuilder")

            ; 2. Execute Launch
            ; The specific class (e.g. YuzuLauncher) handles the PID, Window Registration, and specific arguments.
            if (launcherInstance.Launch(game)) {

                ; 3. Post-Launch UI Updates
                ProcessManager.StartSession(GetProp("SavedName"))
                ConfigManager.UpdateLastPlayed(ConfigManager.CurrentGameId)
                this.UpdateButtonState()

                Logger.Info("Launch sequence completed successfully.", "GuiBuilder")
            } else {
                DialogsGui.CustomStatusPop("Launch Failed")
            }

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Error", err.Message, 0x10)
            this.ClearGameGroup()
        }
    }

    static OnRestartAction() {
        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnRestart, true)
        this.OnKillGame(false)
        Sleep(500)
        this.OnStartAction()
    }

    static OnKillGame(resetUI := true) {
        targetExe := ConfigManager.ActiveProcessName
        if (targetExe != "") {
            if IsSet(Logger)
                Logger.Info("Terminating: " . targetExe, "GuiBuilder")
            if ProcessExist(targetExe) {
                ProcessClose(targetExe)
                DialogsGui.CustomStatusPop("Terminated: " . targetExe)
            }
            WindowManager.ForceKillAll()
        } else {
            WindowManager.ForceKillAll()
        }
        if (resetUI) {
            this.ClearGameGroup()
            ConfigManager.ActiveProcessName := ""
        }
    }

    static OnFocusGame() {
        if (hwnd := WindowManager.GetValidHwnd())
            WindowManager.ForceFocus(hwnd)
    }

    static OnDeleteGame() {
        ; Use exactly TWO parameters
        Logger.Info("Delete request initiated for ID: " . ConfigManager.CurrentGameId, "GuiBuilder")

        if (ConfigManager.CurrentGameId == "") {
            Logger.Warn("Delete aborted. No game selected.", "GuiBuilder")
            return
        }

        ; Confirm with Yes/No (Option 4)
        if (DialogsGui.CustomMsgBox("Delete Game", "Are you sure?", 0, 4) == "Yes") {
            Logger.Info("User confirmed delete for: " . ConfigManager.CurrentGameId, "GuiBuilder")

            if ConfigManager.DeleteGame(ConfigManager.CurrentGameId) {
                this.RefreshDropdown()
                DialogsGui.CustomStatusPop("Game Deleted")
            }
        }
    }


    static OnGameSelect(selectedName) {
        for id, game in ConfigManager.Games {
            if (game["SavedName"] == selectedName) {
                ConfigManager.CurrentGameId := id
                break
            }
        }
        this.UpdateButtonState()
    }

    static OnPatchGame() {
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomTrayTip("No Game Selected", 2)
            return
        }
        game := ConfigManager.GetCurrentGame()
        if !IsObject(game)
            return
        if (!game.HasProp("IsPatchable") || game.IsPatchable != "true") {
            DialogsGui.CustomTrayTip("Not Available", "No patches available for this game.")
            return
        }
        PatchServiceTool.OpenPatcher(game)
    }

    static OnOpenGallery() => SnapshotGallery.Show("")
    static OnViewLogs() => Run(Logger.GetLogFilePath())

    static OnBurstSnap() {
        count := Integer(this.BurstInput.Value)
        if (count < 1)
            return
        this.SetBtnHighlight(this.BtnBurstStart, true, "c05FBE4")
        Sleep(50)
        try {
            CaptureManager.TakeSnapshot(true, count)
        } finally {
            this.SetBtnHighlight(this.BtnBurstStart, false)
            DialogsGui.CustomStatusPop("Burst Sequence Complete")
        }
    }

    static OnFileBrowser() {
        game := ConfigManager.GetCurrentGame()
        if (game && Type(game) == "Map" && game.Has("ApplicationPath") && FileExist(game["ApplicationPath"])) {
            SplitPath(game["ApplicationPath"], , &dir)
            Run(dir)
        } else Run("explorer.exe")
    }

    static GetSelectedId() {
        if !this.GameList
            return ""
        row := this.GameList.GetNext(0, "Focused")
        if (row == 0)
            row := this.GameList.GetNext(0, "Selected")
        return (row > 0) ? this.GameList.GetText(row, 1) : ""
    }

    static OnNotes() {
        id := ConfigManager.CurrentGameId
        if (id == "") {
            DialogsGui.CustomStatusPop("Select a game first")
            return
        }
        if !ConfigManager.Games.Has(id)
            return
        game := ConfigManager.Games[id]
        cleanName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        notesGui := Gui("-Caption +Border +Owner" . this.MainGui.Hwnd, "Notes: " . cleanName)
        notesGui.BackColor := "1a1a1a"
        notesGui.SetFont("s10 Bold cGray")
        hdr := notesGui.Add("Text", "x15 y10 w470 h25 +0x200", "NOTES: " . StrUpper(cleanName))
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, notesGui.Hwnd))
        notesGui.SetFont("s14 Norm cWhite", "Segoe UI")
        existingNotes := (Type(game) == "Map") ? (game.Has("Notes") ? game["Notes"] : "") : (game.HasProp("Notes") ? game.Notes : "")
        editCtrl := notesGui.Add("Edit", "x15 y+10 w500 h300 Background333333 cWhite -E0x200 -VScroll -HScroll", existingNotes)
        notesGui.SetFont("s9 cSilver")
        btnStamp := notesGui.Add("Text", "x15 y+15 w70 h30 +0x200 Center Background333333", "Stamp")
        btnStamp.OnEvent("Click", (*) => EditPaste(FormatTime(, "MM-dd hh:mm tt") . ": ", editCtrl))
        btnSave := notesGui.Add("Text", "x+10 yp w110 h30 +0x200 Center Background333333", "Save & Close")
        btnSave.OnEvent("Click", (*) => (
            ConfigManager.UpdateGameNotes(id, editCtrl.Value),
            DialogsGui.CustomStatusPop("Notes Saved"),
            notesGui.Destroy()
        ))
        btnCancel := notesGui.Add("Text", "x+10 yp w70 h30 +0x200 Center Background333333", "Cancel")
        btnCancel.OnEvent("Click", (*) => notesGui.Destroy())
        notesGui.OnEvent("Escape", (*) => notesGui.Destroy())
        notesGui.Show()
    }

    static SaveGameNotes(gameId, text) {
        if ConfigManager.UpdateGameNotes(gameId, text)
            DialogsGui.CustomStatusPop("Notes Saved")
    }

    static ToggleTimers(state) {
        period := state ? 1000 : 0
        SetTimer(this.TimerStatusObj, period)
        SetTimer(this.TimerRecObj, period)
        SetTimer(this.TimerTitleObj, state ? 10000 : 0)
    }

    static ClearGameGroup() {
        if (this.HasProp("BtnStart") && this.BtnStart)
            this.SetBtnHighlight(this.BtnStart, false)
        if (this.HasProp("BtnRestart") && this.BtnRestart)
            this.SetBtnHighlight(this.BtnRestart, false)
    }

    static OnExitAction() {
        this.SetBtnHighlight(this.BtnExit, true)
        this.ClearGameGroup()
        this.OnKillGame()
        this.RefreshTopPlayed()
        SetTimer(() => this.SetBtnHighlight(this.BtnExit, false), -300)
        DialogsGui.CustomStatusPop("🛑 Session Ended - Stats Updated")
    }

    static OnCpuClick(priorityName, index) {
        for btn in this.BtnCpu {
            this.SetBtnHighlight(btn, false)
        }
        this.SetBtnHighlight(this.BtnCpu[index], true)
        try {
            ProcessManager.SetPriority(priorityName)
            DialogsGui.CustomStatusPop("CPU: " . priorityName)
        } catch {
            DialogsGui.CustomStatusPop("Failed to set CPU priority")
        }
    }

    static OnToggleAudio() {
        static isRecording := false
        isRecording := !isRecording
        this.SetBtnHighlight(this.BtnRecAudio, isRecording, "FF0000")
        if (isRecording) {
            DialogsGui.CustomStatusPop("Audio Recording Started", "Red")
        } else {
            DialogsGui.CustomStatusPop("Audio Recording Saved")
        }
    }

    static OnToggleVideo() {
        static isRecording := false
        isRecording := !isRecording
        this.SetBtnHighlight(this.BtnRecVideo, isRecording, "FF0000")
        if (isRecording) {
            DialogsGui.CustomStatusPop("Video Recording Started", "Red")
        } else {
            DialogsGui.CustomStatusPop("Video Recording Saved")
        }
    }

    static OpenGameList(items) {
        if !items
            return
        if WinExist("NexusGameListPopup")
            return
        this.GameSelector.GetPos(&gx, &gy, &gw, &gh)
        pt := Buffer(8)
        NumPut("int", gx, "int", gy + gh, pt)
        DllCall("ClientToScreen", "Ptr", this.MainGui.Hwnd, "Ptr", pt)
        screenX := NumGet(pt, 0, "int")
        screenY := NumGet(pt, 4, "int")
        PopupGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" this.MainGui.Hwnd, "NexusGameListPopup")
        PopupGui.BackColor := "Silver"
        PopupGui.SetFont("s12", "Segoe UI")
        PopupGui.MarginX := 1, PopupGui.MarginY := 1
        LB := PopupGui.Add("ListBox", "w" (gw + 50) " r15 Background333333 cSilver -E0x200", items)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", LB.Hwnd, "Str", "DarkMode_Explorer", "Str", 0)
        LB.OnEvent("Change", (*) => this.SelectGame(LB, PopupGui))
        PopupGui.OnEvent("Escape", (*) => PopupGui.Destroy())
        PopupGui.Show("x" screenX " y" screenY " w" (gw + 30))
        SetTimer(CloseIfInactive, 200)
        CloseIfInactive() {
            try {
                if WinExist("ahk_id " PopupGui.Hwnd) {
                    if !WinActive("ahk_id " PopupGui.Hwnd) {
                        SetTimer(, 0)
                        PopupGui.Destroy()
                    }
                } else {
                    SetTimer(, 0)
                }
            }
        }
    }

    static SelectGame(ListBoxCtrl, PopupGui) {
        selected := ListBoxCtrl.Text
        if (selected = "")
            return
        this.GameSelector.Value := selected
        PopupGui.Destroy()
        this.OnGameChanged(this.GameSelector)
    }

    static FlashButton(btnCtrl, color := "05FBE4") {
        btnCtrl.SetFont("c" . color)
        btnCtrl.Redraw()
        SetTimer(() => (btnCtrl.SetFont("cSilver"), btnCtrl.Redraw()), -200)
    }

    static SetBtnHighlight(btnObj, isHighlighted := true, activeColor := "05FBE4") {
        if !IsObject(btnObj)
            return
        if (isHighlighted) {
            btnObj.SetFont("c" . activeColor)
        } else {
            btnObj.SetFont("cSilver")
        }
        btnObj.Redraw()
    }

    static ShowHelp() {
        helpText := "
        (
    1. ADDING GAME PATHS:
       - Click Set Launch Path to add the main game excutable.
       - For TeknoParrot select a game profile in Profiles.

    2. EMULATORS:
       - Click Emulator to set the paths.

    3. RUNNING GAMES:
       - Selecting an .ISO/'EBOOT.BIN will ask you which emulator to use.
       - Or select a game from the list and click ▶️

    4. WHEN THE GAME IS ACTIVE:
       - Use Window Manager to identify, resize and position the window.
       - Use CPU buttons to fix lag/stutter.
       - Burst takes rapid screenshots (max. 99).

    5. RECORDING:
       - Record only the audio or record a video including sound.
       - Recordings are saved in Captures or Recordings folder.

    6. TOOLS:
       - Game Notes: Create/Edit specific notes for each game.
       - Atrac3 Converter: Convert ATRAC3 audio format to WAV.
       - File Validator: Check MD5/SHA1 hashes of ISOs.
       - Game Search Database.

    7. HOTKEYS:
       - Escape button, exit the game.
       - Escape + 1, hard reset.
       - Control L opens live log trail.

    8. QUICK LAUNCH
       - Right click on the tray icon for quick launch.
       - Double click on the title bar to switch to text mode.
       - To change language, click the language icon. 

    9. MAGNETIC WINDOWS
       - Hold Control on the Main UI to detach it.

    T. TROUBLESHOOTING:
       - If a game does not respond, use Exit Game (X).
       - To reboot a game use Restart Game.
       - Use View Logs to look for errors.
       - The statusbar shows the RAM usage.
       - Audio related, check Audio Manager.
    )"
        DialogsGui.ShowTextViewer("NEXUS :: Quick Start", helpText, 450, 825)
    }
}