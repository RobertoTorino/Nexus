#Requires AutoHotkey v2.0
; ==============================================================================
; * @description GUI for Game Management Tools (Cloning, etc.)
; * @class CloneGameWizardGui
; * @location lib/ui/CloneGameWizardGui.ahk
; * @author Philip
; * @date 2026/01/10
; * @version 1.0.01
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\tools\CloneWizardTool.ahk
#Include DialogsGui.ahk

class CloneGameWizardGui {
    static MainGui := ""

    static EdtSource := ""
    static EdtName := ""
    static EdtNewId := ""
    static TxtSize := ""
    static TxtInfo := ""

    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Clone Wizard")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 q5 cWhite", "Segoe UI")
        this.MainGui.OnEvent("Close", (*) => this.Destroy())
        ; Get rid of the ugly blue focus color
        this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")

        w := 500

        ; Title Bar
        this.MainGui.Add("Text", "x0 y0 w" (w - 60) " h30 +0x200 Background2A2A2A", "     Nexus :: Clone Game Wizard")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.BtnAddTheme("  ?  ", (*) => this.ShowHelp(), "x+0 yp w30 h30 -Border")
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
            .OnEvent("Click", (*) => this.Destroy())

        ; Source
        this.MainGui.Add("Text", "x20 y40", "Original EBOOT.BIN Source:")
        this.EdtSource := this.MainGui.Add("Edit", "x20 y+5 w390 h26 ReadOnly Background2A2A2A cSilver", "Select EBOOT.BIN...")
        this.BtnAddTheme("  Browse  ", (*) => this.SelectSource(), "x+10 h26 yp")

        ; Info
        this.MainGui.Add("Text", "x20 y+15", "Folder Size:")
        this.TxtSize := this.MainGui.Add("Text", "x+10 yp w200 cYellow", "---")

        this.MainGui.Add("Text", "x20 y+15", "Original ID:")
        this.TxtInfo := this.MainGui.Add("Text", "x+10 yp w200 cSilver", "---")

        ; Target (Auto-Calculated)
        this.MainGui.Add("Text", "x20 y+20", "Next Available ID (Auto):")
        ; ReadOnly to enforce Strict Logic
        this.EdtNewId := this.MainGui.Add("Edit", "x20 y+5 w150 h26 Background222222 cLime Center ReadOnly", "---")

        ; Friendly Name (Required for Registry)
        this.MainGui.Add("Text", "x+20 yp-22", "New Game Name (Required):")
        this.EdtName := this.MainGui.Add("Edit", "xp y+5 w290 h26 Background111111 cWhite", "")
        this.EdtName.OnEvent("Change", (*) => 0) ; Dummy event to keep focus logic happy

        ; Clone Button
        this.BtnAddTheme("CLONE GAME NOW", (*) => this.RunClone(), "x20 y+20 w460 h30 Background222222")

        this.MainGui.Show("w" w " h290")
    }

    static Destroy() {
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := ""
    }

    static SelectSource() {
        path := FileSelect(3, , "Select Original EBOOT (SCEEXE000)", "EBOOT.BIN (*.BIN)")
        if (path == "")
            return

        this.EdtSource.Value := path

        SplitPath(path, , &usrDir)
        SplitPath(usrDir, , &gameDir)
        SplitPath(gameDir, &gameId)

        this.TxtInfo.Text := gameId
        this.TxtSize.Text := "Calculating..."

        ; Async Calculation
        SetTimer(() => this.Analyze(gameDir, gameId), -10)
    }

    static Analyze(gameDir, oldId) {
        ; 1. Size
        sizeStr := CloneWizardTool.GetFolderSize(gameDir)
        this.TxtSize.Text := sizeStr

        ; 2. Strict ID Generation
        nextId := CloneWizardTool.GetNextFreeId()

        if (nextId == "FULL") {
            DialogsGui.CustomMsgBox("Error", "No free IDs available (001-999 exhausted).")
            this.EdtNewId.Value := "ERROR"
        } else {
            this.EdtNewId.Value := nextId
            this.EdtName.Focus() ; Jump to Name field
        }
    }

    static RunClone() {
        src := this.EdtSource.Value
        newId := this.EdtNewId.Value
        newName := this.EdtName.Value

        ; Validation check if we are actually using a special build path
        fighterPath := IniRead(ConfigManager.IniPath, "RPCS3_FIGHTER", "Rpcs3FighterPath", "")
        shooterPath := IniRead(ConfigManager.IniPath, "RPCS3_SHOOTER", "Rpcs3ShooterPath", "")
        tcrsPath := IniRead(ConfigManager.IniPath, "RPCS3_TCRS", "Rpcs3TcrsPath", "")

        isSpecial := false
        ;        for p in [fighterPath, shooterPath, tcrsPath] {
        ;            if (p != "" && InStr(this.EdtSource.Value, StrReplace(p, "\rpcs3.exe", ""))) {
        ;                isSpecial := true
        ;                break
        ;            }
        ;        }
        ;
        ;        if !isSpecial {
        ;            DialogsGui.CustomMsgBox("Restriction", "The Clone Wizard can only be used for games installed within the RPCS3_FIGHTER, RPCS3_SHOOTER, or RPCS3_TCRS build folders.")
        ;            return
        ;        }

        if (src == "" || InStr(src, "Select a file")) {
            DialogsGui.CustomMsgBox("Error", "Please select a source game first.")
            return
        }
        if (newName == "") {
            DialogsGui.CustomMsgBox("Error", "You must provide a Name for the new game.`n(e.g. 'Tekken 6 CN')")
            return
        }
        if (newId == "---" || newId == "ERROR") {
            DialogsGui.CustomMsgBox("Error", "Invalid Target ID.")
            return
        }

        ; Confirm Action
        confirm := DialogsGui.CustomMsgBox("Confirm Clone",
            "Source: " src "`nTarget ID: " newId "`nNew Name: " newName "`nSize: " this.TxtSize.Text "`n`nProceed?", 4)

        if (confirm != "Yes")
            return

        DialogsGui.CustomTrayTip("Cloning started... This may take a while.", 5)

        ; Pass Name to Patcher so it can register it
        newPath := CloneWizardTool.CloneGame(src, newId, newName, true)

        if (newPath) {
            DialogsGui.CustomMsgBox("Success", "Game Cloned & Registered!`n`nID: " newId "`nName: " newName)
            this.Destroy()
        } else {
            DialogsGui.CustomMsgBox("Error", "Cloning Failed. Check logs.")
        }
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " +0x200 +Center +Border cWhite", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; HELP MENU
    static ShowHelp() {
        helpText := "
             (
         1. ADDING GAME PATHS:
             1. Click the "Clone Wizard" button.
             2. Click Browse -> Select SCEEXE000 Eboot.
             3. The Wizard instantly calculates: "Folder Size: 1450 MB"
             4. The Wizard automatically fills: "Target ID: SCEEXE001".
             5. Click Clone.
             6. Done!

         2. PROCESS INFO:
             - The Game ID is Read Only.
             - SCEEXE000 is reserved and can never be used.
             - Available ID range is from 001 until 999.
             - Pre-checks for available disk space before the operation.
             - CRC Validation for the EBOOT.BIN.
             - After "Clone" SCEEXE001+<GAME_NAME> is saved.
             - Used ID's can only be used again if removed from the config.
         )"
        DialogsGui.ShowTextViewer("Nexus - Clone Wizard", helpText, 450, 350)
    }
}