#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Dedicated Interface for managing game patches/modes.
; * @class PatchManagerGui
; * @location lib/ui/PatchManagerGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ======================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\tools\PatchServiceTool.ahk
#Include ..\config\ConfigManager.ahk
#Include ..\ui\DialogsGui.ahk

class PatchManagerGui {
    static MainGui := ""
    static Rows := Map()

    static Show() {
        ; SINGLETON CHECK (Matches LoggerGui)
        ; If GUI exists, just show it and refresh data.
        if (this.MainGui) {
            this.MainGui.Show()
            this.RefreshAllRows()
            return
        }

        ; CREATE GUI (Matches LoggerGui Style: No +Owner)
        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Patch Manager")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s12 cWhite", "Segoe UI")

        ; Prevent Escape/Close from Destroying the window
        this.MainGui.OnEvent("Close", (*) => this.Hide())
        this.MainGui.OnEvent("Escape", (*) => this.Hide())

        guiW := 805
        guiH := 300

        ; Custom Title Bar
        title := this.MainGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", "  Nexus :: Patch Manager")
        title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        ; CLOSE BUTTON CALLS HIDE (Matches LoggerGui)
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.Hide())

        ; --- HEADER ---
        this.MainGui.SetFont("s12 Bold")
        this.MainGui.Add("Text", "x10 y30 w400 h30 Background2A2A2A", "Supported Patches")
        this.MainGui.SetFont("s12 Norm")

        ; --- HEADERS ROW ---
        y := 60
        this.AddHeader(10, y, 120, "Patch Name")
        this.AddHeader(140, y, 150, "Linked Game (Library)")
        this.AddHeader(300, y, 120, "Integrity")
        this.AddHeader(500, y, 120, "Current Mode")
        this.AddHeader(660, y, 120, "Actions")

        ; --- DYNAMIC ROWS ---
        y += 30

        gameList := this.GetGameList()

        for key, patchData in PatchServiceTool.KnownPatches {
            this.RenderRow(y, key, patchData, gameList)
            y += 40
        }

        this.MainGui.Show("w" guiW " h" guiH)
    }

    ; --- HIDE LOGIC (Crucial for Singleton) ---
    static Hide() {
        if (this.MainGui)
            this.MainGui.Hide()
    }

    ; --- REFRESH LOGIC ---
    static RefreshAllRows() {
        for patchKey, row in this.Rows {
            savedId := IniRead(ConfigManager.IniPath, "PATCH_MAPPINGS", patchKey, "")
            if (savedId != "")
                this.RefreshRow(patchKey, savedId)
        }
    }

    static RenderRow(y, patchKey, patchData, gameList) {
        row := {}

        ; PATCH NAME
        this.MainGui.Add("Text", "x10 y" y + 3 " w120 h20 +0x200 Background2A2A2A", patchData.Name)

        ; DROPDOWN
        savedId := IniRead(ConfigManager.IniPath, "PATCH_MAPPINGS", patchKey, "")

        row.DD := this.MainGui.Add("DropDownList", "x+10 y" y " w150 Choose1", gameList.Names)
        row.DD.OnEvent("Change", this.MakeCallback(patchKey, "OnGameSelect"))

        if (savedId != "" && gameList.IdMap.Has(savedId)) {
            try row.DD.Text := gameList.IdMap[savedId]
        }

        ; STATUS
        row.Integrity := this.MainGui.Add("Text", "x+10 y" y + 3 " w190 h20 +0x200 cGray Background2A2A2A", "-")
        row.Mode := this.MainGui.Add("Text", "x+10 y" y + 3 " w150 h20 +0x200 cGray Background2A2A2A", "-")

        ; BUTTONS
        row.BtnApply := this.MainGui.Add("Button", "x+10 y" y - 1 " h26 Disabled", "Patch")
        row.BtnApply.OnEvent("Click", this.MakeCallback(patchKey, "OnApply"))

        row.BtnLaunch := this.MainGui.Add("Button", "x+10 yp h26 Disabled", "▶️")
        row.BtnLaunch.OnEvent("Click", this.MakeCallback(patchKey, "OnLaunch"))

        this.Rows[patchKey] := row

        if (savedId != "") {
            this.RefreshRow(patchKey, savedId)
        }
    }

    static RefreshRow(patchKey, gameId) {
        if (!this.Rows.Has(patchKey))
            return

        row := this.Rows[patchKey]
        game := ConfigManager.Games.Has(gameId) ? ConfigManager.Games[gameId] : ""

        if (!IsObject(game)) {
            row.Integrity.Text := "Game Not Found"
            row.Mode.Text := "-"
            row.BtnApply.Enabled := false
            row.BtnLaunch.Enabled := false
            return
        }

        patchData := PatchServiceTool.KnownPatches[patchKey]
        diag := PatchServiceTool.RunDiagnostics(game, patchData)

        row.Integrity.Text := diag.Integrity
        row.Mode.Text := diag.CurrentState

        row.Integrity.Opt(InStr(diag.Integrity, "Verified") ? "cLime" : "cRed")
        row.Mode.Opt(InStr(diag.CurrentState, "Unknown") ? "cRed" : "cAqua")

        row.BtnApply.Enabled := true
        row.BtnLaunch.Enabled := true

        IniWrite(gameId, ConfigManager.IniPath, "PATCH_MAPPINGS", patchKey)
    }

    static HandleEvent(patchKey, eventType, ctrl) {
        if (eventType == "OnGameSelect") {
            selectedName := ctrl.Text
            if (selectedName == "- Select Game -")
                return

            foundId := ""
            for id, game in ConfigManager.Games {
                name := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                if (name == selectedName) {
                    foundId := id
                    break
                }
            }
            if (foundId != "")
                this.RefreshRow(patchKey, foundId)
        }
        else if (eventType == "OnApply") {
            gameId := IniRead(ConfigManager.IniPath, "PATCH_MAPPINGS", patchKey, "")
            if (gameId != "") {
                game := ConfigManager.Games[gameId]
                PatchServiceTool.OpenPatcher(game, patchKey)
                this.RefreshRow(patchKey, gameId)
            }
        }
        else if (eventType == "OnLaunch") {
            gameId := IniRead(ConfigManager.IniPath, "PATCH_MAPPINGS", patchKey, "")
            if (gameId != "") {
                ConfigManager.CurrentGameId := gameId
                StartGame()
                this.Hide()
            }
        }
    }

    static MakeCallback(patchKey, eventType) {
        return (ctrl, *) => this.HandleEvent(patchKey, eventType, ctrl)
    }

    static GetGameList() {
        names := ["- Select Game -"]
        idMap := Map()

        for id, game in ConfigManager.Games {
            name := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
            names.Push(name)
            idMap[id] := name
        }
        return { Names: names, IdMap: idMap }
    }

    static AddHeader(x, y, w, text) {
        this.MainGui.SetFont("s12 cGray")
        this.MainGui.Add("Text", "x" x " y" y " w" w " h20 Background2A2A2A", text)
        this.MainGui.SetFont("s12 cWhite")
    }
}