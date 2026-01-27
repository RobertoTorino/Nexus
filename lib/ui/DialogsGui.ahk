#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Common popup dialogs (MsgBox, InputBox, Text Viewer).
; * @class DialogsGui
; * @location lib/ui/DialogsGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

class DialogsGui {

    ; [FIX] Define the property so 'this.PopGui' works
    static PopGui := ""

    ; CustomMsgBox: Modern, Borderless, Dark
    static CustomMsgBox(title, text, options := 0) {
        Result := "Cancel"
        guiW := 400

        ; Create Base Modern GUI
        myGui := this._CreateModernGui(title, guiW)

        ; Body Text
        myGui.SetFont("s10 Norm")
        myGui.Add("Text", "x20 y50 w" (guiW - 40) " +Wrap BackgroundTrans", text)

        ; Buttons (Modern Flat Style)
        yPos := "y+25"

        ; Check if bit 2 is set (Value 4 = Yes/No)
        if (options & 4) {
            ; Yes Button
            this._AddFlatButton(myGui, "Yes", "x80 " yPos " w100 h35", (*) => (Result := "Yes", myGui.Destroy()))
            ; No Button
            this._AddFlatButton(myGui, "No", "x+20 yp w100 h35", (*) => (Result := "No", myGui.Destroy()))
        } else {
            ; OK Button
            this._AddFlatButton(myGui, "OK", "x150 " yPos " w100 h35", (*) => (Result := "OK", myGui.Destroy()))
        }

        ; Spacer at bottom
        myGui.Add("Text", "x0 y+20 w1 h1 BackgroundTrans", "")

        myGui.Show("w" guiW " Center")
        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    ; --- COMPATIBILITY FIXES ---

    static Show(text, title := "Nexus", options := 0) {
        return this.CustomMsgBox(title, text, options)
    }

    static AskForConfirmation(text, title := "Confirm Action") {
        result := this.CustomMsgBox(title, text, 4)
        return (result == "Yes")
    }

    ; AskForString: Modern Input Box
    static AskForString(title, prompt, defaultText := "") {
        Result := ""
        guiW := 400

        myGui := this._CreateModernGui(title, guiW)

        ; Prompt
        myGui.SetFont("s10 Norm")
        myGui.Add("Text", "x20 y50 w" (guiW - 40) " +Wrap BackgroundTrans", prompt)

        ; Edit Box (Styled Dark & Flat)
        edt := myGui.Add("Edit", "x20 y+15 w" (guiW - 40) " h30 cWhite Background2A2A2A -E0x200 +Border", defaultText)

        ; Buttons
        yPos := "y+20"
        this._AddFlatButton(myGui, "OK", "x80 " yPos " w100 h35", (*) => (Result := edt.Value, myGui.Destroy()))
        this._AddFlatButton(myGui, "Cancel", "x+20 yp w100 h35", (*) => (Result := "", myGui.Destroy()))

        ; Bottom Spacer
        myGui.Add("Text", "x0 y+20 w1 h1 BackgroundTrans", "")

        myGui.Show("w" guiW " Center")
        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    ; AskForChoice: Modern Button Stack
    static AskForChoice(title, prompt, options) {
        result := ""
        guiW := 350

        myGui := this._CreateModernGui(title, guiW)

        ; Prompt
        myGui.SetFont("s10 Norm")
        myGui.Add("Text", "x20 y50 w" (guiW - 40) " Center BackgroundTrans", prompt)

        ; Option Buttons (Stacked)
        yPos := "y+20"
        for opt in options {
            this._AddFlatButton(myGui, opt, "x35 " yPos " w" (guiW - 70) " h40", (ctrl, *) => (result := ctrl.Text, myGui.Destroy()))
            yPos := "y+10"
        }

        ; Cancel Link
        myGui.SetFont("s9 c999999 Underline")
        cancelBtn := myGui.Add("Text", "x35 y+15 w" (guiW - 70) " h20 Center BackgroundTrans", "Cancel")
        cancelBtn.OnEvent("Click", (*) => (result := "", myGui.Destroy()))

        ; Spacer
        myGui.Add("Text", "x0 y+15 w1 h1 BackgroundTrans", "")

        myGui.Show("w" guiW " Center")
        WinWaitClose("ahk_id " myGui.Hwnd)
        return result
    }

    ; ShowTextViewer: Modern, Read-Only
    static ShowTextViewer(title, content, w := 600, h := 600) {
        viewer := this._CreateModernGui(title, w)
        viewer.SetFont("s10 Norm")
        viewer.Add("Text", "x12 y50 w" (w - 24) " h" (h - 60) " BackgroundTrans", content)
        viewer.Show("w" w " h" h)
    }

    ; HELPER: Creates the "Superslick" Base GUI
    static _CreateModernGui(title, w) {
        myGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner +Border", title)
        myGui.BackColor := "202020" ; Very Dark Grey
        myGui.SetFont("s10 cWhite", "Segoe UI")

        ; Custom Header (Draggable)
        hdr := myGui.Add("Text", "x12 y10 w" (w - 40) " h24 +0x200 BackgroundTrans", title)
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, myGui.Hwnd))

        ; Custom Close Button (X)
        BtnClose := myGui.Add("Text", "x" (w - 32) " y10 w24 h24 +0x200 +Center BackgroundTrans cRed", "✕")
        BtnClose.OnEvent("Click", (*) => myGui.Destroy())

        return myGui
    }

    ; HELPER: Adds a Flat "Button" (Text Control)
    static _AddFlatButton(guiObj, text, options, callback) {
        guiObj.SetFont("s10 Norm cWhite")
        btn := guiObj.Add("Text", options " +0x200 Center Background2A2A2A", text)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; UTILS
    static CustomTrayTip(text, iconType := 1) {
        try {
            TrayTip(text, "Nexus", (iconType == 2 ? 2 : 1))
            SetTimer(() => TrayTip(), -3000)
        }
    }

    static ShowAbout() {
        this.CustomMsgBox("About", "NEXUS`nVersion: Phase 2.1`n`n© " A_YYYY, 0)
    }

    ; --- [UPDATED] Smart Centering Status Popup ---
    static CustomStatusPop(text, duration := 2000) {
        ; 1. Reuse existing GUI to prevent stacking
        if (this.PopGui)
            this.PopGui.Destroy()

        ; 2. Create modern popup
        this.PopGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
        this.PopGui.BackColor := "202020"
        this.PopGui.SetFont("s11 c05FBE4", "Segoe UI") ; Cyan text for visibility
        this.PopGui.Add("Text", "x15 y10 Center", text)

        ; 3. Calculate Size (Hidden)
        this.PopGui.Show("NoActivate AutoSize Hide")

        ; 4. SMART CENTERING LOGIC
        ; Try to find the Main Window to center against
        targetHwnd := WinExist("Nexus Main Window") ; Or use your window title

        ; If we have access to the Global GuiBuilder, use that HWND (Most reliable)
        if IsSet(GuiBuilder) && GuiBuilder.MainGui
            targetHwnd := GuiBuilder.MainGui.Hwnd

        if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            WinGetPos(&mX, &mY, &mW, &mH, "ahk_id " . targetHwnd)
            WinGetPos(,, &pW, &pH, this.PopGui.Hwnd)

            ; Math: Center = MainX + (MainWidth/2) - (PopupWidth/2)
            finalX := mX + (mW / 2) - (pW / 2)
            finalY := mY + (mH / 2) - (pH / 2)

            this.PopGui.Show("x" . finalX . " y" . finalY . " NoActivate")
        } else {
            ; Fallback: Center on Screen
            this.PopGui.Show("Center NoActivate")
        }

        ; 5. Auto-Destroy
        SetTimer(() => (this.PopGui ? this.PopGui.Destroy() : ""), -duration)
    }

    ; Legacy fade helper (kept if needed, but unused by new popup for snappiness)
    static _FadeAndDestroy(guiObj) {
        try guiObj.Destroy()
    }
}