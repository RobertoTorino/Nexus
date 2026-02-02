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

        myGui := this._CreateModernGui(title, guiW)
        myGui.SetFont("s10 cSilver", "Segoe UI")

        ; ReadOnly Edit for copyable text
        editCtrl := myGui.Add("Edit", "x15 y45 w" (guiW - 30) " r5 ReadOnly Background202020 -E0x200 -VScroll +Wrap", message)

        yPos := "y+20"
        if (options & 4) {
            this._AddFlatButton(myGui, "Yes", "x100 " yPos " w100 h35", (*) => (Result := "Yes", myGui.Destroy()))
            this._AddFlatButton(myGui, "No", "x+20 yp w100 h35", (*) => (Result := "No", myGui.Destroy()))
        } else {
            this._AddFlatButton(myGui, "OK", "x175 " yPos " w100 h35", (*) => (Result := "OK", myGui.Destroy()))
        }

        myGui.Add("Text", "x0 y+15 w1 h1", "")
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
        myGui.SetFont("s10 cSilver")
        myGui.Add("Text", "x20 y50 w" (guiW - 40) " +Wrap BackgroundTrans", prompt)

        myGui.SetFont("s11 cWhite")
        edt := myGui.Add("Edit", "x20 y+15 w" (guiW - 40) " h30 Background333333 -E0x200 +Border", defaultText)

        yPos := "y+25"
        this._AddFlatButton(myGui, "OK", "x100 " yPos " w100 h35", (*) => (Result := edt.Value, myGui.Destroy()))
        this._AddFlatButton(myGui, "Cancel", "x+20 yp w100 h35", (*) => (Result := "", myGui.Destroy()))

        myGui.Add("Text", "x0 y+20 w1 h1", "")

        ; [FIX] Removed invalid OnEvent("Show").
        ; Instead, we simply show the window, then focus the control immediately.
        this._ShowCentered(myGui, guiW)
        try ControlFocus(edt)

        WinWaitClose("ahk_id " myGui.Hwnd)
        return Result
    }

    static AskForChoice(title, prompt, options) {
        Result := ""
        guiW := 350

        myGui := this._CreateModernGui(title, guiW)
        myGui.SetFont("s10 cSilver")
        myGui.Add("Text", "x20 y50 w" (guiW - 40) " Center BackgroundTrans", prompt)

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

        ; Initial state: Hidden and transparent
        WinSetTransparent(0, viewer.Hwnd)

        viewer.SetFont("s11 cSilver", "Segoe UI")

        ; Custom Header
        titleBar := viewer.Add("Text", "x0 y0 w" (width - 65) " h30 +0x200 Background2A2A2A", "  " . title)
        titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, viewer.Hwnd))

        ; 1. Add the Copy Button (Using the Matte Blue theme)
        ; +0x100 (SS_NOTIFY) ensures clicks are registered
        copyBtn := viewer.Add("Text", "x" (width - 65) " y0 w30 h30 +0x200 +Center +0x100 Background2A2A2A cSilver", "📋")
        ; 2. We use a global-ish property or a Bound Function to ensure the text persists
        ; Binding the 'text' variable directly to the function
        copyBtn.OnEvent("Click", this.OnCopyClick.Bind(this, text))

        ; 2. ATTACH THE DATA: Save the text string directly to the button object
        copyBtn.SavedText := text

        ; 3. THE ACTION: Use 'ctrl' to access the stored text
        copyBtn.OnEvent("Click", (ctrl, *) => (
            A_Clipboard := ctrl.SavedText,
            DialogsGui.CustomStatusPop("Copied to Clipboard", "White"),
            Logger.Info("UI: Help text copied to clipboard.", "DialogsGui")
        ))

        closeBtn := viewer.Add("Text", "x+0 w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
        closeBtn.OnEvent("Click", (*) => viewer.Destroy())

        ; Main Content - Hidden Scrollbar and Sunken Borders removed
        viewer.SetFont("s10 cSilver")

        ; -VScroll: Hides the bar
        ; -E0x200: Removes the sunken border
        ; -TabStop: Prevents the control from being "clicked into" or Tabbed into
        ; ReadOnly: Prevents the caret (blinking line) and editing
        viewer.Add("Edit", "x15 y40 w" (width - 30) " h" (height - 55) " ReadOnly -VScroll -E0x200 -TabStop Background1A1A1A", text)

        ; Show the window
        viewer.Show("w" width " h" height " NoActivate")

        ; --- SUBTLE FADE IN ---
        loop 15 { ; 15 steps instead of 10
            if (!WinExist("ahk_id " viewer.Hwnd))
                break
            transValue := Integer(A_Index * 17) ; 15 * 17 = 255
            try WinSetTransparent(transValue, "ahk_id " viewer.Hwnd)
            Sleep(10) ; Faster updates
        }
        ; Final safety to ensure it's 100% solid
        try WinSetTransparent(255, "ahk_id " viewer.Hwnd)

        ; Register for magnetic snapping
        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(viewer.Hwnd)
    }

    static OnCopyClick(textToCopy, ctrl, *) {
        ; 1. Visual Feedback (High Performance)
        ctrl.Opt("Background444444") ; Lighten background instantly
        ctrl.Redraw()

        try {
            A_Clipboard := textToCopy
            DialogsGui.CustomStatusPop("Copied to Clipboard", "004466")
        }

        ; 2. Reset visual after a tiny delay (50ms is enough to see it)
        SetTimer(() => (ctrl.Opt("Background2A2A2A"), ctrl.Redraw()), -50)
    }

    ; NOTIFICATIONS

    static CustomStatusPop(text, color := "Silver", duration := 2500) {
        ; 1. NORMALIZE THE COLOR
        if (color ~= "i)^(RomScanner|WindowManager|GuiBuilder|ConfigManager|ProcessManager)$"
            || color == ""
            || StrLen(color) > 12) {
            color := "004466"
        }

        ; 2. CLEANUP PREVIOUS POPUP
        try if (this.HasProp("PopGui") && this.PopGui)
            this.PopGui.Destroy()

        ; 3. CREATE THE POPUP
        this.PopGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
        this.PopGui.BackColor := "1A1A1A"

        this.PopGui.SetFont("s12 c" . color, "Segoe UI")
        this.PopGui.Add("Text", "x15 y6 Center", text)

        ; 4. DISPLAY
        this.PopGui.Show("NoActivate AutoSize Center")

        ; 5. START FADE TIMER
        ; We stay at full visibility for (duration), then start fading
        timeout := -Abs(duration)
        SetTimer(() => this.FadeOut(), timeout)
    }

    static FadeOut() {
        if (!this.PopGui)
            return

        ; Loop through transparency from 255 (solid) down to 0 (invisible)
        loop 10 {
            if (!this.PopGui)
                break
            transparency := 255 - (A_Index * 25)
            try WinSetTransparent(Max(0, transparency), "ahk_id " this.PopGui.Hwnd)
            Sleep(20) ; Speed of the fade
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

    ; --- COMPATIBILITY METHODS ---

    static Show(text, title := "Nexus", options := 0) {
        return this.CustomMsgBox(title, text, 0, options)
    }

    static AskForConfirmation(title, text) {
        result := this.CustomMsgBox(title, text, 0, 4)
        return (result == "Yes")
    }

    ; INTERNAL HELPERS

    static _CreateModernGui(title, w) {
        ownerOpt := (IsSet(GuiBuilder) && GuiBuilder.MainGui) ? " +Owner" . GuiBuilder.MainGui.Hwnd : ""
        myGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Border" . ownerOpt, title)
        myGui.BackColor := "202020"
        myGui.SetFont("s10 cWhite", "Segoe UI")
        myGui.SetFont("s11 cWhite Bold")
        hdr := myGui.Add("Text", "x15 y10 w" (w - 50) " h25 +0x200 BackgroundTrans", title)
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, myGui.Hwnd))
        btnClose := myGui.Add("Text", "x" (w - 35) " y10 w25 h25 +0x200 Center BackgroundTrans cRed", "✕")
        btnClose.OnEvent("Click", (*) => myGui.Destroy())
        myGui.Add("Text", "x0 y38 w" w " h1 Background444444")
        return myGui
    }

    static _AddFlatButton(guiObj, text, options, callback) {
        guiObj.SetFont("s10 Norm cWhite")
        btn := guiObj.Add("Text", options " +0x200 Center Background333333 +Border", text)
        btn.OnEvent("Click", callback)
        return btn
    }

    static _ShowCentered(guiObj, w, h := 0) {
        guiObj.Show("Hide w" w . (h > 0 ? " h" h : ""))
        this._CenterOnOwner(guiObj)
        guiObj.Show()
    }

    static _CenterOnOwner(childGui) {
        targetHwnd := 0
        if (IsSet(GuiBuilder) && GuiBuilder.MainGui) {
            try {
                if WinExist("ahk_id " . GuiBuilder.MainGui.Hwnd)
                    targetHwnd := GuiBuilder.MainGui.Hwnd
            }
        }

        if (targetHwnd) {
            try {
                WinGetPos(&pX, &pY, &pW, &pH, "ahk_id " targetHwnd)
                WinGetPos(, , &cW, &cH, "ahk_id " childGui.Hwnd)
                nX := pX + (pW - cW) // 2
                nY := pY + (pH - cH) // 2
                childGui.Move(nX, nY)
                return
            }
        }
        childGui.Show("Center")
    }
}