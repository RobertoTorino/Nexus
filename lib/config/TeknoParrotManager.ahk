;#Requires AutoHotkey v2.0
;; ==============================================================================
;; * @description Scans TP UserProfiles, parses XMLs, and registers games.
;; * @class TeknoParrotManager
;; * @location lib/config/TeknoParrotManager.ahk
;; * @author Philip
;; * @version 1.2.00
;; ==============================================================================
;
;#Include ..\core\Utilities.ahk
;#Include ..\ui\DialogsGui.ahk
;#Include ConfigManager.ahk
;
;class TeknoParrotManager {
;    static PickerGui := ""
;    static ListView := ""
;    static ProfileMap := Map()
;
;    static EmulatorMap := Map(
;        "Play", "Play.exe", "ElfLdr2", "elfldr2.exe", "Sdaemon", "sdaemon.exe",
;        "TeknoParrot", "TeknoParrot.exe", "ParrotLoader", "parrotloader.exe",
;        "OpenParrot", "OpenParrotLoader.exe", "OpenParrot64", "OpenParrotLoader64.exe",
;        "Lindbergh", "BudgieLoader.exe", "SegaTools", "BudgieLoader.exe",
;        "RingEdge", "BudgieLoader.exe", "TypeX", "game.exe", "Nesica", "game.exe",
;        "RPCS3", "rpcs3.exe", "CrediarDolphin", "DolphinNoGUI.exe", "Dolphin", "Dolphin.exe"
;    )
;
;    static GetPath() {
;        return IniRead(ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath", "")
;    }
;
;    static ShowPicker() {
;        tpPath := this.GetPath()
;
;        if (tpPath == "" || !FileExist(tpPath)) {
;            tpPath := FileSelect(3 + 4096, , "Select TeknoParrotUi.exe", "TeknoParrotUi.exe")
;            if (tpPath == "")
;                return
;            IniWrite(tpPath, ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath")
;        }
;
;        SplitPath(tpPath, , &tpDir)
;        profilesDir := tpDir "\UserProfiles"
;
;        if !DirExist(profilesDir) {
;            DialogsGui.CustomTrayTip("UserProfiles folder not found", 3)
;            return
;        }
;
;        this.ScanProfiles(profilesDir)
;
;        if (this.ProfileMap.Count == 0) {
;            DialogsGui.CustomTrayTip("No XML profiles found", 2)
;            return
;        }
;        this.CreateGui()
;    }
;
;    static ScanProfiles(dir) {
;        this.ProfileMap.Clear()
;        Loop Files, dir "\*.xml" {
;            try {
;                xmlContent := FileRead(A_LoopFileFullPath)
;                title := A_LoopFileName
;                if RegExMatch(xmlContent, "<GameNameInternal>(.*?)</GameNameInternal>", &match)
;                    title := match[1]
;
;                gameExe := ""
;                if RegExMatch(xmlContent, "<ExecutableName>(.*?)</ExecutableName>", &match)
;                    gameExe := match[1]
;
;                emuType := ""
;                if RegExMatch(xmlContent, "<EmulatorType>(.*?)</EmulatorType>", &match)
;                    emuType := match[1]
;
;                if (SubStr(gameExe, -4) = ".zip" || SubStr(gameExe, -4) = ".rar") {
;                    if (this.EmulatorMap.Has(emuType))
;                        gameExe := this.EmulatorMap[emuType]
;                    else if (emuType = "Play")
;                         gameExe := "Play.exe"
;                }
;
;                this.ProfileMap[A_LoopFileName] := {
;                    Title: title, Exe: gameExe, File: A_LoopFileName
;                }
;            }
;        }
;    }
;
;    static CreateGui() {
;        if (this.PickerGui)
;            this.PickerGui.Destroy()
;
;        this.PickerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Select TeknoParrot Profile")
;        this.PickerGui.BackColor := "2A2A2A"
;        this.PickerGui.SetFont("s10 q5 cWhite", "Segoe UI")
;
;        this.PickerGui.Add("Text", "x0 y0 w470 h30 +0x200 Background2A2A2A", "   Select TeknoParrot Profile").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PickerGui.Hwnd))
;        this.PickerGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.PickerGui.Destroy())
;
;        this.ListView := this.PickerGui.Add("ListView", "x10 y+5 w480 h300 -Hdr Background202020 cWhite", ["Game Title", "Profile File"])
;        this.ListView.OnEvent("DoubleClick", this.OnProfileSelected.Bind(this))
;
;        for fileName, data in this.ProfileMap
;            this.ListView.Add(, data.Title, fileName)
;
;        this.ListView.ModifyCol(1, 300)
;        this.ListView.ModifyCol(2, 150)
;
;        this.BtnAddTheme("  Add Profile to Launcher  ", this.OnProfileSelected.Bind(this), "x10 y+10 Background2A2A2A")
;        this.BtnAddTheme("  Cancel  ", (*) => this.PickerGui.Destroy(), "x+10 yp Background2A2A2A")
;        this.PickerGui.Show("w500")
;    }
;
;    static BtnAddTheme(label, callback, options) {
;        btn := this.PickerGui.Add("Text", options " h30 +0x200 +Center +Border", label)
;        btn.OnEvent("Click", callback)
;    }
;
;    static OnProfileSelected(*) {
;        row := this.ListView.GetNext(0, "F")
;        if (row == 0)
;            return
;
;        fileName := this.ListView.GetText(row, 2)
;        data := this.ProfileMap[fileName]
;        this.RegisterTeknoGame(data)
;        this.PickerGui.Destroy()
;    }
;
;    static RegisterTeknoGame(data) {
;        safeTitle := Utilities.SanitizeName(data.Title)
;        safeId := "GAME_TP_" RegExReplace(data.File, "[^A-Za-z0-9]", "_")
;
;        userInput := DialogsGui.AskForString("Add TeknoParrot Game", "Display Name:", safeTitle)
;
;        ; [CRITICAL] Enforce GAME_NAME_STYLE
;        friendlyName := ""
;        if (userInput != "")
;             friendlyName := Utilities.SanitizeName(userInput)
;
;        if (friendlyName == "")
;            friendlyName := safeTitle
;
;        tpPath := this.GetPath()
;
;        newGame := {
;            ApplicationPath: tpPath,
;            GameApplication: "TeknoParrotUi.exe",
;            ExeName: data.Exe,
;            SavedName: friendlyName,
;            LauncherType: "TEKNO",
;            ProfileFile: data.File,
;            Id: safeId
;        }
;
;        ConfigManager.RegisterGame(safeId, newGame)
;        ConfigManager.CurrentGameId := safeId
;        ConfigManager.UpdateLastPlayed(safeId)
;
;        if IsSet(GuiBuilder) {
;            GuiBuilder.RefreshDropdown()
;            DialogsGui.CustomTrayTip("Added: " friendlyName, 1)
;        }
;    }
;}

#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans TP UserProfiles & GameProfiles for viewing/registering.
; * @class TeknoParrotManager
; * @location lib/config/TeknoParrotManager.ahk
; * @author Philip
; * @version 1.2.00 (Added GameProfiles & XML Viewer)
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

    static GetPath() {
        return IniRead(ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath", "")
    }

    static ShowPicker() {
        tpPath := this.GetPath()

        if (tpPath == "" || !FileExist(tpPath)) {
            tpPath := FileSelect(3 + 4096, , "Select TeknoParrotUi.exe", "TeknoParrotUi.exe")
            if (tpPath == "")
                return
            IniWrite(tpPath, ConfigManager.IniPath, "TEKNO_PATH", "TeknoPath")
        }

        SplitPath(tpPath, , &tpDir)

        userDir := tpDir "\UserProfiles"
        systemDir := tpDir "\GameProfiles"

        if !DirExist(userDir) {
            DialogsGui.CustomTrayTip("UserProfiles folder not found", 3)
            return
        }

        ; 1. CLEAR & SCAN BOTH FOLDERS
        this.ProfileMap.Clear()

        ; Scan User Profiles (Runnable)
        this.ScanProfiles(userDir, "User")

        ; Scan Game Profiles (Templates - View Only)
        if DirExist(systemDir)
            this.ScanProfiles(systemDir, "System")

        if (this.ProfileMap.Count == 0) {
            DialogsGui.CustomTrayTip("No XML profiles found", 2)
            return
        }
        this.CreateGui()
    }

    static ScanProfiles(dir, type) {
        Loop Files, dir "\*.xml" {
            try {
                xmlContent := FileRead(A_LoopFileFullPath)
                title := A_LoopFileName

                ; Extract Internal Name
                if RegExMatch(xmlContent, "<GameNameInternal>(.*?)</GameNameInternal>", &match)
                    title := match[1]
                else if RegExMatch(xmlContent, "<GameName>(.*?)</GameName>", &match) ; Fallback for some old templates
                    title := match[1]

                gameExe := ""
                if RegExMatch(xmlContent, "<ExecutableName>(.*?)</ExecutableName>", &match)
                    gameExe := match[1]

                emuType := ""
                if RegExMatch(xmlContent, "<EmulatorType>(.*?)</EmulatorType>", &match)
                    emuType := match[1]

                if (SubStr(gameExe, -4) = ".zip" || SubStr(gameExe, -4) = ".rar") {
                    if (this.EmulatorMap.Has(emuType))
                        gameExe := this.EmulatorMap[emuType]
                    else if (emuType = "Play")
                         gameExe := "Play.exe"
                }

                ; Use Full Path as Key to avoid duplicates if same name exists in both folders
                this.ProfileMap[A_LoopFileFullPath] := {
                    Title: title,
                    Exe: gameExe,
                    File: A_LoopFileName,
                    FullPath: A_LoopFileFullPath,
                    Type: type
                }
            }
        }
    }

    static CreateGui() {
        if (this.PickerGui)
            this.PickerGui.Destroy()

        this.PickerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "TeknoParrot Profile Explorer")
        this.PickerGui.BackColor := "2A2A2A"
        this.PickerGui.SetFont("s10 q5 cWhite", "Segoe UI")

        this.PickerGui.Add("Text", "x0 y0 w680 h30 +0x200 Background2A2A2A", "   TeknoParrot Profile Explorer").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PickerGui.Hwnd))
        this.PickerGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.PickerGui.Destroy())

        ; Added 'Type' Column
        this.ListView := this.PickerGui.Add("ListView", "x10 y+5 w690 h400 -Hdr Background202020 cWhite", ["Game Title", "XML File", "Type"])
        this.ListView.OnEvent("DoubleClick", this.OnProfileSelected.Bind(this))
        this.ListView.OnEvent("ItemSelect", this.OnSelectionChanged.Bind(this))

        ; Populate List
        for path, data in this.ProfileMap {
            row := this.ListView.Add(, data.Title, data.File, data.Type)
            ; Optional: Color code could be added here if using a custom ListView class,
            ; but for standard LV, text is sufficient.
        }

        this.ListView.ModifyCol(1, 350)
        this.ListView.ModifyCol(2, 250)
        this.ListView.ModifyCol(3, 80)

        ; Buttons
        this.BtnAdd := this.BtnAddTheme("  Add to Launcher  ", this.OnProfileSelected.Bind(this), "x10 y+10 Background006600")
        this.BtnView := this.BtnAddTheme("  View XML  ", this.OnViewXml.Bind(this), "x+10 yp Background2A2A2A")
        this.BtnAddTheme("  Close  ", (*) => this.PickerGui.Destroy(), "x+10 yp Background660000")

        this.PickerGui.Show("w710")
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.PickerGui.Add("Text", options " h30 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static OnSelectionChanged(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0) {
            this.BtnAdd.Opt("Background333333 cGray")
            this.BtnAdd.Enabled := false
            return
        }

        type := this.ListView.GetText(row, 3)

        ; Only allow Adding USER profiles (System profiles are just templates)
        if (type == "User") {
            this.BtnAdd.Opt("Background006600 cWhite")
            this.BtnAdd.Enabled := true
        } else {
            this.BtnAdd.Opt("Background333333 cGray")
            this.BtnAdd.Enabled := false
        }
    }

    static OnViewXml(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0)
            return

        ; Find the data object by iterating (since we don't store the key in the row directly)
        ; A cleaner way is using the row number map, but loop is fast enough here.
        targetFile := this.ListView.GetText(row, 2)
        targetType := this.ListView.GetText(row, 3)

        selectedData := ""
        for path, data in this.ProfileMap {
            if (data.File == targetFile && data.Type == targetType) {
                selectedData := data
                break
            }
        }

        if (selectedData) {
            try {
                content := FileRead(selectedData.FullPath)
                DialogsGui.ShowTextViewer(selectedData.Title, content, 600, 500)
            } catch {
                DialogsGui.CustomStatusPop("Error reading file")
            }
        }
    }

    static OnProfileSelected(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0)
            return

        type := this.ListView.GetText(row, 3)
        if (type != "User") {
            DialogsGui.CustomStatusPop("Cannot run System Templates")
            return
        }

        targetFile := this.ListView.GetText(row, 2)

        ; Locate Data
        for path, data in this.ProfileMap {
            if (data.File == targetFile && data.Type == "User") {
                this.RegisterTeknoGame(data)
                this.PickerGui.Destroy()
                return
            }
        }
    }

    static RegisterTeknoGame(data) {
        safeTitle := Utilities.SanitizeName(data.Title)
        safeId := "GAME_TP_" RegExReplace(data.File, "[^A-Za-z0-9]", "_")

        userInput := DialogsGui.AskForString("Add TeknoParrot Game", "Display Name:", safeTitle)

        friendlyName := ""
        if (userInput != "")
             friendlyName := Utilities.SanitizeName(userInput)

        if (friendlyName == "")
            friendlyName := safeTitle

        tpPath := this.GetPath()

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