#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans TP UserProfiles & GameProfiles for viewing/registering.
; * @class TeknoParrotManager
; * @location lib/config/TeknoParrotManager.ahk
; * @author Philip
; * @version 1.2.02 (Added Icon Preview)
; ==============================================================================

#Include ..\core\Utilities.ahk
#Include ..\ui\DialogsGui.ahk
#Include ConfigManager.ahk

class TeknoParrotManager {
    static PickerGui := ""
    static ListView := ""
    static IconCtrl := ""
    static ProfileMap := Map()
    static TpRootDir := "" ; Stores the TP Root for icon resolution

    static UserCount := 0
    static SystemCount := 0

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
        this.TpRootDir := tpDir ; Save root for icon path building

        userDir := tpDir "\UserProfiles"
        systemDir := tpDir "\GameProfiles"

        if !DirExist(userDir) {
            DialogsGui.CustomTrayTip("UserProfiles folder not found", 3)
            return
        }

        this.ProfileMap.Clear()
        this.UserCount := 0
        this.SystemCount := 0

        this.ScanProfiles(userDir, "User")

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

                if RegExMatch(xmlContent, "<GameNameInternal>(.*?)</GameNameInternal>", &match)
                    title := match[1]
                else if RegExMatch(xmlContent, "<GameName>(.*?)</GameName>", &match)
                    title := match[1]

                gameExe := ""
                if RegExMatch(xmlContent, "<ExecutableName>(.*?)</ExecutableName>", &match)
                    gameExe := match[1]

                emuType := ""
                if RegExMatch(xmlContent, "<EmulatorType>(.*?)</EmulatorType>", &match)
                    emuType := match[1]

                ; [NEW] Capture Icon Path
                iconRelPath := ""
                if RegExMatch(xmlContent, "i)<IconName>\s*(.*?)\s*</IconName>", &match)
                    iconRelPath := match[1]

                if (SubStr(gameExe, -4) = ".zip" || SubStr(gameExe, -4) = ".rar") {
                    if (this.EmulatorMap.Has(emuType))
                        gameExe := this.EmulatorMap[emuType]
                    else if (emuType = "Play")
                         gameExe := "Play.exe"
                }

                this.ProfileMap[A_LoopFileFullPath] := {
                    Title: title,
                    Exe: gameExe,
                    File: A_LoopFileName,
                    FullPath: A_LoopFileFullPath,
                    Type: type,
                    IconPath: iconRelPath
                }

                if (type == "User")
                    this.UserCount++
                else
                    this.SystemCount++
            }
        }
    }

    static CreateGui() {
        if (this.PickerGui)
            this.PickerGui.Destroy()

        ; Made the GUI wider to accommodate the image preview (w920)
        this.PickerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "TeknoParrot Profile Explorer")
        this.PickerGui.BackColor := "2A2A2A"
        this.PickerGui.SetFont("s10 q5 cWhite", "Segoe UI")

        headerText := "   TeknoParrot Profiles  (User: " this.UserCount " / System: " this.SystemCount ")"

        this.PickerGui.Add("Text", "x0 y0 w900 h30 +0x200 Background2A2A2A", headerText).OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PickerGui.Hwnd))
        this.PickerGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.PickerGui.Destroy())

        ; ListView
        this.ListView := this.PickerGui.Add("ListView", "x10 y+5 w690 h400 -Hdr Background202020 cWhite", ["Game Title", "XML File", "Type"])
        this.ListView.OnEvent("DoubleClick", this.OnProfileSelected.Bind(this))
        this.ListView.OnEvent("ItemSelect", this.OnSelectionChanged.Bind(this))

        ; Image Preview Box (Right Side)

        ; [Image of Game Icon]

        this.PickerGui.SetFont("s9 cSilver")
        this.PickerGui.Add("GroupBox", "x+10 yp w200 h220", " Icon Preview ")

        ; The Picture Control (Starts empty)
        this.IconCtrl := this.PickerGui.Add("Picture", "xp+10 yp+20 w180 h180 +Background202020 +Border vIconPreview", "")

        for path, data in this.ProfileMap {
            this.ListView.Add(, data.Title, data.File, data.Type)
        }

        this.ListView.ModifyCol(1, 350)
        this.ListView.ModifyCol(2, 250)
        this.ListView.ModifyCol(3, 80)

        this.BtnAdd := this.BtnAddTheme("  Add to Launcher  ", this.OnProfileSelected.Bind(this), "x10 y+10 Background006600")
        this.BtnView := this.BtnAddTheme("  View XML  ", this.OnViewXml.Bind(this), "x+10 yp Background2A2A2A")
        this.BtnAddTheme("  Close  ", (*) => this.PickerGui.Destroy(), "x+10 yp Background660000")

        this.PickerGui.Show("w930")
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
            this.IconCtrl.Value := "" ; Clear Image
            return
        }

        ; 1. Handle Buttons
        type := this.ListView.GetText(row, 3)
        if (type == "User") {
            this.BtnAdd.Opt("Background006600 cWhite")
            this.BtnAdd.Enabled := true
        } else {
            this.BtnAdd.Opt("Background333333 cGray")
            this.BtnAdd.Enabled := false
        }

        ; 2. Handle Image Loading (Lazy Load)
        targetFile := this.ListView.GetText(row, 2)

        selectedData := ""
        for path, data in this.ProfileMap {
            if (data.File == targetFile && data.Type == type) {
                selectedData := data
                break
            }
        }

        if (selectedData && selectedData.IconPath != "") {
            ; Construct Full Path: TP_ROOT + Icons/Name.png
            cleanRel := StrReplace(selectedData.IconPath, "/", "\")
            fullIconPath := this.TpRootDir . "\" . cleanRel

            try {
                if FileExist(fullIconPath)
                    this.IconCtrl.Value := fullIconPath
                else
                    this.IconCtrl.Value := "" ; File listed in XML but missing on disk
            } catch {
                this.IconCtrl.Value := ""
            }
        } else {
            this.IconCtrl.Value := ""
        }
    }

    static OnViewXml(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0)
            return

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