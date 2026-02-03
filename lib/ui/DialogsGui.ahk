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

    static PopGui := ""

    ; MAIN DIALOGS

    static CustomMsgBox(title, message, timeout := 0, options := 0) {
        Result := "Cancel"
        guiW := 450

        ; Create Base Window
        myGui := this._CreateModernGui(title, guiW)
        myGui.SetFont("s10 cWhite", "Segoe UI") ; Forced White Text

        ; --- CONTENT AREA ---
        myGui.Add("Text", "x20 y55 w" (guiW - 40) " Wrap BackgroundTrans", message)

        ; --- BUTTON ROW ---
        yPos := "y+25"

        ; COPY BUTTON (Bottom Left)
        this._AddFlatButton(myGui, "📋 Copy", "x20 " yPos " w100 h35", (*) => (
            A_Clipboard := message,
            this.CustomTrayTip("Copied to Clipboard", 1)
        ))

        ; ACTION BUTTONS (Bottom Right)
        if (options == 4) { ; Yes / No
            this._AddFlatButton(myGui, "No", "x330 yp w100 h35", (*) => (Result := "No", myGui.Destroy()))
            this._AddFlatButton(myGui, "Yes", "x220 yp w100 h35", (*) => (Result := "Yes", myGui.Destroy()))
        }
        else if (options == 1) { ; OK / Cancel
            this._AddFlatButton(myGui, "Cancel", "x330 yp w100 h35", (*) => (Result := "Cancel", myGui.Destroy()))
            this._AddFlatButton(myGui, "OK", "x220 yp w100 h35", (*) => (Result := "OK", myGui.Destroy()))
        }
        else { ; Default: OK Only
            this._AddFlatButton(myGui, "OK", "x330 yp w100 h35", (*) => (Result := "OK", myGui.Destroy()))
        }

        myGui.Add("Text", "x0 y+20 w1 h1", "")

        this._ShowCentered(myGui, guiW)

        if (timeout > 0)
            SetTimer(() => myGui.Destroy(), -timeout * 1000)

        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    static AskForString(title, prompt, defaultText := "") {
        Result := ""
        guiW := 450

        myGui := this._CreateModernGui(title, guiW)
        myGui.SetFont("s10 cWhite", "Segoe UI")
        myGui.Add("Text", "x20 y55 w" (guiW - 40) " +Wrap BackgroundTrans", prompt)

        myGui.SetFont("s11 cWhite")
        edt := myGui.Add("Edit", "x20 y+15 w" (guiW - 40) " h30 Background333333 -E0x200 +Border cWhite", defaultText)

        yPos := "y+25"
        this._AddFlatButton(myGui, "OK", "x110 " yPos " w100 h35", (*) => (Result := edt.Value, myGui.Destroy()))
        this._AddFlatButton(myGui, "Cancel", "x+10 yp w100 h35", (*) => (Result := "", myGui.Destroy()))

        myGui.Add("Text", "x0 y+20 w1 h1", "")

        this._ShowCentered(myGui, guiW)
        try ControlFocus(edt)

        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    static AskForChoice(title, prompt, options) {
        Result := ""
        guiW := 350

        myGui := this._CreateModernGui(title, guiW)
        myGui.SetFont("s10 cWhite", "Segoe UI")
        myGui.Add("Text", "x20 y55 w" (guiW - 40) " Center BackgroundTrans", prompt)

        yPos := "y+20"
        for opt in options {
            this._AddFlatButton(myGui, opt, "x35 " yPos " w" (guiW - 70) " h40", (ctrl, *) => (Result := ctrl.Text, myGui.Destroy()))
            yPos := "y+10"
        }

        myGui.SetFont("s9 cGray Underline")
        lnk := myGui.Add("Text", "x35 y+15 w" (guiW - 70) " h20 Center BackgroundTrans cGray", "Cancel")
        lnk.OnEvent("Click", (*) => (Result := "", myGui.Destroy()))

        myGui.Add("Text", "x0 y+15 w1 h1", "")

        this._ShowCentered(myGui, guiW)
        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    static ShowTextViewer(title, text, width := 600, height := 400) {
        viewer := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", title)
        viewer.BackColor := "1A1A1A"
        WinSetTransparent(0, viewer.Hwnd)

        ; Header
        viewer.SetFont("s11 cWhite Bold", "Segoe UI")
        titleBar := viewer.Add("Text", "x0 y0 w" (width - 65) " h35 +0x200 Background202020", "  " . title)
        titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, viewer.Hwnd))

        ; Copy Button
        viewer.SetFont("s10 Norm")
        copyBtn := viewer.Add("Text", "x" (width - 65) " y0 w30 h35 +0x200 +Center Background202020 cSilver", "📋")
        copyBtn.SavedText := text
        copyBtn.OnEvent("Click", (ctrl, *) => (
            A_Clipboard := ctrl.SavedText,
            this.CustomStatusPop("Copied!", "White"),
            ctrl.Opt("cWhite"), SetTimer(() => ctrl.Opt("cSilver"), -150)
        ))

        ; Close Button
        closeBtn := viewer.Add("Text", "x+0 y0 w35 h35 +0x200 +Center Background202020 cRed", "✕")
        closeBtn.OnEvent("Click", (*) => viewer.Destroy())

        ; Content
        viewer.SetFont("s10 cSilver", "Segoe UI")
        viewer.Add("Edit", "x15 y45 w" (width - 30) " h" (height - 60) " ReadOnly -E0x200 Background1A1A1A -Border cWhite", text)

        viewer.Show("w" width " h" height " NoActivate")

        loop 10 {
            if (!WinExist("ahk_id " viewer.Hwnd))
                break
            try WinSetTransparent(A_Index * 25, "ahk_id " viewer.Hwnd)
            Sleep(10)
        }
        try WinSetTransparent(255, "ahk_id " viewer.Hwnd)

        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(viewer.Hwnd)
    }

    ; NOTIFICATIONS (The Fix is Here)

    static CustomStatusPop(text, color := "White", duration := 2500) {
        ; Cleanup previous
        try if (this.PopGui)
            this.PopGui.Destroy()

        this.PopGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
        this.PopGui.BackColor := "1A1A1A" ; Strictly Dark Background

        ; FORCE WHITE TEXT: We ignore the 'color' parameter for the font itself
        ; to ensure maximum readability.
        this.PopGui.SetFont("s12 cWhite", "Segoe UI")

        this.PopGui.Add("Text", "x20 y8 Center", text)
        this.PopGui.Show("NoActivate AutoSize Center")

        SetTimer(() => this.FadeOut(), -Abs(duration))
    }

    static FadeOut() {
        if (!this.PopGui)
            return
        loop 10 {
            if (!this.PopGui)
                break
            try WinSetTransparent(255 - (A_Index * 25), "ahk_id " this.PopGui.Hwnd)
            Sleep(20)
        }
        try if (this.PopGui) {
            this.PopGui.Destroy()
            this.PopGui := ""
        }
    }

    static CustomTrayTip(text, iconType := 1) {
        try {
            TrayTip(text, "Nexus", (iconType == 2 ? 2 : 1))
            SetTimer(() => TrayTip(), -3000)
        }
    }

    ; HELPERS

    static Show(text, title := "Nexus", options := 0) {
        return this.CustomMsgBox(title, text, 0, options)
    }

    static AskForConfirmation(title, text) {
        return (this.CustomMsgBox(title, text, 0, 4) == "Yes")
    }

    static _CreateModernGui(title, w) {
        ownerOpt := (IsSet(GuiBuilder) && GuiBuilder.MainGui) ? " +Owner" . GuiBuilder.MainGui.Hwnd : ""
        myGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Border" . ownerOpt, title)
        myGui.BackColor := "202020"

        myGui.SetFont("s11 cWhite Bold", "Segoe UI")
        myGui.Add("Text", "x0 y0 w" w " h40 Background202020")

        hdr := myGui.Add("Text", "x15 y0 w" (w - 50) " h40 +0x200 BackgroundTrans", title)
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, myGui.Hwnd))

        btnClose := myGui.Add("Text", "x" (w - 40) " y0 w40 h40 +0x200 Center BackgroundTrans cRed", "✕")
        btnClose.OnEvent("Click", (*) => myGui.Destroy())

        myGui.Add("Text", "x0 y40 w" w " h1 Background444444")
        return myGui
    }

    static _AddFlatButton(guiObj, text, options, callback) {
        guiObj.SetFont("s10 Norm cWhite", "Segoe UI")
        btn := guiObj.Add("Text", options " +0x200 Center Background333333 +Border", text)
        btn.OnEvent("Click", callback)
        return btn
    }

    static _ShowCentered(guiObj, w) {
        guiObj.Show("Hide w" w)
        this._CenterOnOwner(guiObj)
        guiObj.Show()
    }

    static _CenterOnOwner(childGui) {
        targetHwnd := 0
        if (IsSet(GuiBuilder) && GuiBuilder.MainGui) {
            try targetHwnd := GuiBuilder.MainGui.Hwnd
        }

        if (targetHwnd && WinExist("ahk_id " targetHwnd)) {
            try {
                WinGetPos(&pX, &pY, &pW, &pH, "ahk_id " targetHwnd)
                WinGetPos(, , &cW, &cH, "ahk_id " childGui.Hwnd)
                childGui.Move(pX + (pW - cW) // 2, pY + (pH - cH) // 2)
                return
            }
        }
        childGui.Show("Center")
    }
}