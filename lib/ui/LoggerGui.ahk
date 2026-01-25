#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Show lags (tail).
; * @class LoggerGui
; * @location lib/ui/LoggerGui.ahk
; * @author Philip
; * @date 2026/01/12
; * @version 1.0.00
; ======================================================================

; --- DEPENDENCY IMPORTS ---
; None

class LoggerGui {
    static MainGui := ""
    static LogBox := ""
    static IsActive := false
    static Buffer := []      ; Memory buffer for log lines
    static MaxLines := 200     ; Keeps memory usage low

    static Show() {
        if (this.MainGui) {
            this.IsActive := true
            this.MainGui.Show("NoActivate")
            ; Explicitly bind the timer to the static method
            SetTimer(this.FlushBuffer.Bind(this), 250)
            return
        }

        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus Console")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "1A1A1A"

        ; Title Bar
        this.MainGui.SetFont("s9 cSilver", "Segoe UI")
        this.MainGui.Add("Text", "x0 y0 w775 h25 +0x200 Background2A2A2A", "  Nexus :: System Log").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        this.MainGui.Add("Text", "x775 y0 w30 h25 +0x200 Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.Hide())

        ; The Log Box: -Wrap and -VScroll makes it faster, but we'll keep VScroll for usability.
        ; Using an Edit control is significantly lighter on CPU than a ListView.
        this.MainGui.SetFont("s9 cLime", "Consolas")
        this.LogBox := this.MainGui.Add("Edit", "x5 y30 h360 w785 -VScroll -HScroll +ReadOnly -E0x200 Background1A1A1A")

        this.IsActive := true
        this.MainGui.Show("w805 h350 x0 y0 NoActivate") ; Docked to top-left by default

        ; Start the timer
        SetTimer(this.FlushBuffer.Bind(this), 250)

        ; Test line to verify it works immediately
        this.Log("Visual Console Initialized", "SYSTEM")
    }

    static Hide() {
        this.IsActive := false
        if (this.MainGui)
            this.MainGui.Hide()
    }

    ; ---- PERFORMANCE LOGGING: Pushes to memory only ----
    static Log(msg, level := "INFO") {
        if (!this.IsActive)
            return

        timestamp := FormatTime(, "HH:mm:ss")
        this.Buffer.Push("[" . timestamp . "] [" . level . "] " . msg . "`r`n")

        ; Safety: if buffer gets too huge, force a flush
        if (this.Buffer.Length > 50)
            this.FlushBuffer()
    }

    ; ---- THROTTLED UPDATE: Only hits the GUI every 250ms ----
    static FlushBuffer() {
        ; Performance Guard: check if anything is actually in the buffer
        if (!this.IsActive || this.Buffer.Length == 0)
            return

        combinedText := ""
        while (this.Buffer.Length > 0)
            combinedText .= this.Buffer.RemoveAt(1)

        try {
            ; Direct Windows Message to append text (Zero-latency)
            SendMessage(0x00B1, -1, -1, this.LogBox.Hwnd)
            SendMessage(0x00C2, 0, StrPtr(combinedText), this.LogBox.Hwnd)
        }
    }
}