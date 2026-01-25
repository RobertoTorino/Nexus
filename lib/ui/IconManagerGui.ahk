#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Icon & Sound Manager
; * @class IconManagerGui
; * @location lib/ui/IconManagerGui.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 2.5.0 (Fixes Object/String Crashes)
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
    static CurrentPaths := { Icon0: "", Pic1: "", Snd0: "", Snd0Wav: "" }
    static CurrentMonitor := 1
    static TempWavCreated := false
    static LoopTimerFunc := ""

    ; ==========================================================================
    ; 1. GUI CREATION
    ; ==========================================================================
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Icon Manager")
        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s9 cWhite", "Segoe UI")
        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("Escape", (*) => this.Close())

        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        guiW := 705
        guiH := 550

        ; Title Bar
        title := this.MainGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", "   Nexus :: Icon Manager")
        title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.Close())

        ; Left Column
        this.MainGui.Add("Text", "x10 h24 y+5 Border +0x200 Center", "  Search:  ")
        this.SearchBox := this.MainGui.Add("Edit", "x+5 yp w243 Background333333 cWhite")
        this.SearchBox.OnEvent("Change", (*) => this.FilterList())
        ; List box
        this.GameList := this.MainGui.Add("ListBox", "x10 y+10 w300 h430 Background333333 cWhite", [])
        this.GameList.OnEvent("Change", (*) => this.OnGameSelect())
        this.BtnBrowse := this.MainGui.Add("Button", "x10 y+10 h24 w300 Background333333", "Add New...")
        this.BtnBrowse.OnEvent("Click", (*) => this.BrowseAndAddGame())
        ; Right Column
        xCol2 := 330
        this.LblGameTitle := this.MainGui.Add("Text", "x" xCol2 " y33 w365 h25 +0x200 cAqua", "Select a game...")
        this.MainGui.Add("Text", "x" xCol2 " y+5 w75", "Path:")
        this.LblPath := this.MainGui.Add("Edit", "x" xCol2 " yp+20 w365 h20 ReadOnly Background2A2A2A cGray -Border", "-")

        this.MainGui.Add("Text", "x" xCol2 " y+5 w35", "Icon:")
        this.LblIconStatus := this.MainGui.Add("Text", "x+5 yp w365 cGray", "-")
        this.MainGui.Add("Text", "x" xCol2 " y+5 w35", "Sound:")
        this.LblSoundStatus := this.MainGui.Add("Text", "x+5 yp w365 cGray", "-")

        ; Preview
        this.PicPreview := this.MainGui.Add("Picture", "x" xCol2 " y+10 w365 h176 +Border Background000000", "")
        this.PicPreview.OnEvent("Click", (*) => this.ShowPic1Window())
        this.MainGui.Add("Text", "x" xCol2 " y+5 cGray", "(Click image to view PIC1.PNG background)")

        ; Sound Controls
        ySound := 350
        this.BtnPlay := this.MainGui.Add("Text", "x" xCol2 " y" ySound " h26 Border Center Disabled", "  Play Sound  ")
        this.BtnPlay.OnEvent("Click", (*) => this.PlaySnd0())
        this.BtnStop := this.MainGui.Add("Text", "x+10 yp h26 Border Disabled", "  Stop  ")
        this.BtnStop.OnEvent("Click", (*) => this.StopSound())
        this.ChkLoop := this.MainGui.Add("CheckBox", "x+15 yp+5 cWhite", "Loop Sound")

        ; Management (Ps3Media)
        yAction := 400
        this.MainGui.Add("GroupBox", "x" xCol2 " y" yAction " w450 h130 cWhite", "Ps3Media Library")

        this.BtnCopyIcon := this.MainGui.Add("Button", "xp+10 yp+25 w130 h30 Disabled", "Save Icon0")
        this.BtnCopyIcon.OnEvent("Click", (*) => this.CopyAsset("ICON0"))

        this.BtnCopyPic := this.MainGui.Add("Button", "x+10 yp w130 h30 Disabled", "Save Pic1")
        this.BtnCopyPic.OnEvent("Click", (*) => this.CopyAsset("PIC1"))

        this.BtnCopyWav := this.MainGui.Add("Button", "x" xCol2 + 10 " y+10 w130 h30 Disabled", "Save Audio (.wav)")
        this.BtnCopyWav.OnEvent("Click", (*) => this.CopyAsset("WAV"))

        this.BtnOpenFolder := this.MainGui.Add("Button", "x+10 yp w130 h30", "Open Media Folder")
        this.BtnOpenFolder.OnEvent("Click", (*) => this.OpenMediaFolder())

        this.MainGui.Add("Text", "x" xCol2 + 10 " y+10 w400 cGray", "Library Path: /Ps3Media/<GameID>/")

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

    ; ==========================================================================
    ; 2. LIST & FILTERING
    ; ==========================================================================
    static PopulateGameList() {
        this.AllGames := []
        for id, game in ConfigManager.Games {
            name := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
            launcher := (Type(game) == "Map") ? game["LauncherType"] : game.LauncherType
            appPath := (Type(game) == "Map") ? game["ApplicationPath"] : game.ApplicationPath

            if (InStr(launcher, "RPCS3") || InStr(appPath, "EBOOT.BIN")) {
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

    ; ==========================================================================
    ; 3. BROWSE & ADD
    ; ==========================================================================
    static BrowseAndAddGame() {
        folder := DirSelect(, 3, "Select Game Folder (containing EBOOT.BIN)")
        if (folder == "")
            return

        targetPath := ""
        if FileExist(folder . "\EBOOT.BIN")
            targetPath := folder . "\EBOOT.BIN"
        else if FileExist(folder . "\USRDIR\EBOOT.BIN")
            targetPath := folder . "\USRDIR\EBOOT.BIN"

        if (targetPath == "") {
            DialogsGui.CustomMsgBox("Error", "Could not find EBOOT.BIN in this folder.", 0x10)
            return
        }

        safePath := StrReplace(targetPath, "\", "/")

        for id, game in ConfigManager.Games {
            existingPath := (Type(game) == "Map") ? game["ApplicationPath"] : game.ApplicationPath
            if (existingPath == safePath) {
                DialogsGui.CustomTrayTip("Found: Game is already in library.", 1)
                existingName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                this.GameList.Choose(existingName)
                this.OnGameSelect()
                return
            }
        }

        SplitPath(folder, &folderName)
        gameName := folderName
        gameId := "GAME_" . StrUpper(StrReplace(gameName, " ", "_"))

        newGame := {
            Id: gameId,
            SavedName: gameName,
            ApplicationPath: safePath,
            LauncherType: "RPCS3",
            GameApplication: "EBOOT.BIN",
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
        DialogsGui.CustomTrayTip("New game added to library!", 2)

        this.PopulateGameList()
        try this.GameList.Choose(gameName)
        this.OnGameSelect()
    }

    ; ==========================================================================
    ; 4. ASSET LOADING
    ; ==========================================================================
    static LoadGameAssets(gameData) {
        this.CurrentGame := gameData
        this.StopSound()

        appPath := (Type(gameData) == "Map") ? gameData["ApplicationPath"] : gameData.ApplicationPath
        if (appPath == "")
            return

        appPath := StrReplace(appPath, "/", "\")
        SplitPath(appPath, , &parentDir)
        rootDir := parentDir

        this.LblGameTitle.Text := (Type(gameData) == "Map") ? gameData["SavedName"] : gameData.SavedName
        this.LblPath.Text := rootDir

        searchPaths := [rootDir, rootDir . "\..", rootDir . "\..\PS3_GAME", rootDir . "\PS3_GAME"]
        this.CurrentPaths := { Icon0: "", Pic1: "", Snd0: "" }

        for path in searchPaths {
            if (this.CurrentPaths.Icon0 == "" && FileExist(path . "\ICON0.PNG"))
                this.CurrentPaths.Icon0 := path . "\ICON0.PNG"
            if (this.CurrentPaths.Pic1 == "" && FileExist(path . "\PIC1.PNG"))
                this.CurrentPaths.Pic1 := path . "\PIC1.PNG"
            if (this.CurrentPaths.Snd0 == "" && FileExist(path . "\SND0.AT3"))
                this.CurrentPaths.Snd0 := path . "\SND0.AT3"
        }

        this.BtnCopyIcon.Enabled := false
        this.BtnCopyPic.Enabled := false
        this.BtnCopyWav.Enabled := false

        if (this.CurrentPaths.Icon0) {
            this.PicPreview.Value := this.CurrentPaths.Icon0
            this.LblIconStatus.Text := "" . this.CurrentPaths.Icon0
            this.BtnCopyIcon.Enabled := true
        } else {
            this.PicPreview.Value := ""
            this.LblIconStatus.Text := "ICON0.PNG not found."
        }

        if (this.CurrentPaths.Pic1) {
            this.BtnCopyPic.Enabled := true
        }

        if (this.CurrentPaths.Snd0) {
            this.LblSoundStatus.Text := "Found SND0.AT3"
            this.BtnPlay.Enabled := true
            this.BtnCopyWav.Enabled := true
        } else {
            this.LblSoundStatus.Text := "SND0.AT3 not found."
            this.BtnPlay.Enabled := false
        }
    }

    ; ==========================================================================
    ; 5. SOUND LOGIC
    ; ==========================================================================
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
        this.LblSoundStatus.Text := "Converting AT3..."
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
        this.BtnStop.Enabled := false
        this.BtnPlay.Enabled := (this.CurrentPaths.Snd0 != "")
        this.LblSoundStatus.Text := "Stopped."
    }

    ; ==========================================================================
    ; 6. PIC1 & FULLSCREEN
    ; ==========================================================================
    static ShowPic1Window() {
        if (!this.CurrentPaths.Pic1) {
            DialogsGui.CustomTrayTip("PIC1.PNG not found.", 2)
            return
        }

        ; FIX: Check if Object before destroying
        if IsObject(this.PicGui)
            this.PicGui.Destroy()

        this.PicGui := Gui("+Owner" . this.MainGui.Hwnd . " +AlwaysOnTop", "PIC1 Viewer")
        this.PicGui.BackColor := "Black"
        this.PicGui.SetFont("s10 cWhite", "Segoe UI")

        guiW := 800
        guiH := 450
        this.PicGui.Add("Picture", "x0 y0 w" guiW " h" guiH, this.CurrentPaths.Pic1).OnEvent("Click", (*) => this.ToggleFullscreen())
        this.PicGui.Add("Text", "x10 y" (guiH + 10) " w" guiW " Center", "Click image for Fullscreen (ESC to close, S to switch monitor)")
        this.PicGui.Show("w" guiW " h" (guiH + 40))
    }

    static ToggleFullscreen() {
        ; FIX: Check if Object
        if IsObject(this.FullscreenGui) {
            this.FullscreenGui.Destroy()
            this.FullscreenGui := ""
            return
        }
        this.FullscreenGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "Fullscreen Pic1")
        this.FullscreenGui.BackColor := "Black"
        this.FullscreenGui.Add("Picture", "x0 y0", this.CurrentPaths.Pic1)
        this.FullscreenGui.OnEvent("Escape", (*) => this.ToggleFullscreen())
        HotIfWinActive("ahk_id " . this.FullscreenGui.Hwnd)
        Hotkey "s", (*) => this.SwitchMonitor()
        HotIfWinActive()
        this.SwitchMonitor(true)
    }

    static SwitchMonitor(firstRun := false) {
        if (!this.FullscreenGui)
            return
        count := MonitorGetCount()
        if (!firstRun) {
            this.CurrentMonitor++
        }
        if (this.CurrentMonitor > count) this.CurrentMonitor := 1
            MonitorGet(this.CurrentMonitor, &L, &T, &R, &B)
        width := R - L
        height := B - T
        this.FullscreenGui.Show("x" L " y" T " w" width " h" height)
        try {
            picCtrl := this.FullscreenGui["Static1"]
            if picCtrl
                picCtrl.Move(0, 0, width, height)
        }
    }

    ; ==========================================================================
    ; 7. PS3 MEDIA LIBRARY
    ; ==========================================================================
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
                sourcePath := this.CurrentPaths.Pic1
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