#Requires AutoHotkey v2.0
; ==============================================================================
; * @description PS5 Linux image helper tool (WSL build guide + Balena launcher).
; * @class Ps5LinuxImageTool
; * @location lib/tools/Ps5LinuxImageTool.ahk
; * @author Philip
; * @date 2026/07/08
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class Ps5LinuxImageTool {
    static T(text) => TranslationManager.T(text)

    static Show() {
        g := Gui("+AlwaysOnTop -Caption +Border +Owner" . (IsSet(GuiBuilder) ? GuiBuilder.MainGui.Hwnd : ""), this.T("BUILD PS5 LINUX IMAGE"))
        g.BackColor := "101010"
        g.SetFont("s10 cWhite", "Segoe UI")

        g.Add("Text", "x20 y15 w390 h24 +0x200", this.T("BUILD PS5 LINUX IMAGE"))

        g.SetFont("s11 Bold cA0A0A0", "Segoe UI")
        helpBtn := g.Add("Text", "x+5 yp w24 h24 +0x200 +Center +Border Background1A1A1A", "?")
        helpBtn.OnEvent("Click", (*) => this.ShowHelp())

        g.SetFont("s9 cGray", "Segoe UI")
        g.Add("Text", "x20 y+8 w420 h44", this.T("Build PS5 Linux image subtitle"))

        g.SetFont("s10 cWhite", "Segoe UI")
        g.Add("Text", "x20 y+8 w240 h30 +0x200 +Center +Border Background202020", this.T("Open Balena Etcher"))
            .OnEvent("Click", (*) => this.OpenBalenaEtcher())

        g.Add("Text", "x+10 yp w170 h30 +0x200 +Center +Border Background202020", this.T("Open Build Guide"))
            .OnEvent("Click", (*) => this.ShowHelp())

        g.Add("Text", "x20 y+12 w420 h26 +0x200 +Center cGray", this.T("Close"))
            .OnEvent("Click", (*) => g.Destroy())

        g.Show("w460 h185")
    }

    static OpenBalenaEtcher() {
        try {
            Run("balenaEtcher.exe")
            return
        } catch {
        }

        try {
            Run("https://etcher.balena.io/")
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Could not open Balena Etcher:`n" . err.Message, 0x10)
        }
    }

    static ShowHelp() {
        helpText := this.T("HELP_TEXT_PS5_LINUX_IMAGE")
        DialogsGui.ShowTextViewer("Nexus :: BUILD PS5 LINUX IMAGE :: Help", helpText, 650, 500)
    }
}
