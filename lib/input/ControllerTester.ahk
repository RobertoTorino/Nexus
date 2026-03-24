#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Visual Controller Diagnostics (Zero-Impact when closed).
; * @class ControllerTester
; * @location lib/input/ControllerTester.ahk
; * @author Philip
; * @version 1.0.00
; ==============================================================================

#Include ..\core\Logger.ahk
#Include ..\ui\WindowManagerGui.ahk
#Include ..\ui\DialogsGui.ahk

class ControllerTester {
    static ActiveID := 1
    static Main := ""
    static TimerObj := ""
    static ButtonLabels := Map()
    static AxisLabels := Map()
    static PrevStates := Map()

    static Show() {
        if (IsObject(this.Main)) {
            this.Main.Destroy()
            this.Main := ""
        }

        this.Main := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus Matrix Scanner")
        this.Main.BackColor := "101010"
        this.Main.SetFont("s10 cSilver", "Segoe UI")
        this.Main.OnEvent("Escape", (*) => this.Close())

        ; --- SNAPPING LOGIC ---
        if HasProp(WindowManagerGui, "RegisterForSnapping")
            WindowManagerGui.RegisterForSnapping(this.Main.Hwnd)

        ; --- HEADER ---
        this.Main.Add("Text", "x0 y0 w450 h35 Background202020")

        ; Title (Width adjusted to fit both buttons)
        this.Main.Add("Text", "x15 y0 w345 h35 +0x200 BackgroundTrans", "Nexus :: GamePad Tester")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.Main.Hwnd))

        ; Top-RIGHT Help Button (?)
        this.Main.SetFont("s14 cSilver Bold")
        this.Main.Add("Text", "x380 y0 w35 h35 +0x200 Center BackgroundTrans", "?")
            .OnEvent("Click", (*) => this.ShowHelp())

        ; Top-RIGHT Red Cross (X)
        this.Main.SetFont("s14 cRed Norm")
        this.Main.Add("Text", "x415 y0 w35 h35 +0x200 Center BackgroundTrans", "✕")
            .OnEvent("Click", (*) => this.Close())

        this.Main.SetFont("s10 cSilver") ; Reset Font

        ; ID Selector
        this.Main.Add("Text", "x15 y45 cGray", "Controller ID:")
        this.Main.SetFont("c00FFFF")
        this.IdDisplay := this.Main.Add("Text", "x+10 yp-5 w50 h30 +0x200 Center Border", "[ " this.ActiveID " ]")
        this.IdDisplay.OnEvent("Click", (*) => this.CycleId())
        this.Main.SetFont("cSilver")

        ; --- THE MATRIX (Buttons 1-16) ---
        this.Main.Add("Text", "x15 y85 w420 h1 0x10")

        yPos := 100
        xPos := 20
        Loop 16 {
            this.ButtonLabels[A_Index] := this.Main.Add("Text", "x" xPos " y" yPos " w40 h30 Center +0x200 Border Background333333 cGray", A_Index)
            this.PrevStates[A_Index] := false
            xPos += 50
            if (Mod(A_Index, 8) == 0) {
                xPos := 20
                yPos += 40
            }
        }

        ; --- AXES ---
        yPos += 20
        axes := ["X", "Y", "Z", "R", "POV"]
        xPos := 20
        for ax in axes {
            this.Main.Add("Text", "x" xPos " y" yPos " w30 Center cGray", ax)
            this.Main.SetFont("cLime")
            this.AxisLabels[ax] := this.Main.Add("Text", "x" xPos " y" (yPos+20) " w50 h20 Center Border", "0")
            this.Main.SetFont("cSilver")
            xPos += 60
        }

        this.Main.Show("w450 h" (yPos + 60))

        this.TimerObj := (*) => this.Update()
        SetTimer(this.TimerObj, 20)
    }

    static Close() {
        if (this.TimerObj && HasMethod(this.TimerObj)) {
            try SetTimer(this.TimerObj, 0)
        }
        this.TimerObj := ""

        if (IsObject(this.Main)) {
            this.Main.Destroy()
        }
        this.Main := ""
        this.ButtonLabels.Clear()
        this.AxisLabels.Clear()
        this.PrevStates.Clear()
    }

    static CycleId() {
        this.ActiveID := (this.ActiveID >= 4) ? 1 : this.ActiveID + 1
        this.IdDisplay.Value := "[ " this.ActiveID " ]"
    }

    static ShowHelp() {
        helpKey := "HELP_TEXT_GAMEPAD"

        ; 1. Fetch text from your TranslationManager
        helpText := ""
        if IsSet(TranslationManager)
            helpText := TranslationManager.T(helpKey)

        ; Fallback just in case the key is missing from the translation file
        if (helpText == "" || helpText == helpKey) {
            helpText := "Axis Help Translation Missing.`nPlease add '" helpKey "' to your language file."
        }

        ; 2. Show the Viewer (using a smaller, tighter window size suitable for this text)
        if IsSet(DialogsGui)
            DialogsGui.ShowTextViewer("GamePad Tester :: Help", helpText, 400, 450)
    }

    static Update() {
        if (!IsObject(this.Main))
            return

        id := this.ActiveID "Joy"

        ; Check Buttons 1-16
        Loop 16 {
            isDown := GetKeyState(id . A_Index)
            wasDown := this.PrevStates.Has(A_Index) ? this.PrevStates[A_Index] : false

            if (isDown) {
                if (!wasDown) {
                    Logger.Info("GamePad Tester: Button [" A_Index "] pressed.", "ControllerTester")
                    this.PrevStates[A_Index] := true
                }

                try this.ButtonLabels[A_Index].Opt("Background00AAAA")
                try this.ButtonLabels[A_Index].SetFont("cWhite Bold")
            } else {
                this.PrevStates[A_Index] := false

                try this.ButtonLabels[A_Index].Opt("Background333333")
                try this.ButtonLabels[A_Index].SetFont("cGray Norm")
            }
        }

        ; Check Axes
        x := GetKeyState(id "X"), y := GetKeyState(id "Y")
        z := GetKeyState(id "Z"), r := GetKeyState(id "R")
        pov := GetKeyState(id "POV")

        try this.AxisLabels["X"].Value := Format("{:0.0f}", x)
        try this.AxisLabels["Y"].Value := Format("{:0.0f}", y)
        try this.AxisLabels["Z"].Value := Format("{:0.0f}", z)
        try this.AxisLabels["R"].Value := Format("{:0.0f}", r)
        try this.AxisLabels["POV"].Value := pov
    }
}