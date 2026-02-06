#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Visual Controller Diagnostics (Zero-Impact when closed).
; * @class GamepadTester
; * @location lib/input/GamepadTester.ahk
; * @author Philip
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class GamepadTester {
    static ActiveID := 1
    static Main := ""
    static TimerObj := ""

    ; Visual Control Storage
    static Controls := Map()
    static Sticks := Map() ; Specific storage for moving sticks

    ; --- CONFIGURATION ---
    static ColorBg      := "1A1A1A"
    static ColorPanel   := "2A2A2A"
    static ColorBtn     := "333333"
    static ColorActive  := "05FBE4" ; Nexus Blue
    static ColorText    := "Silver"

    static Show() {
        if (this.Main)
            return

        ; 1. Create Window
        this.Main := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus Gamepad Tester")
        this.Main.BackColor := this.ColorBg
        this.Main.SetFont("s12 c" this.ColorText, "Segoe UI")
        this.Main.OnEvent("Close", (*) => this.Close())
        this.Main.OnEvent("Escape", (*) => this.Close())

        ; 2. Header (Left Aligned, Custom Close)
        this.Main.Add("Text", "x0 y0 w605 h35 Background" this.ColorPanel) ; Header BG
        Header := this.Main.Add("Text", "x10 y0 w605 h35 +0x200 BackgroundTrans", "Nexus :: Controller Diagnostics")
        Header.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.Main.Hwnd)) ; Drag logic

        BtnClose := this.Main.Add("Text", "x570 y0 w35 h35 +0x200 Center BackgroundTrans cRed", "✕")
        BtnClose.OnEvent("Click", (*) => this.Close())

        ; 3. ID Selector (Dark UX Cycler)
        this.Main.Add("Text", "x10 y50 cGray", "Controller ID:")
        this.IdDisplay := this.Main.Add("Text", "x+10 yp w40 +0x200 Center c" this.ColorActive " Border", "[ " this.ActiveID " ]")
        this.IdDisplay.OnEvent("Click", (*) => this.CycleId())

        ; --- VISUAL LAYOUT (DualShock 4 / XInput Style) ---

        ; TOUCHPAD (Top Center)
        this.AddBtn("Touchpad", "x130 y60 w160 h40", "Touchpad", 15) ; Often unmapped on PC, but placeholder exists

        ; TRIGGERS & SHOULDERS
        this.AddBtn("L2", "x30 y90 w60 h20", "L2", "Axis_Z_Pos")  ; Triggers are often Z-Axis
        this.AddBtn("R2", "x330 y90 w60 h20", "R2", "Axis_Z_Neg")
        this.AddBtn("L1", "x30 y115 w60 h20", "L1", 5)
        this.AddBtn("R1", "x330 y115 w60 h20", "R1", 6)

        ; CENTER OPTIONS
        this.AddBtn("Back",  "x140 y115 w60 h20", "SHARE", 7)
        this.AddBtn("Start", "x220 y115 w60 h20", "OPT", 8)

        ; D-PAD (POV Hat)
        this.AddBtn("Up",    "x80 y145 w30 h30", "▲", "POV_0")
        this.AddBtn("Left",  "x50 y175 w30 h30", "◀", "POV_27000")
        this.AddBtn("Right", "x110 y175 w30 h30", "▶", "POV_9000")
        this.AddBtn("Down",  "x80 y205 w30 h30", "▼", "POV_18000")

        ; FACE BUTTONS (XInput Standard: A=1, B=2, X=3, Y=4)
        this.AddBtn("Y", "x310 y145 w30 h30", "△", 4)
        this.AddBtn("X", "x280 y175 w30 h30", "□", 3)
        this.AddBtn("B", "x340 y175 w30 h30", "○", 2)
        this.AddBtn("A", "x310 y205 w30 h30", "✕", 1)

        ; --- ANALOG STICKS (Moving UI) ---
        ; Left Stick Container
        this.Main.Add("Text", "x130 y180 w60 h60 Border Background050505")
        this.Sticks["L"] := this.Main.Add("Text", "x145 y195 w30 h30 Center +0x200 Background" this.ColorBtn " +0x200", "L3")

        ; Right Stick Container
        this.Main.Add("Text", "x230 y180 w60 h60 Border Background050505")
        this.Sticks["R"] := this.Main.Add("Text", "x245 y195 w30 h30 Center +0x200 Background" this.ColorBtn " +0x200", "R3")

        ; L3/R3 Buttons (Clicking the stick)
        this.Controls["L3"] := {Ctrl: this.Sticks["L"], ID: 9, Active: false}
        this.Controls["R3"] := {Ctrl: this.Sticks["R"], ID: 10, Active: false}

        ; 4. Footer Status (Left Aligned)
        this.Main.Add("Text", "x0 y260 w420 h30 Background" this.ColorPanel) ; Footer BG
        this.Status := this.Main.Add("Text", "x10 y260 w400 h30 +0x200 BackgroundTrans cGray", "Waiting for input...")

        this.Main.Show("w605 h290")

        ; 5. Register for Snapping (Magnet Logic)
        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(this.Main.Hwnd)

        ; 6. Start Loop
        this.TimerObj := ObjBindMethod(this, "Update")
        SetTimer(this.TimerObj, 20)
    }

    static Close() {
        if (this.TimerObj)
            SetTimer(this.TimerObj, 0)

        this.TimerObj := ""
        if (this.Main)
            this.Main.Destroy()
        this.Main := ""
        this.Controls.Clear()
        this.Sticks.Clear()
    }

    static CycleId() {
        this.ActiveID++
        if (this.ActiveID > 4)
            this.ActiveID := 1
        this.IdDisplay.Value := "[ " this.ActiveID " ]"
    }

    static AddBtn(keyName, coords, text, inputId) {
        ctrl := this.Main.Add("Text", coords " Center +0x200 Border Background" this.ColorBtn, text)
        this.Controls[keyName] := {Ctrl: ctrl, ID: inputId, Active: false}
    }

    static Update() {
        if (!this.Main)
            return

        idPrefix := this.ActiveID "Joy"
        anyPressed := false

        ; --- 1. AXIS HANDLING (Sticks & Triggers) ---
        ; Reading Axes: 0 to 100. Center is approx 50.
        x_axis := GetKeyState(idPrefix "X")
        y_axis := GetKeyState(idPrefix "Y")
        u_axis := GetKeyState(idPrefix "U") ; Often Right Stick X (or Z)
        r_axis := GetKeyState(idPrefix "R") ; Often Right Stick Y

        ; Move Left Stick Visual (Range 130-190, Center 160)
        ; Offset calculation: (Axis - 50) * Scale
        l_x_off := (x_axis - 50) * 0.5
        l_y_off := (y_axis - 50) * 0.5
        try this.Sticks["L"].Move(145 + l_x_off, 195 + l_y_off)

        ; Move Right Stick Visual
        r_x_off := (u_axis - 50) * 0.5
        r_y_off := (r_axis - 50) * 0.5
        try this.Sticks["R"].Move(245 + r_x_off, 195 + r_y_off)

        ; Z-Axis for Triggers (XInput puts both triggers on one axis usually, or separate)
        z_axis := GetKeyState(idPrefix "Z")

        ; --- 2. BUTTON/POV HANDLING ---
        pov := GetKeyState(idPrefix "POV")

        for key, data in this.Controls {
            isActive := false

            if IsInteger(data.ID) {
                ; Standard Buttons
                isActive := GetKeyState(idPrefix . data.ID)
            }
            else if InStr(data.ID, "POV_") {
                ; POV Hat
                targetAngle := Integer(StrReplace(data.ID, "POV_", ""))
                isActive := (pov == targetAngle)
            }
            else if (data.ID == "Axis_Z_Pos") {
                ; L2 Trigger (approximated on Z axis < 10 or > 90 depending on driver)
                ; In many XInput setups, Z is 50, L2 goes to 100, R2 goes to 0 (or vice versa)
                ; We'll treat standard XInput behavior:
                isActive := (z_axis > 60)
            }
            else if (data.ID == "Axis_Z_Neg") {
                ; R2 Trigger
                isActive := (z_axis < 40)
            }

            ; Visual Toggle (Efficient)
            if (isActive != data.Active) {
                data.Active := isActive
                if (isActive) {
                    data.Ctrl.Opt("Background" this.ColorActive)
                    data.Ctrl.SetFont("cBlack Bold")
                    this.Status.Value := "Detected: " key
                } else {
                    data.Ctrl.Opt("Background" this.ColorBtn)
                    data.Ctrl.SetFont("c" this.ColorText " Norm")
                }
            }
            if (isActive)
                anyPressed := true
        }

        if (!anyPressed) {
            ; Show raw axis data for debugging if nothing is pressed
            this.Status.Value := Format("L:[{:0.0f},{:0.0f}]  R:[{:0.0f},{:0.0f}]  Z:{:0.0f}", x_axis, y_axis, u_axis, r_axis, z_axis)
        }
    }
}