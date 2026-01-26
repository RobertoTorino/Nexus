#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans TP UserProfiles & GameProfiles (XML + JSON Metadata)
; * @class TeknoParrotManager
; * @location lib/config/TeknoParrotManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

#Include ..\core\Utilities.ahk
#Include ..\ui\DialogsGui.ahk
#Include ..\core\Logger.ahk
#Include ConfigManager.ahk

class TeknoParrotManager {
    static PickerGui := ""
    static ListView := ""
    static IconCtrl := ""
    static ProfileMap := Map()
    static TpRootDir := ""

    ; Header Buttons
    static BtnAdd := ""
    static BtnView := ""
    static BtnClose := ""

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

        Logger.Info("TP Manager: Opening Picker. TP Path: " tpPath)
        SplitPath(tpPath, , &tpDir)
        this.TpRootDir := tpDir

        userDir := tpDir "\UserProfiles"
        systemDir := tpDir "\GameProfiles"

        if !DirExist(userDir) {
            Logger.Error("TP Manager: UserProfiles folder missing at " userDir)
            DialogsGui.CustomTrayTip("UserProfiles folder not found", 3)
            return
        }

        this.ProfileMap.Clear()
        this.UserCount := 0
        this.SystemCount := 0

        Logger.Info("TP Manager: Scanning User Profiles...")
        this.ScanProfiles(userDir, "User")

        if DirExist(systemDir) {
            Logger.Info("TP Manager: Scanning System Profiles...")
            this.ScanProfiles(systemDir, "System")
        }

        Logger.Info("TP Manager: Scan Complete. Found " this.UserCount " User, " this.SystemCount " System.")

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

                iconRelPath := ""

                if (type == "System") {
                    jsonName := StrReplace(A_LoopFileName, ".xml", ".json")
                    jsonPath := this.TpRootDir . "\Metadata\" . jsonName
                    if FileExist(jsonPath) {
                        try {
                            jsonContent := FileRead(jsonPath)
                            if RegExMatch(jsonContent, 'i)"icon_name"\s*:\s*"(.*?)"', &match) {
                                iconRelPath := "Icons\" . match[1]
                                ; Logger.Debug("TP Manager: Found Metadata JSON for " title)
                            }
                        }
                    }
                }

                if (iconRelPath == "") {
                    if RegExMatch(xmlContent, "i)<IconName>\s*(.*?)\s*</IconName>", &match)
                        iconRelPath := Trim(match[1])
                }

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

        this.PickerGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "TeknoParrot Profile Explorer")
        this.PickerGui.BackColor := "2A2A2A"
        this.PickerGui.SetFont("s10 q5 cWhite", "Segoe UI")

        headerText := "   TeknoParrot Profiles  (User: " this.UserCount " / System: " this.SystemCount ")"

        ; HEADER BAR (850w)
        this.PickerGui.Add("Text", "x0 y0 w760 h30 +0x200 Background2A2A2A", headerText).OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.PickerGui.Hwnd))

        ; Header Icons [Add] [View] [Close]
        this.BtnAdd := this.AddNavBtn(" ➕ ", this.OnProfileSelected.Bind(this), "x+0 yp Background333333") ; Starts Gray
        this.BtnView := this.AddNavBtn(" 📄 ", this.OnViewXml.Bind(this), "x+0 yp Background333333")
        this.BtnClose := this.AddNavBtn(" ❌ ", (*) => this.PickerGui.Destroy(), "x+0 yp Background2A2A2A cRed")

        ; ListView
        this.ListView := this.PickerGui.Add("ListView", "x10 y+5 w600 h450 -Hdr Background202020 cWhite", ["Game Title", "XML File", "Type"])
        this.ListView.OnEvent("DoubleClick", this.OnProfileSelected.Bind(this))
        this.ListView.OnEvent("ItemSelect", this.OnSelectionChanged.Bind(this))

        ; Icon Preview
        this.IconCtrl := this.PickerGui.Add("Picture", "x630 y50 w180 h180 +BackgroundTrans -Border vIconPreview +0x40", "")

        for path, data in this.ProfileMap {
            this.ListView.Add(, data.Title, data.File, data.Type)
        }

        this.ListView.ModifyCol(1, 300)
        this.ListView.ModifyCol(2, 220)
        this.ListView.ModifyCol(3, 75)

        this.PickerGui.Show("w850")
    }

    static AddNavBtn(label, callback, options) {
        btn := this.PickerGui.Add("Text", options " w30 h30 +0x200 +Center", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static OnSelectionChanged(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0) {
            this.BtnAdd.Opt("Background333333")
            this.IconCtrl.Value := ""
            return
        }

        targetFile := this.ListView.GetText(row, 2)
        type := this.ListView.GetText(row, 3)

        ; Update Add Button State
        if (type == "User") {
            this.BtnAdd.Opt("Background006600") ; Green for Go
        } else {
            this.BtnAdd.Opt("Background333333") ; Gray for No-Go
        }

        selectedData := ""
        for path, data in this.ProfileMap {
            if (data.File == targetFile && data.Type == type) {
                selectedData := data
                break
            }
        }

        if (selectedData && selectedData.IconPath != "") {
            cleanRel := StrReplace(selectedData.IconPath, "/", "\")
            fullIconPath := this.TpRootDir . "\" . cleanRel

            if !FileExist(fullIconPath) {
                SplitPath(cleanRel, &fName)
                fullIconPath := this.TpRootDir . "\Icons\" . fName
            }

            try {
                if FileExist(fullIconPath) {
                    this.IconCtrl.Value := fullIconPath
                    Logger.Debug("TP Manager: Previewing Icon -> " fullIconPath)
                } else {
                    this.IconCtrl.Value := ""
                    Logger.Debug("TP Manager: Icon missing on disk -> " fullIconPath)
                }
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
            } catch as err {
                Logger.Error("TP Manager: Failed to read XML " err.Message)
                DialogsGui.CustomStatusPop("Error reading file")
            }
        }
    }

    static OnProfileSelected(*) {
        row := this.ListView.GetNext(0, "F")
        if (row == 0)
            return

        type := this.ListView.GetText(row, 3)

        ; Block action if it's a System profile
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
        Logger.Info("TP Manager: Starting registration for " data.Title)

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

        Logger.Info("TP Manager: Successfully registered " safeId)

        if IsSet(GuiBuilder) {
            GuiBuilder.RefreshDropdown()
            DialogsGui.CustomTrayTip("Added: " friendlyName, 1)
        }
    }
}