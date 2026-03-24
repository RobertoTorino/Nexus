#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Icon & Sound Manager
; * @class IconManagerGui
; * @location lib/ui/IconManagerGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\config\ConfigManager.ahk
#Include ..\ui\DialogsGui.ahk
#Include ..\core\Utilities.ahk

class IconManagerGui {
    static MainGui := ""
    static PicGui := ""
    static FullscreenGui := ""

    ; State
    static CurrentGame := {}
    static CurrentPaths := { Icon0: "", Pic0: "", Pic1: "", Snd0: "", Snd0Wav: "" }
    static CurrentMonitor := 1
    static TempWavCreated := false
    static LoopTimerFunc := ""

    ; flat-button helper — Text control that mimics a button
    static BtnAddTheme(guiObj, label, callback, options) {
        btn := guiObj.Add("Text", options " +0x200 Center +Border Background333333", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; 1. GUI CREATION
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Icon Manager")
        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("Escape", (*) => this.Close())

        ; Total window width
        guiW := 805

        ; Title Bar (s11)
        this.MainGui.SetFont("s11 cSilver", "Segoe UI")
        title := this.MainGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background333333", "   Nexus :: Icon Manager")
        title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background333333 cRed", "✕").OnEvent("Click", (*) => this.Close())

        this.MainGui.SetFont("s11 cSilver", "Segoe UI")

        ; Game path
        this.LblPath := this.MainGui.Add("Text", "x10 h25 y+10 w785 Center +0x200 Background333333 Border", "  -")
        ; Icon path
        this.LblIconStatus := this.MainGui.Add("Text", "x10 h25 y+5 w785 Center +0x200 Background333333 Border", "  -")
        ; Sound path
        this.LblSoundStatus := this.MainGui.Add("Text", "x10 h25 y+5 w785 Center +0x200 Background333333 Border", "  -")

        ; s12 for all remaining controls
        this.MainGui.SetFont("s12 cSilver", "Segoe UI")

        ; --- LEFT COLUMN ---
        this.MainGui.Add("Text", "x10 h30 y+10 +0x200 Background333333 Center", "  Search:  ")

        ; Search box
        this.SearchBox := this.MainGui.Add("Edit", "x+5 yp w227 Background333333")
        this.SearchBox.OnEvent("Change", (*) => this.FilterList())

        ; Game list
        this.GameList := this.MainGui.Add("ListBox", "x10 y+15 w300 h330 Background333333", [])
        this.GameList.OnEvent("Change", (*) => this.OnGameSelect())

        ; Bottom buttons
        this.BtnAdd := this.BtnAddTheme(this.MainGui, "  + Add New  ", (*) => this.ShowAddGameDialog(), "x10 y+15 h26 Center Background333333")
        this.BtnRemove := this.BtnAddTheme(this.MainGui, "  ✕ Remove Selected  ", (*) => this.RemoveSelectedGame(), "x+10 h26 Center Background333333")

        ; --- RIGHT COLUMN ---
        xCol2 := 320
        rW := guiW - xCol2 - 8   ; 480

        ; Correct ICON0 aspect ratio: original 320 × 176 px
        picH := Round(rW * 176 / 320)

        this.MainGui.SetFont("s10 cSilver", "Segoe UI")
        ; Preview — aspect-correct ICON0 (320 × 176 native)
        this.PicPreview := this.MainGui.Add("Picture", "x" xCol2 " y135 w" rW " h" picH " Background333333", "")
        this.PicPreview.OnEvent("Click", (*) => this.ShowPic1Window())

        ; Text line
        hintY  := 122 + picH + 4
        this.MainGui.SetFont("s10 cSilver", "Segoe UI")
        this.MainGui.Add("Text", "x" xCol2 " y" hintY " w" rW " h26 +0x200 ", "Click image to view fullscreen background")

        ; Sound Controls
        this.MainGui.SetFont("s12 cSilver", "Segoe UI")
        soundY := hintY + 88
        this.BtnPlay := this.BtnAddTheme(this.MainGui, "  ▶  Play  ", (*) => this.PlaySnd0(), "x" xCol2 " y" soundY " h26")
        this.BtnStop := this.BtnAddTheme(this.MainGui, "  ■  Stop  ", (*) => this.StopSound(), "x+8 yp h26")
        this.ChkLoop := this.MainGui.Add("CheckBox", "x+12 yp+5", "Loop")

        ; Action Buttons (single row)
        ;btnW    := 113
        actionY := soundY + 36
        this.BtnCopyIcon   := this.BtnAddTheme(this.MainGui, "  Save Icon  ",   (*) => this.CopyAsset("ICON0"), "x" xCol2 " y" actionY " h26 Background333333" )
        this.BtnCopyPic    := this.BtnAddTheme(this.MainGui, "  Save Pic  ",    (*) => this.CopyAsset("PIC1"),  "x+6 yp h26 Background333333" )
        this.BtnCopyWav    := this.BtnAddTheme(this.MainGui, "  Save Audio  ",  (*) => this.CopyAsset("WAV"),   "x+6 yp h26 Background333333" )
        this.BtnOpenFolder := this.BtnAddTheme(this.MainGui, "  Open Folder  ", (*) => this.OpenMediaFolder(), "x+6 yp h26 Background333333"  )

        guiH := actionY + 100
        this.PopulateGameList()
        this.MainGui.Show("w" guiW " h" guiH)
    }

    static Close() {
        this.StopSound()

        ; FIX: Check if Object before destroying
        if IsObject(this.PicGui)
            this.PicGui.Destroy()
        if IsObject(this.FullscreenGui)
            this.FullscreenGui.Destroy()
        if IsObject(this.MainGui)
            this.MainGui.Destroy()

        this.MainGui := ""
        this.PicGui := ""
        this.FullscreenGui := ""

        try Hotkey "s", "Off"
    }

    ; 2. LIST & FILTERING
    static PopulateGameList() {
        this.AllGames := []
        for id, game in ConfigManager.Games {
            name     := (Type(game) == "Map") ? game["SavedName"]     : game.SavedName
            launcher := (Type(game) == "Map") ? game["LauncherType"]  : game.LauncherType
            appPath  := (Type(game) == "Map") ? game["ApplicationPath"] : game.ApplicationPath

            isPs3  := InStr(launcher, "RPCS3")   || InStr(appPath, "EBOOT.BIN")
            isPs4  := InStr(launcher, "ShadPS4") || InStr(appPath, "sce_sys")
            if (isPs3 || isPs4) {
                this.AllGames.Push({ Name: name, Id: id, Data: game })
            }
        }
        this.FilterList()
    }

    static FilterList() {
        term := StrLower(this.SearchBox.Value)
        items := []
        for g in this.AllGames {
            if (term == "" || InStr(StrLower(g.Name), term) || InStr(StrLower(g.Id), term))
                items.Push(g.Name)
        }
        this.GameList.Delete()
        this.GameList.Add(items)
    }

    static OnGameSelect() {
        selectedName := this.GameList.Text
        if (selectedName == "")
            return
        for g in this.AllGames {
            if (g.Name == selectedName) {
                this.LoadGameAssets(g.Data)
                return
            }
        }
    }

    static RemoveSelectedGame() {
        selectedName := this.GameList.Text
        if (selectedName == "") {
            DialogsGui.CustomTrayTip("Select a game first.", 2)
            return
        }
        gameId := ""
        for g in this.AllGames {
            if (g.Name == selectedName) {
                gameId := g.Id
                break
            }
        }
        if (gameId == "") {
            DialogsGui.CustomTrayTip("Game not found.", 2)
            return
        }
        if !DialogsGui.AskForConfirmation("Remove Game", "Remove '" selectedName "' from the library?")
            return
        ConfigManager.Games.Delete(gameId)
        ConfigManager.SaveGames()
        this.CurrentGame := {}
        this.CurrentPaths := { Icon0: "", Pic0: "", Pic1: "", Snd0: "", Snd0Wav: "" }
        this.LblPath.Text := "-"
        this.LblIconStatus.Text := "-"
        this.LblSoundStatus.Text := "-"
        this.PicPreview.Value := ""
        this.PopulateGameList()
        DialogsGui.CustomTrayTip("Removed: " selectedName, 2)
    }

    ; 3. BROWSE & ADD
    static ShowAddGameDialog() {
        dlg := Gui("+Owner" this.MainGui.Hwnd " -Caption +Border +AlwaysOnTop +ToolWindow", "Add Game")
        dlg.BackColor := "2A2A2A"
        dlg.SetFont("s12 cSilver", "Segoe UI")
        dW := 640

        titleBar := dlg.Add("Text", "x0 y0 w" (dW - 30) " h28 +0x200 Background333333", "   Nexus :: Add PS3 / PS4 Game")
        titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, dlg.Hwnd))
        dlg.Add("Text", "x+0 yp w30 h28 +0x200 Center Background333333 cRed", "✕").OnEvent("Click", (*) => dlg.Destroy())

        dlg.Add("Text", "x10 y+10 w" (dW - 20), "Select the game root folder (e.g. 'BlazBlue Calamity Trigger')")
        dlg.Add("Text", "x10 y+3 w" (dW - 20), "PS3: GameName\PS3_GAME\USRDIR\EBOOT.BIN")
        dlg.Add("Text", "x10 y+3 w" (dW - 20), "PS4 (ShadPS4): GameName\sce_sys\icon0.png")

        ; Add game folder with explorer like window
        editPath := dlg.Add("Edit", "x10 y+12 w" (dW - 60) " h30 Background333333")

        ; Select a game folder to add
        btnBrw := dlg.Add("Text", "x+5 yp w28 h30 Border +0x200 Center Background333333", "…")
        btnBrw.OnEvent("Click", (*) => (p := DirSelect(, 3, "Select Game Root Folder"), p != "" ? editPath.Value := p : 0))

        dlg.Add("Text", "x10 y+14 w" (dW - 20) " h1 Background333333")
        addFn := (ctrl, *) => (
            folder := Trim(editPath.Value),
            folder != "" && DirExist(folder)
                ? (this.BrowseAndAddGame(folder), dlg.Destroy())
                : DialogsGui.CustomTrayTip("Please enter a valid folder path.", 2)
        )

        ; Add game button
        btnOk := dlg.Add("Button", "x10 y+5 h30 Default Center Background333333", "  Add Game  ")
        btnOk.OnEvent("Click", addFn)

        ; Cancel button
        dlg.Add("Button", "x+8 yp h30 Center Background333333", "  Cancel  ").OnEvent("Click", (*) => dlg.Destroy())
        dlg.OnEvent("Escape", (*) => dlg.Destroy())
        dlg.Show("w" dW)
    }

    static BrowseAndAddGame(folder) {
        if (folder == "" || !DirExist(folder))
            return

        ; Search for EBOOT.BIN (PS3) or sce_sys/eboot.bin (PS4/ShadPS4)
        targetPath := ""
        launcherType := "RPCS3"

        for tryPath in [folder . "\EBOOT.BIN",
                        folder . "\USRDIR\EBOOT.BIN",
                        folder . "\PS3_GAME\USRDIR\EBOOT.BIN",
                        folder . "\PS3_GAME\EBOOT.BIN"] {
            if FileExist(tryPath) {
                targetPath := tryPath
                launcherType := "RPCS3"
                break
            }
        }

        if (targetPath == "") {
            for tryPath in [folder . "\eboot.bin",
                            folder . "\eboot.elf"] {
                if FileExist(tryPath) {
                    targetPath := tryPath
                    launcherType := "ShadPS4"
                    break
                }
            }
        }

        ; ShadPS4 assets-only (no executable in this folder, but sce_sys present)
        if (targetPath == "" && DirExist(folder . "\sce_sys")) {
            targetPath := folder . "\sce_sys\icon0.png"
            launcherType := "ShadPS4"
        }

        if (targetPath == "") {
            DialogsGui.CustomMsgBox("Error",
                "Could not detect a game in this folder.`n`n"
                "PS3: GameName\PS3_GAME\USRDIR\EBOOT.BIN`n"
                "PS4: GameName\eboot.bin  or  GameName\sce_sys\", 0x10)
            return
        }

        safePath := StrReplace(targetPath, "\", "/")

        for id, game in ConfigManager.Games {
            existingPath := (Type(game) == "Map") ? game["ApplicationPath"] : game.ApplicationPath
            if (existingPath == safePath) {
                DialogsGui.CustomTrayTip("Skip, game is already in library.", 1)
                existingName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                this.GameList.Choose(existingName)
                this.OnGameSelect()
                return
            }
        }

        ; Derive a clean game name — skip generic subfolder names
        SplitPath(folder, &folderName, &folderDir)
        while (folderName = "PS3_GAME" || folderName = "USRDIR" || folderName = "sce_sys") {
            folder := folderDir
            SplitPath(folder, &folderName, &folderDir)
        }
        gameName := folderName
        gameId   := (launcherType = "ShadPS4" ? "PS4_" : "GAME_") . StrUpper(StrReplace(gameName, " ", "_"))

        newGame := {
            Id: gameId,
            SavedName: gameName,
            ApplicationPath: safePath,
            LauncherType: launcherType,
            GameApplication: (launcherType = "ShadPS4" ? "eboot.bin" : "EBOOT.BIN"),
            SnapshotDir: "snapshots/" . gameId,
            CaptureDir: "captures/" . gameId,
            EbootIsoPath: safePath,
            TotalPlayTime: 0,
            LastPlayed: "Never",
            IsPatchable: "false",
            PatchGroup: ""
        }

        ConfigManager.Games[gameId] := newGame
        ConfigManager.SaveGames()
        DialogsGui.CustomTrayTip("New game added: " gameName, 2)

        this.PopulateGameList()
        try this.GameList.Choose(gameName)
        this.OnGameSelect()
    }

    ; 4. ASSET LOADING
    static LoadGameAssets(gameData) {
        this.CurrentGame := gameData
        this.StopSound()

        appPath := (Type(gameData) == "Map") ? gameData["ApplicationPath"] : gameData.ApplicationPath
        if (appPath == "")
            return

        appPath := StrReplace(appPath, "/", "\")
        SplitPath(appPath, , &dirOfEboot)      ; e.g. …\PS3_GAME\USRDIR  or …\sce_sys
        SplitPath(dirOfEboot, , &dirOfUsrdir)  ; e.g. …\PS3_GAME         or …\GameName
        SplitPath(dirOfUsrdir, , &dirOfRoot)   ; e.g. …\GameName

        this.LblPath.Text := dirOfEboot

        ; Build candidate paths covering PS3 (RPCS3) and PS4 (ShadPS4) layouts
        searchPaths := [
            dirOfEboot,
            dirOfUsrdir,
            dirOfRoot,
            dirOfUsrdir . "\PS3_GAME",
            dirOfEboot  . "\PS3_GAME",
            ; ShadPS4 — assets live in sce_sys (lowercase names)
            dirOfUsrdir . "\sce_sys",
            dirOfRoot   . "\sce_sys"
        ]
        this.CurrentPaths := { Icon0: "", Pic0: "", Pic1: "", Snd0: "", Snd0Wav: "" }

        for path in searchPaths {
            ; ICON0 — uppercase (PS3) then lowercase (PS4)
            if (this.CurrentPaths.Icon0 == "") {
                for name in ["ICON0.PNG", "icon0.png"] {
                    if FileExist(path . "\" . name) {
                        this.CurrentPaths.Icon0 := path . "\" . name
                        break
                    }
                }
            }
            ; PIC1 / PIC0 — pick best available
            if (this.CurrentPaths.Pic1 == "") {
                for name in ["PIC1.PNG", "pic1.png"] {
                    if FileExist(path . "\" . name) {
                        this.CurrentPaths.Pic1 := path . "\" . name
                        break
                    }
                }
            }
            if (this.CurrentPaths.Pic0 == "") {
                for name in ["PIC0.PNG", "pic0.png"] {
                    if FileExist(path . "\" . name) {
                        this.CurrentPaths.Pic0 := path . "\" . name
                        break
                    }
                }
            }
            ; Sound
            if (this.CurrentPaths.Snd0 == "" && FileExist(path . "\SND0.AT3"))
                this.CurrentPaths.Snd0 := path . "\SND0.AT3"
        }

        if (this.CurrentPaths.Icon0) {
            this.PicPreview.Value := this.CurrentPaths.Icon0
            this.LblIconStatus.Text := this.CurrentPaths.Icon0
        } else {
            this.PicPreview.Value := ""
            this.LblIconStatus.Text := "icon file not found (ICON0.PNG / icon0.png)"
        }

        picLabel := this.CurrentPaths.Pic1 != "" ? this.CurrentPaths.Pic1
                  : this.CurrentPaths.Pic0 != "" ? this.CurrentPaths.Pic0 : ""
        ; LblSoundStatus / BtnCopyPic feedback handled below

        if (this.CurrentPaths.Snd0) {
            this.LblSoundStatus.Text := this.CurrentPaths.Snd0
        } else {
            this.LblSoundStatus.Text := "sound file not found (SND0.AT3 / snd0.at9"
        }
    }

    ; 5. SOUND LOGIC
    static PlaySnd0() {
        if (!this.CurrentPaths.Snd0)
            return

        wavPath := StrReplace(this.CurrentPaths.Snd0, ".AT3", ".wav")
        if (!FileExist(wavPath)) {
            if (!this.ConvertAudio(this.CurrentPaths.Snd0, wavPath))
                return
        }

        if FileExist(wavPath) {
            this.CurrentPaths.Snd0Wav := wavPath
            shouldLoop := this.ChkLoop.Value

            if (shouldLoop) {
                size := FileGetSize(wavPath)
                durationMS := ((size - 44) / 192000) * 1000
                if (durationMS < 1000) durationMS := 1000
                    this.LoopTimerFunc := this.PlayLoop.Bind(wavPath)
                SoundPlay(wavPath)
                SetTimer(this.LoopTimerFunc, durationMS)
                this.LblSoundStatus.Text := "Looping..."
            } else {
                SoundPlay(wavPath)
                this.LblSoundStatus.Text := "Playing..."
            }
            this.BtnStop.Enabled := true
            this.BtnPlay.Enabled := false
        }
    }

    static ConvertAudio(src, dest) {
        this.LblSoundStatus.Text := "Converting ATTRAC..."
        converter := "core\vgmstream-cli.exe"
        if !FileExist(converter) {
            DialogsGui.CustomMsgBox("Error", "Missing core\vgmstream-cli.exe", 0x10)
            return false
        }
        try {
            RunWait(Format('"{1}" "{2}" -o "{3}"', converter, src, dest), , "Hide")
            this.TempWavCreated := true
            return true
        } catch {
            this.LblSoundStatus.Text := "Conversion Failed."
            return false
        }
    }

    static PlayLoop(wavPath) {
        SoundPlay(wavPath)
    }

    static StopSound() {
        if (this.LoopTimerFunc != "") {
            SetTimer(this.LoopTimerFunc, 0)
            this.LoopTimerFunc := ""
        }
        try SoundPlay("NonExistentFile.wav")
        this.LblSoundStatus.Text := "Stopped."
    }

    ; 6. PIC1 & FULLSCREEN
    static ShowPic1Window() {
        ; Prefer PIC1, fall back to PIC0 (ShadPS4)
        imgPath := this.CurrentPaths.Pic1 != "" ? this.CurrentPaths.Pic1
                 : this.CurrentPaths.Pic0 != "" ? this.CurrentPaths.Pic0 : ""
        if (imgPath == "") {
            DialogsGui.CustomTrayTip("No background image found (PIC1.PNG / PIC0.PNG / pic0.png).", 2)
            return
        }
        Logger.Info("ShowPic1Window: opening " imgPath, "IconManagerGui")

        if IsObject(this.PicGui)
            this.PicGui.Destroy()

        picW  := 800
        picH  := 450
        tbarH := 28
        statH := 24

        this.PicGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Background Viewer")
        this.PicGui.BackColor := "1A1A1A"
        this.PicGui.SetFont("s11 cSilver", "Segoe UI")

        ; Custom title bar
        tbar := this.PicGui.Add("Text", "x0 y0 w" (picW - 30) " h" tbarH " +0x200 Background2A2A2A", "  Nexus :: Background Viewer")
        tbar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PicGui.Hwnd))
        this.PicGui.Add("Text", "x+0 yp w30 h" tbarH " +0x200 Center Background2A2A2A cRed", "✕")
            .OnEvent("Click", (*) => (this.PicGui.Destroy(), this.PicGui := ""))

        ; Picture
        this.PicGui.Add("Picture", "x0 y" tbarH " w" picW " h" picH, imgPath)
            .OnEvent("Click", (*) => this.ToggleFullscreen())

        ; Status bar
        this.PicGui.Add("Text", "x0 y" (tbarH + picH) " w" picW " h" statH " +0x200 Center Background2A2A2A",
            "Click image for fullscreen  |  ESC = close  |  S = switch monitor")

        this.PicGui.OnEvent("Escape", (*) => (this.PicGui.Destroy(), this.PicGui := ""))
        this.PicGui.Show("w" picW " h" (tbarH + picH + statH))
    }

    static ToggleFullscreen() {
        if IsObject(this.FullscreenGui) {
            Logger.Info("ToggleFullscreen: closing", "IconManagerGui")
            this.FullscreenGui.Destroy()
            this.FullscreenGui := ""
            return
        }

        imgPath := this.CurrentPaths.Pic1 != "" ? this.CurrentPaths.Pic1
                 : this.CurrentPaths.Pic0 != "" ? this.CurrentPaths.Pic0 : ""
        if (imgPath == "") {
            Logger.Warn("ToggleFullscreen: no image path available", "IconManagerGui")
            return
        }
        Logger.Info("ToggleFullscreen: opening " imgPath, "IconManagerGui")

        this.FullscreenGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "Fullscreen Pic")
        this.FullscreenGui.BackColor := "Black"
        this.FullscreenGui.Add("Picture", "x0 y0", imgPath)
        this.FullscreenGui.OnEvent("Escape", (*) => this.ToggleFullscreen())

        hwnd := this.FullscreenGui.Hwnd
        HotIfWinActive("ahk_id " hwnd)
        Hotkey "s", (*) => this.SwitchMonitor(), "On"
        HotIfWinActive()

        this.CurrentMonitor := 1
        this.SwitchMonitor(true)
        ; Explicitly activate so the S hotkey fires immediately
        WinActivate("ahk_id " hwnd)
        Logger.Info("ToggleFullscreen: registered S hotkey for hwnd=" hwnd, "IconManagerGui")
    }

    static SwitchMonitor(firstRun := false) {
        if (!this.FullscreenGui)
            return
        count := MonitorGetCount()
        if (!firstRun)
            this.CurrentMonitor++
        if (this.CurrentMonitor > count)
            this.CurrentMonitor := 1

        Logger.Info("SwitchMonitor: monitor=" this.CurrentMonitor "/" count " firstRun=" firstRun, "IconManagerGui")
        MonitorGet(this.CurrentMonitor, &L, &T, &R, &B)
        width  := R - L
        height := B - T
        this.FullscreenGui.Show("x" L " y" T " w" width " h" height)
        try {
            picCtrl := this.FullscreenGui["Static1"]
            if picCtrl
                picCtrl.Move(0, 0, width, height)
        }
    }

    ; 7. PS3 MEDIA LIBRARY
    static CopyAsset(type) {
        gameId := (Type(this.CurrentGame) == "Map") ? this.CurrentGame["Id"] : this.CurrentGame.Id
        if (gameId == "" || gameId == "MANUAL") {
            DialogsGui.CustomMsgBox("Error", "Please select a valid saved game first.", 0x10)
            return
        }
        destDir := A_ScriptDir . "\Ps3Media\" . gameId
        if !DirExist(destDir)
            DirCreate(destDir)

        sourcePath := ""
        destFile := ""

        switch type {
            case "ICON0":
                sourcePath := this.CurrentPaths.Icon0
                destFile := "ICON0.PNG"
            case "PIC1":
                sourcePath := this.CurrentPaths.Pic1 != "" ? this.CurrentPaths.Pic1 : this.CurrentPaths.Pic0
                destFile := "PIC1.PNG"
            case "WAV":
                rawWav := StrReplace(this.CurrentPaths.Snd0, ".AT3", ".wav")
                if !FileExist(rawWav) {
                    if (!this.ConvertAudio(this.CurrentPaths.Snd0, rawWav))
                        return
                }
                sourcePath := rawWav
                destFile := "SND0.wav"
        }

        if (sourcePath == "" || !FileExist(sourcePath)) {
            DialogsGui.CustomTrayTip("Error: Source file not found.", 2)
            return
        }

        try {
            FileCopy(sourcePath, destDir . "\" . destFile, 1)
            DialogsGui.CustomTrayTip("Saved: " . destFile . " to library.", 2)
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Copy failed: " . err.Message, 0x10)
        }
    }

    static OpenMediaFolder() {
        gameId := (Type(this.CurrentGame) == "Map") ? this.CurrentGame["Id"] : this.CurrentGame.Id
        destDir := A_ScriptDir . "\Ps3Media\" . gameId

        if DirExist(destDir) {
            Run(destDir)
        } else {
            DialogsGui.CustomTrayTip("Folder not created yet.", 2)
        }
    }
}