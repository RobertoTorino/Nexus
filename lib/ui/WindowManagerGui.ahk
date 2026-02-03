#Requires AutoHotkey v2.0
; ======================================================================
; * @description Complete V1-Style Window Manager (Unfiltered Debug Mode)
; * @class WindowManagerGui
; * @location lib/ui/WindowManagerGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ======================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\window\WindowManager.ahk
#Include ..\ui\DialogsGui.ahk

class WindowManagerGui {
    static WinGui := ""
    static ListView := ""
    static NudgeStep := 1
    static GameHwnd := 0
    static OverscanVal := 0

    static RegisteredGuis := Map()
    static SnapThreshold := 20
    static LastMainPos := { x: 0, y: 0 }
    static IsMoveHookActive := false

    static EditW := ""
    static EditH := ""
    static EditStep := ""
    static BtnMon1 := ""
    static BtnMon2 := ""
    static EditOverscan := ""

    static txtMonitorInfo := ""

    static Show() {
        if (this.HasProp("WinGui") && IsObject(this.WinGui) && this.WinGui) {
            this.WinGui.Show()
            this.RefreshList()
            return
        }

        winTitle := "  Nexus :: Window Manager | Positioning | Nudge Steps (px) | Custom Size | Predefined Sizes |"
        if (IsSet(WindowManager) && WindowManager.ActiveGameExe != "")
            winTitle .= " - [" . WindowManager.ActiveGameExe . "]"

        this.WinGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow +Owner", "Nexus :: Window Manager")
        this.WinGui.BackColor := "2A2A2A"
        this.WinGui.SetFont("s12 cSilver", "Segoe UI")
        this.WinGui.OnEvent("Close", (*) => this.Destroy())
        this.WinGui.OnEvent("Escape", (*) => this.Destroy())

        guiW := 905

        ; CUSTOM TITLE BAR
        titleCtrl := this.WinGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", winTitle)
        titleCtrl.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.WinGui.Hwnd))

        BtnClose := this.WinGui.Add("Text", "x+0 w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
        BtnClose.OnEvent("Click", (*) => this.Destroy())

        ; WINDOW LIST
        this.ListView := this.WinGui.Add("ListView", "x5 y+5 w895 h150 -Multi Background2A2A2A cSilver", ["ID", "Title", "Class", "Status"])
        this.ListView.OnEvent("DoubleClick", (*) => this.OnListDoubleClick())

        this.ListView.ModifyCol(1, 95)
        this.ListView.ModifyCol(2, 325)
        this.ListView.ModifyCol(3, 375)
        this.ListView.ModifyCol(4, 65)

        ; --- ROW 1: WINDOW STATE BUTTONS ---
        yState := "y+10"

        this.BtnAddTheme("  Destroy  ", (*) => this.Action("Close"), "x6 " yState " Background660000")
        this.BtnAddTheme("  Hidden  ", (*) => this.Action("Hide"), "x+10 Background333333")
        this.BtnAddTheme("  Show  ", (*) => this.Action("Show"), "x+10 Background333333")
        this.BtnAddTheme("  Minimized  ", (*) => this.Action("Minimize"), "x+10 Background333333")
        this.BtnAddTheme("  Maximized  ", (*) => this.Action("Maximize"), "x+10 Background333333")
        this.BtnAddTheme("  Windowed  ", (*) => this.Action("Windowed"), "x+10 Background333333")
        this.BtnAddTheme("  True Borderless Fullscreen  ", (*) => this.Action("Borderless"), "x+10 Background333333")
        this.BtnAddTheme("  Refresh List  ", (*) => this.RefreshList(), "x+10 Background333333")

        ; --- ROW 2  ---
        ; --- ROW 2: ADVANCED MODES ---
        this.BtnAddTheme("  Restore  ", (*) => this.Action("Default"), "x6 " yState " Background333333", "Resets window to standard OS defaults.")
        this.BtnAddTheme("  Fit Screen  ", (*) => this.Action("FitScreen"), "x+10 Background333333", "Stretches window to fill the current monitor.")
        this.BtnAddTheme("  Topmost  ", (*) => WindowManager.ApplyMode(this.GetValidHwndFromUI(), "Topmost", 0, {}), "x+10 Background333333", "Keeps the game on top of all other windows.")
        this.BtnAddTheme("  Tool Window  ", (*) => WindowManager.ApplyMode(this.GetValidHwndFromUI(), "ToolWindow", 0, {}), "x+10 Background333333", "Hides the game from the Windows Alt-Tab menu.")
        this.BtnAddTheme("  Layered  ", (*) => WindowManager.ApplyMode(this.GetValidHwndFromUI(), "Layered", 0, {}), "x+10 Background333333", "Enables advanced transparency and overlay support.")
        this.BtnAddTheme("  No Activate  ", (*) => WindowManager.ApplyMode(this.GetValidHwndFromUI(), "NoActivate", 0, {}), "x+10 Background333333", "Window will not take focus when clicked or resized.")
        this.BtnAddTheme("  Overscan  ", (*) => WindowManager.ApplyPreset("SizeOverscan"), "x+10 Background333333", "Zooms slightly past edges to hide UI borders.")
        this.BtnAddTheme("  Force Saved Settings  ", (*) => WindowManager.ApplyGameSettings(), "x+10 Background006666")

        ; --- ROW 3: OVERSCAN LOGIC ---
        this.BtnAddTheme("  Apply H-Overscan  ", (*) => WindowManager.ApplyHorizontalOverscan(this.OverscanVal), "x6 " yState " Background006666")

        this.WinGui.SetFont("Bold s12 cBlack")

        this.EditOverscan := this.WinGui.Add("Edit", "x+0 h26 w35 Number +0x200 Center", "0")

        this.WinGui.SetFont("Norm s12 cSilver")

        this.EditOverscan.OnEvent("Change", (ctrl, *) => this.OverscanVal := ctrl.Value)
        this.BtnAddTheme("  Apply V-Overscan  ", (*) => WindowManager.ApplyVerticalOverscan(this.OverscanVal), "x+0 Background006666")
        this.BtnAddTheme("  U  ", (*) => WindowManager.Nudge(0, -this.NudgeStep, 0, 0), "x+10 +0x200 Center Background333333")
        this.BtnAddTheme("  D  ", (*) => WindowManager.Nudge(0, this.NudgeStep, 0, 0), "x+0  +0x200 Center Background333333")
        this.BtnAddTheme("  L  ", (*) => WindowManager.Nudge(-this.NudgeStep, 0, 0, 0), "x+0  +0x200 Center Background333333")
        this.BtnAddTheme("  R  ", (*) => WindowManager.Nudge(this.NudgeStep, 0, 0, 0), "x+0  +0x200 Center Background333333")

        this.WinGui.SetFont("Bold s12 cBlack")

        this.EditStep := this.WinGui.Add("Edit", "x+0 h26 w35 Number Center", "1")
        this.EditStep.OnEvent("Change", (ctrl, *) => this.NudgeStep := ctrl.Value)

        this.WinGui.SetFont("Norm s12 cSilver")

        this.BtnAddTheme("  W ++  ", (*) => WindowManager.Nudge(0, 0, this.NudgeStep, 0, true), "x+0 Background333333")
        this.BtnAddTheme("  H ++  ", (*) => WindowManager.Nudge(0, 0, 0, this.NudgeStep, true), "x+0 Background333333")
        this.BtnAddTheme("  W --  ", (*) => WindowManager.Nudge(0, 0, -this.NudgeStep, 0, true), "x+0 Background333333")
        this.BtnAddTheme("  H --  ", (*) => WindowManager.Nudge(0, 0, 0, -this.NudgeStep, true), "x+0 Background333333")
        this.BtnAddTheme("  Save  ", (*) => WindowManager.SaveCurrentPosition(), "x+0 Background006666")

        this.WinGui.SetFont("Bold s12 cBlack")

        this.EditW := this.WinGui.Add("Edit", "x+10 h26 w50 Number Center", "1920")
        this.EditH := this.WinGui.Add("Edit", "x+0 h26 w50 Number Center", "1080")

        this.WinGui.SetFont("Norm s12 cSilver")

        this.BtnAddTheme("Set", (*) => this.ApplyCustomSize(), "x+0 w35 Background006666")

        ; --- ROW 4: RESOLUTIONS
        this.BtnAddTheme("1920x1080", (*) => WindowManager.ApplyPreset("Size1920x1080"), "x6 " yState " w90 Background333333")
        this.BtnAddTheme("1920x1200", (*) => WindowManager.ApplyPreset("Size1920x1200"), "x+10 Background333333 w90")
        this.BtnAddTheme("1920x1440", (*) => WindowManager.ApplyPreset("Size1920x1440"), "x+10 Background333333 w90")
        this.BtnAddTheme("2048x1152", (*) => WindowManager.ApplyPreset("Size2048x1152"), "x+10 Background333333 w90")
        this.BtnAddTheme("2048x1536", (*) => WindowManager.ApplyPreset("Size2048x1536"), "x+10 Background333333 w90")
        this.BtnAddTheme("2560x1440", (*) => WindowManager.ApplyPreset("Size2560x1440"), "x+10 Background333333 w90")
        this.BtnAddTheme("2560x1600", (*) => WindowManager.ApplyPreset("Size2560x1600"), "x+10 Background333333 w90")
        this.BtnAddTheme("2880x1800", (*) => WindowManager.ApplyPreset("Size2880x1800"), "x+10 Background333333 w90")
        this.BtnAddTheme("3840x2160", (*) => WindowManager.ApplyPreset("Size3840x2160"), "x+10 Background333333 w90")

        ; --- ROW 5: RESOLUTIONS
        this.BtnAddTheme("4096x2160", (*) => WindowManager.ApplyPreset("Size4096x2160"), "x6 " yState " w90 Background333333 w90")
        this.BtnAddTheme("5120x2880", (*) => WindowManager.ApplyPreset("Size5120x2880"), "x+10 Background333333 w90")
        this.BtnAddTheme("6016x3384", (*) => WindowManager.ApplyPreset("Size6016x3384"), "x+10 Background333333 w90")
        this.BtnAddTheme("7680x4320", (*) => WindowManager.ApplyPreset("Size7680x4320"), "x+10 Background333333 w90")

        ; --- ROW 6: RESOLUTIONS 1080P
        this.BtnAddTheme("  1080P  ", (*) => WindowManager.ApplyPreset("SizeBorderlessTopmost1920"), "x6 " yState " Background004466")
        this.BtnAddTheme("  Bor+Top  ", (*) => WindowManager.ApplyPreset("SizeBorderlessTopmost1920"), "x+0 Background004466")
        this.BtnAddTheme("  Bor+Layer  ", (*) => WindowManager.ApplyPreset("SizeBorderlessLayered1920"), "x+0 Background004466")
        this.BtnAddTheme("  Fake Fullscreen  ", (*) => WindowManager.ApplyPreset("SizeFakeFull1920"), "x+0 Background004466")
        this.BtnAddTheme("  All Logic  ", (*) => WindowManager.ApplyPreset("SizeFakeFullAll1920"), "x+0 Background004466")
        ; 1440P
        this.BtnAddTheme("  1440P  ", (*) => WindowManager.ApplyPreset("SizeBorderlessTopmost2560"), "x+10 Background004466")
        this.BtnAddTheme("  Bor+Top  ", (*) => WindowManager.ApplyPreset("SizeBorderlessTopmost2560"), "x+0 Background004466")
        this.BtnAddTheme("  Bor+Layer  ", (*) => WindowManager.ApplyPreset("SizeBorderlessLayered2560"), "x+0 Background004466")
        this.BtnAddTheme("  Fake Fullscreen  ", (*) => WindowManager.ApplyPreset("SizeFakeFull2560"), "x+0 Background004466")
        this.BtnAddTheme("  All Logic  ", (*) => WindowManager.ApplyPreset("SizeFakeFullAll2560"), "x+0 Background004466")

        ; --- ROW 7: MONITOR SWITCH ---
        this.BtnMon1 := this.BtnAddTheme("  Monitor 01  ", (*) => this.SwitchMonitor(1), "x6 " yState " Background333333", "Move window to Primary Display.")
        this.BtnMon2 := this.BtnAddTheme("  Monitor 02  ", (*) => this.SwitchMonitor(2), "x+0 Background333333", "Move window to Secondary Display.")

        ; The Info Label (No callback, just visual)
        this.txtMonitorInfo := this.WinGui.Add("Text", "x+10 w205 h26 +0x200 +Border Background333333 Center", " Active: [Detecting...] ")

        this.BtnAddTheme("  Reset All  ", (*) => WindowManager.ForceKillAll(), "x+405 Background660000", "WARNING: Force closes all known emulator processes.")

        this.UpdateMonitorVisuals(1)

        this.WinGui.Show("w" guiW)
        ; --- THE FIX: Listen for mouse movement over controls ---
        OnMessage(0x0200, WindowManagerGui.OnMouseMove.Bind(WindowManagerGui))

        if !this.HasProp("RegisteredGuis")
            this.RegisteredGuis := Map()

        if (this.WinGui)
            this.RegisterForSnapping(this.WinGui.Hwnd)

        this.RefreshList()
    }

    static VisualFeedback(ctrl, flashColor := "Background444444", originalColor := "Background333333") {
        ctrl.Opt("+" . flashColor)
        ctrl.Redraw()
        ; Use a high-speed timer to revert (50ms is the "sweet spot" for human eyes)
        SetTimer(() => (ctrl.Opt("+" . originalColor), ctrl.Redraw()), -50)
    }

    static Destroy() {
        if (this.WinGui) {
            this.WinGui.Destroy()
            this.WinGui := ""
        }
    }

    static SwitchMonitor(monitorIndex) {
        ; Move the actual window
        WindowManager.MoveToMonitor(monitorIndex)

        ; Force the UI to reflect the move
        this.UpdateMonitorVisuals(monitorIndex)

        ; Optional: Small delay then refresh list to update the "Status" column
        SetTimer(() => this.RefreshList(), -200)
    }

    static UpdateMonitorVisuals(activeIndex) {
        cActive := "Background006666"
        cInactive := "Background333333"

        if !this.HasProp("BtnMon1") || !this.HasProp("BtnMon2")
            return

        ; 1. Update Button Colors
        if (activeIndex == 1) {
            this.BtnMon1.Opt("+" cActive), this.BtnMon2.Opt("+" cInactive)
        } else {
            this.BtnMon1.Opt("+" cInactive), this.BtnMon2.Opt("+" cActive)
        }
        this.BtnMon1.Redraw(), this.BtnMon2.Redraw()

        ; 2. Update Resolution Text
        mon := MonitorHelper.GetMonitorGeometry(activeIndex)
        if (mon) {
            infoText := "Active: Mon " activeIndex " [" mon.Width "x" mon.Height "]"
            this.txtMonitorInfo.Value := infoText
        }
    }

    static BtnAddTheme(label, callback, options, tip := "") {
        btn := this.WinGui.Add("Text", "h26 +0x200 +Center +Border " options, label)

        originalBg := "Background333333"
        if RegExMatch(options, "i)Background([0-9A-F]{6})", &match)
            originalBg := "Background" . match[1]

        ; Visual Feedback
        btn.OnEvent("Click", (ctrl, *) => (
            this.VisualFeedback(ctrl, "Background444444", originalBg),
            callback(ctrl)
        ))

        ; --- THE FIX: Store tip in the control object ---
        if (tip != "")
            btn.ToolTipText := tip

        return btn
    }

    ; [UPDATED] Unfiltered Refresh List
    static RefreshList() {
        if !this.WinGui
            return

        selectedHwnd := 0
        row := this.ListView.GetNext(0)
        if (row > 0)
            selectedHwnd := this.ListView.GetText(row, 1)

        this.ListView.Delete()

        targetPids := Map()

        ; --- [FIX START] ---
        ; 1. Check ConfigManager for the REAL active process (e.g. PPSSPPWindows64.exe)
        activeExe := ConfigManager.ActiveProcessName

        if (activeExe != "") {
            try {
                pid := ProcessExist(activeExe)
                if (pid)
                    targetPids[pid] := true
            }
        }

        ; 2. Fallback to WindowManager internal tracking
        if (IsSet(WindowManager) && WindowManager.ActiveGamePid > 0)
            targetPids[WindowManager.ActiveGamePid] := true
        ; --- [FIX END] ---

        if (targetPids.Count == 0) {
            this.ListView.Add("", "", "No active game tracked", "", "")
            return
        }

        prevDetect := A_DetectHiddenWindows
        DetectHiddenWindows(true)

        try {
            uniqueIds := Map()
            for pid, _ in targetPids {
                try {
                    ids := WinGetList("ahk_pid " pid)
                    for id in ids
                        uniqueIds[id] := true
                }
            }

            for this_id, _ in uniqueIds {
                title := WinGetTitle(this_id)
                cls := WinGetClass(this_id)
                style := WinGetStyle(this_id)
                status := (style & 0x10000000) ? "Visible" : "Hidden"
                this.ListView.Add("", this_id, title, cls, status)
            }
        } catch {
            this.ListView.Add("", "Error", "Could not list windows", "", "")
        }
        DetectHiddenWindows(prevDetect)

        ; --- THE FIX: SYNC MONITOR BUTTONS ---
        ; This must happen AFTER the list is refreshed and DetectHiddenWindows is reset
        hwnd := this.GetValidHwndFromUI()
        if (hwnd) {
            actualMon := MonitorHelper.GetMonitorIndexFromWindow(hwnd)
            this.UpdateMonitorVisuals(actualMon)
        }
    }

    static Action(type) {
        row := this.ListView.GetNext(0)

        hwnd := 0
        if (row > 0)
            hwnd := Integer(this.ListView.GetText(row, 1))
        else
            hwnd := WindowManager.GetValidHwnd()

        if (!hwnd) {
            DialogsGui.CustomTrayTip("No window selected", 2)
            return
        }

        prevDetect := A_DetectHiddenWindows
        DetectHiddenWindows(true)

        try {
            if !WinExist("ahk_id " hwnd) {
                DialogsGui.CustomTrayTip("Window gone", 2)
                return
            }

            switch type {
                case "Close": WinClose("ahk_id " hwnd)
                case "Hide": WinHide("ahk_id " hwnd)
                case "Show": WinShow("ahk_id " hwnd)
                case "Minimize": WinMinimize("ahk_id " hwnd)
                case "Maximize":
                    WinShow("ahk_id " hwnd)
                    WinMaximize("ahk_id " hwnd)
                case "Borderless": WindowManager.ApplyMode(hwnd, "Borderless", 0, {})
                case "Windowed": WindowManager.ApplyMode(hwnd, "Windowed", 0, {})
                case "Default": WindowManager.ApplyMode(hwnd, "Restored", 0, {})
                case "FitScreen": WindowManager.ApplyPreset("SizeFitScreen")
                case "Center":
                    WinGetPos(, , &w, &h, "ahk_id " hwnd)
                    WindowManager.ApplyFakeFullscreen(hwnd, w, h, 0, {})
            }
            SetTimer(() => this.RefreshList(), -500)
        } catch {
            DialogsGui.CustomTrayTip("Action Failed", 3)
        } finally {
            DetectHiddenWindows(prevDetect)
        }
    }

    static ApplyCustomSize() {
        hwnd := this.GetValidHwndFromUI()
        if (!hwnd || !WinExist("ahk_id " hwnd))
            return

        try {
            w := Integer(this.EditW.Value)
            h := Integer(this.EditH.Value)

            if (w > 0 && h > 0) {
                ; 1. Move the window
                WinMove(, , w, h, "ahk_id " hwnd)

                ; 2. Sync Context: If WindowManager doesn't know the game, tell it
                if (WindowManager.ActiveGameId == "")
                    WindowManager.ActiveGameId := ConfigManager.CurrentGameId

                ; 3. Auto-Save the new size to JSON
                if (WindowManager.ActiveGameId != "") {
                    WinGetPos(&x, &y, , , "ahk_id " hwnd)
                    ConfigManager.UpdateGameWindowProfile(WindowManager.ActiveGameId, x, y, w, h)
                    DialogsGui.CustomStatusPop("Size Set & Saved")
                }
            }
        } catch {
            DialogsGui.CustomStatusPop("Failed to resize/save")
        }
    }

    ; Helper to ensure we are targeting the right window from the list
    static GetValidHwndFromUI() {
        ; 1. If a row is selected in the list, use that
        row := this.ListView.GetNext(0)
        if (row > 0)
            return Integer(this.ListView.GetText(row, 1))

        ; 2. If nothing is selected, ask WindowManager for the best guess
        return WindowManager.GetValidHwnd()
    }

    static OnListDoubleClick() {
        this.RefreshList()
    }

    ; ---- SNAPPING LOGIC (Restored) ----
    static RegisterForSnapping(hwnd) {
        if (this.RegisteredGuis.Count == 0) {
            OnMessage(0x0216, (wp, lp, msg, h) => this.OnWindowMoving(wp, lp, h))
        }

        if (!this.IsMoveHookActive) {
            if IsSet(GuiBuilder) && GuiBuilder.MainGui {
                GuiBuilder.MainGui.GetPos(&mainX, &mainY)
                this.LastMainPos := { x: mainX, y: mainY }

                OnMessage(0x0003, (w, l, m, h) => WindowManagerGui.OnMainMove(w, l, m, h))
                this.IsMoveHookActive := true
            }
        }
        this.RegisteredGuis[hwnd] := true
    }

    static OnWindowMoving(wParam, lParam, hwnd) {
        if (!this.RegisteredGuis.Has(hwnd))
            return
        if !IsSet(GuiBuilder) || !GuiBuilder.MainGui
            return

        GuiBuilder.MainGui.GetPos(&mX, &mY, &mW, &mH)
        currL := NumGet(lParam, 0, "Int"), currT := NumGet(lParam, 4, "Int")
        currR := NumGet(lParam, 8, "Int"), currB := NumGet(lParam, 12, "Int")
        currW := currR - currL, currH := currB - currT

        snapX := "", snapY := ""

        if (Abs(currL - (mX + mW)) < this.SnapThreshold)
            snapX := mX + mW
        else if (Abs(currR - mX) < this.SnapThreshold)
            snapX := mX - currW
        else if (Abs(currL - mX) < this.SnapThreshold)
            snapX := mX
        else if (Abs(currR - (mX + mW)) < this.SnapThreshold)
            snapX := mX + mW - currW

        if (Abs(currT - mY) < this.SnapThreshold)
            snapY := mY
        else if (Abs(currB - (mY + mH)) < this.SnapThreshold)
            snapY := mY + mH
        else if (Abs(currB - mY) < this.SnapThreshold)
            snapY := mY - currH
        else if (Abs(currT - (mY + mH)) < this.SnapThreshold)
            snapY := mY + mH

        if (snapX !== "") {
            NumPut("Int", snapX, lParam, 0)
            NumPut("Int", snapX + currW, lParam, 8)
        }
        if (snapY !== "") {
            NumPut("Int", snapY, lParam, 4)
            NumPut("Int", snapY + currH, lParam, 12)
        }
    }

    static OnMainMove(wParam, lParam, msg, hwnd) {
        ; 1. Safety check: Is the GuiBuilder even initialized?
        if !IsSet(GuiBuilder) || !HasProp(GuiBuilder, "MainGui")
            return

        ; 2. Safety check: Is MainGui an object and does it have a valid Hwnd?
        if !IsObject(GuiBuilder.MainGui) || !HasProp(GuiBuilder.MainGui, "Hwnd")
            return

        ; 3. Ignore messages that aren't for the MainGui
        if (hwnd != GuiBuilder.MainGui.Hwnd)
            return

        try {
            ; Get current position safely
            GuiBuilder.MainGui.GetPos(&nX, &nY)

            ; Initialize LastMainPos if it's missing to avoid "Unassigned Variable" errors
            if !WindowManagerGui.HasProp("LastMainPos") || !IsObject(WindowManagerGui.LastMainPos) {
                WindowManagerGui.LastMainPos := { x: nX, y: nY }
                return
            }

            dX := nX - WindowManagerGui.LastMainPos.x
            dY := nY - WindowManagerGui.LastMainPos.y

            ; If no movement, exit
            if (dX == 0 && dY == 0)
                return

            ; Hold Ctrl to move Main UI without moving attached windows
            if GetKeyState("Ctrl", "P") {
                WindowManagerGui.LastMainPos := { x: nX, y: nY }
                return
            }

            ; Move registered child GUIs (like the Window Manager itself)
            if WindowManagerGui.HasProp("RegisteredGuis") {
                for cHwnd, _ in WindowManagerGui.RegisteredGuis {
                    if WinExist("ahk_id " cHwnd) {
                        try {
                            WinGetPos(&cX, &cY, , , "ahk_id " cHwnd)
                            WinMove(cX + dX, cY + dY, , , "ahk_id " cHwnd)
                        }
                    }
                }
            }

            ; Update reference point for next move
            WindowManagerGui.LastMainPos := { x: nX, y: nY }
        }
    }

    ; --- INSERT THIS AT THE BOTTOM OF YOUR CLASS ---
static OnMouseMove(wParam, lParam, msg, hwnd) {
        ; --- SAFETY GUARD ---
        ; If the main GUI variable is a String (e.g., ""), unset, or not an object, stop immediately.
        if (!WindowManagerGui.HasProp("WinGui") || !IsObject(WindowManagerGui.WinGui))
            return

        static LastCtrlHwnd := 0

        ; Get the control under the mouse
        currCtrl := GuiCtrlFromHwnd(hwnd)

        ; Check if the control belongs to OUR specific GUI
        ; We added IsObject() here just to be double-safe
        if (currCtrl && IsObject(WindowManagerGui.WinGui) && currCtrl.Gui.Hwnd == WindowManagerGui.WinGui.Hwnd) {

            if (currCtrl.Hwnd != LastCtrlHwnd) {

                ; 1. Reset Previous Control (if it was ours)
                if (LastCtrlHwnd) {
                    try {
                        prevCtrl := GuiCtrlFromHwnd(LastCtrlHwnd)
                        if (prevCtrl && prevCtrl.Gui.Hwnd == WindowManagerGui.WinGui.Hwnd) {
                            ; Restore standard font/color
                            try prevCtrl.SetFont("Norm")
                            try prevCtrl.Opt("cThemeText") ; Use your theme variable if needed
                        }
                    }
                }

                ; 2. Highlight Current Control (Hover Effect)
                LastCtrlHwnd := currCtrl.Hwnd

                ; Only highlight buttons or text, not the background
                if (currCtrl.Type = "Button" || currCtrl.Type = "Text") {
                    try currCtrl.SetFont("Bold")
                    ; Optional: Change color if you want
                    ; try currCtrl.Opt("cBlue")
                }
            }
        }
        else {
            ; Mouse moved OFF our GUI entirely -> Reset last known control
            if (LastCtrlHwnd) {
                try {
                    prevCtrl := GuiCtrlFromHwnd(LastCtrlHwnd)
                    if (prevCtrl && IsObject(WindowManagerGui.WinGui) && prevCtrl.Gui.Hwnd == WindowManagerGui.WinGui.Hwnd) {
                        try prevCtrl.SetFont("Norm")
                    }
                }
                LastCtrlHwnd := 0
            }
        }
    }
}