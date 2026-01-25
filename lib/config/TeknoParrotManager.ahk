#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans TP UserProfiles, parses XMLs, and registers games.
; * @class TeknoParrotManager
; * @location lib/config/TeknoParrotManager.ahk
; * @author Philip
; * @version 1.1.05 (INI Auto-Fix & Path Unification)
; ==============================================================================

#Include ..\core\Utilities.ahk
#Include ..\ui\DialogsGui.ahk
#Include ConfigManager.ahk

class TeknoParrotManager {
    static PickerGui := ""
    static ListView := ""
    static ProfileMap := Map()

    ; Mapping XML <EmulatorType> to Real Executables
    static EmulatorMap := Map(
        "Play", "Play.exe", "ElfLdr2", "elfldr2.exe", "Sdaemon", "sdaemon.exe",
        "TeknoParrot", "TeknoParrot.exe", "ParrotLoader", "parrotloader.exe",
        "OpenParrot", "OpenParrotLoader.exe", "OpenParrot64", "OpenParrotLoader64.exe",
        "Lindbergh", "BudgieLoader.exe", "SegaTools", "BudgieLoader.exe",
        "RingEdge", "BudgieLoader.exe", "TypeX", "game.exe", "Nesica", "game.exe",
        "RPCS3", "rpcs3.exe", "CrediarDolphin", "DolphinNoGUI.exe", "Dolphin", "Dolphin.exe"
    )

    ; [CRITICAL] Unified Path Getter with Auto-Fix
    static GetPath() {
        ; Check the standard key
        path := IniRead(ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath", "")

        ; Check the legacy key if standard is missing
        if (path == "" || !FileExist(path)) {
            path := IniRead(ConfigManager.IniPath, "TEKNOPARROT_PATH", "TeknoParrotPath", "")

            ; If we found it in legacy, MIGRATE IT to standard
            if (path != "" && FileExist(path)) {
                IniWrite(path, ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath")
                IniDelete(ConfigManager.IniPath, "TEKNOPARROT_PATH") ; Clean up duplicates
            }
        }
        return path
    }

    static ShowPicker() {
        tpPath := this.GetPath()

        ; 1. Auto-Detect / Ask
        if (tpPath == "" || !FileExist(tpPath)) {
            tpPath := FileSelect(3 + 4096, , "Select TeknoParrotUi.exe", "TeknoParrotUi.exe")
            if (tpPath == "")
                return
            IniWrite(tpPath, ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath")
        }

        SplitPath(tpPath, , &tpDir)
        profilesDir := tpDir "\UserProfiles"

        if !DirExist(profilesDir) {
            DialogsGui.CustomTrayTip("UserProfiles folder not found", 3)
            return
        }

        this.ScanProfiles(profilesDir)

        if (this.ProfileMap.Count == 0) {
            DialogsGui.CustomTrayTip("No XML profiles found", 2)
            return
        }
        this.CreateGui()
    }

    static ScanProfiles(dir) {
        this.ProfileMap.Clear()
        Loop Files, dir "\*.xml" {
            try {
                xmlContent := FileRead(A_LoopFileFullPath)
                title := A_LoopFileName
                if RegExMatch(xmlContent, "<GameNameInternal>(.*?)</GameNameInternal>", &match)
                    title := match[1]

                gameExe := ""
                if RegExMatch(xmlContent, "<ExecutableName>(.*?)</ExecutableName>", &match)
                    gameExe := match[1]

                emuType := ""
                if RegExMatch(xmlContent, "<EmulatorType>(.*?)</EmulatorType>", &match)
                    emuType := match[1]

                ; Resolve Zip/Emulator overrides
                if (SubStr(gameExe, -4) = ".zip" || SubStr(gameExe, -4) = ".rar") {
                    if (this.EmulatorMap.Has(emuType))
                        gameExe := this.EmulatorMap[emuType]
                    else if (emuType = "Play")
                         gameExe := "Play.exe"
                }

                this.ProfileMap[A_LoopFileName] := {
                    Title: title, Exe: gameExe, File: A_LoopFileName
                }
            }
        }
    }

    static CreateGui() {
        if (this.PickerGui)
            this.PickerGui.Destroy()

        this.PickerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Select TeknoParrot Profile")
        this.PickerGui.BackColor := "2A2A2A"
        this.PickerGui.SetFont("s10 q5 cWhite", "Segoe UI")

        this.PickerGui.Add("Text", "x0 y0 w470 h30 +0x200 Background2A2A2A", "   Select TeknoParrot Profile").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PickerGui.Hwnd))
        this.PickerGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.PickerGui.Destroy())

        this.ListView := this.PickerGui.Add("ListView", "x10 y+5 w480 h300 -Hdr Background202020 cWhite", ["Game Title", "Profile File"])
        this.ListView.OnEvent("DoubleClick", this.OnProfileSelected.Bind(this))

        for fileName, data in this.ProfileMap
            this.ListView.Add(, data.Title, fileName)

        this.ListView.ModifyCol(1, 300)
        this.ListView.ModifyCol(2, 150)

        this.BtnAddTheme("  Add Profile to Launcher  ", this.OnProfileSelected.Bind(this), "x10 y+10 Background2A2A2A")
        this.BtnAddTheme("  Cancel  ", (*) => this.PickerGui.Destroy(), "x+10 yp Background2A2A2A")
        this.PickerGui.Show("w500")
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.PickerGui.Add("Text", options " h30 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
    }

    static OnProfileSelected(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0)
            return

        fileName := this.ListView.GetText(row, 2)
        data := this.ProfileMap[fileName]
        this.RegisterTeknoGame(data)
        this.PickerGui.Destroy()
    }

    static RegisterTeknoGame(data) {
        safeTitle := Utilities.SanitizeName(data.Title)
        safeId := "GAME_TP_" RegExReplace(data.File, "[^A-Za-z0-9]", "_")

        friendlyName := DialogsGui.AskForString("Add TeknoParrot Game", "Display Name:", safeTitle)
        if (friendlyName == "")
            friendlyName := safeTitle

        tpPath := this.GetPath() ; Use unified getter

        newGame := {
            ApplicationPath: tpPath,
            GameApplication: "TeknoParrotUi.exe",
            ExeName: data.Exe,
            SavedName: friendlyName,
            LauncherType: "TEKNO",
            ProfileFile: data.File,
            Id: safeId
        }

        ConfigManager.RegisterGame(safeId, newGame)
        ConfigManager.CurrentGameId := safeId
        ConfigManager.UpdateLastPlayed(safeId)

        if IsSet(GuiBuilder) {
            GuiBuilder.RefreshDropdown()
            DialogsGui.CustomTrayTip("Added: " friendlyName, 1)
        }
    }
}