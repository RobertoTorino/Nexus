#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Common popup dialogs (MsgBox, InputBox, Text Viewer).
; * @class DialogsGui
; * @location lib/ui/DialogsGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class DialogsGui {

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

    ; Fixes "Expected 1-2 parameters, but got 3" error in GuiBuilder
    ; Maps the generic .Show() call to your specific .CustomMsgBox()
    static Show(text, title := "Nexus", options := 0) {
        return this.CustomMsgBox(title, text, options)
    }

    ; Fixes "Class might not have member 'AskForConfirmation'"
    static AskForConfirmation(text, title := "Confirm Action") {
        ; Option 4 triggers the Yes/No buttons in your CustomMsgBox logic
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
        ; Background2A2A2A = Slightly lighter than bg
        ; -E0x200 = Removes 3D sunken edge for flat look
        ; +Border = Adds simple 1px border
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

    ; AskForChoice: Modern Button Stack (The "GameSearch" Style)
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
            ; Uses the helper to create a flat clickable text box
            this._AddFlatButton(myGui, opt, "x35 " yPos " w" (guiW - 70) " h40", (ctrl, *) => (result := ctrl.Text, myGui.Destroy()))
            yPos := "y+10"
        }

        ; Cancel Link (Subtle style for Cancel)
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

        ; Content
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
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, myGui.Hwnd)) ; WM_NCLBUTTONDOWN

        ; Custom Close Button (X)
        BtnClose := myGui.Add("Text", "x" (w - 32) " y10 w24 h24 +0x200 +Center BackgroundTrans cRed", "✕")
        BtnClose.OnEvent("Click", (*) => myGui.Destroy())

        return myGui
    }

    ; HELPER: Adds a Flat "Button" (Text Control)
    static _AddFlatButton(guiObj, text, options, callback) {
        ; 1. Create the Text Control
        ; Background2A2A2A = Dark Grey (Normal State)
        ; +0x200 = Centers text vertically inside the control
        guiObj.SetFont("s10 Norm cWhite")
        btn := guiObj.Add("Text", options " +0x200 Center Background2A2A2A", text)

        ; 2. Bind the Click Event
        btn.OnEvent("Click", callback)

        ; REMOVED: btn.OnEvent("MouseMove"...) -> This caused the crash.
        ; AHK v2 Text controls do not natively support MouseMove events
        ; without complex OnMessage(0x200) handling.

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

    ; CustomStatusPop: Small, Dark, Non-blocking notification with Fade
    static CustomStatusPop(text, duration := 2000) {
        ; 1. Create the Pop
        pop := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
        pop.BackColor := "202020"
        pop.SetFont("s10 q5 cSilver", "Segoe UI")
        pop.Add("Text", "x15 y5 Center +200", text)

        ; 2. Show it (Start fully opaque)
        pop.Show("xCenter yCenter NoActivate")

        ; 3. Schedule the Fade (Wait 'duration', then start fading)
        SetTimer(() => this._FadeAndDestroy(pop), -duration)
    }

    static _FadeAndDestroy(guiObj) {
        try {
            ; Simple loop to drop transparency from 255 (solid) to 0 (invisible)
            ; Doing this in steps of 15 is fast enough to look smooth but slow enough to be seen
            loop 17 {
                trans := 255 - (A_Index * 15)
                WinSetTransparent(Max(0, trans), "ahk_id " guiObj.Hwnd)
                Sleep(10) ; 10ms is the "sweet spot" for 60fps animations
            }
            guiObj.Destroy()
        } catch {
            ; If the user closed the app or window manually, just ensure it's gone
            try guiObj.Destroy()
        }
    }
}