#Requires AutoHotkey v2.0
; ======================================================================
; * @description Handles game window resizing, positioning, styles, and stability.
; * @class WindowManager
; * @location lib/window/WindowManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ======================================================================

#Include ..\core\Logger.ahk
#Include ..\window\MonitorHelper.ahk
#Include ..\config\ConfigManager.ahk
#Include ..\ui\DialogsGui.ahk

class WindowManager {
    ; CONFIGURATION PRESETS
    static Presets := Map(
        "SizeFull", { Mode: "FullScreen" },
        "SizeWindowed", { Mode: "Windowed" },
        "SizeBorderless", { Mode: "Borderless" },
        "SizeHidden", { Mode: "Hidden" },
        "SizeMinimized", { Mode: "Minimized" },
        "SizeMaximized", { Mode: "Maximized" },
        "SizeRestored", { Mode: "Restored" },
        ; Resolutions - Standard
        "Size640x480", { Width: 640, Height: 480 },
        "Size800x600", { Width: 800, Height: 600 },
        "Size1024x768", { Width: 1024, Height: 768 },
        "Size1280x720", { Width: 1280, Height: 720 },
        "Size1366x768", { Width: 1366, Height: 768 },
        "Size1600x900", { Width: 1600, Height: 900 },
        "Size1920x1080", { Width: 1920, Height: 1080 },
        ; Resolutions - High / Ultrawide
        "Size1920x1200", { Width: 1920, Height: 1200 },
        "Size1920x1440", { Width: 1920, Height: 1440 },
        "Size2048x1152", { Width: 2048, Height: 1152 },
        "Size2048x1536", { Width: 2048, Height: 1536 },
        "Size2560x1440", { Width: 2560, Height: 1440 },
        "Size2560x1600", { Width: 2560, Height: 1600 },
        "Size2880x1800", { Width: 2880, Height: 1800 },
        "Size3840x2160", { Width: 3840, Height: 2160 },
        "Size5120x2880", { Width: 5120, Height: 2880 },
        "Size7680x4320", { Width: 7680, Height: 4320 },
        ; Complex Presets
        "SizeFakeFull1920", { Width: 1920, Height: 1080, Mode: "Borderless", Topmost: true },
        "SizeFitScreen", { Mode: "FitScreen" },
        "SizeOverscan", { Mode: "Overscan" }
    )

    ; State Tracking
    static IgnoreList := ""
    static TeknoLoaders := ""
    static LastKnownRect := { X: 0, Y: 0, W: 0, H: 0 }
    static ActiveGameExe := ""
    static ActiveGameHwnd := 0
    static ActiveGamePid := 0
    static ActiveGameId := ""
    static IsPaused := false
    static TargetMonitor := 0

    static __New() {
        this.IgnoreList := Map()
        this.IgnoreList.CaseSense := "Off"
        this.IgnoreList.Set(
            "explorer.exe", true, "searchui.exe", true, "shellexperiencehost.exe", true,
            "searchhost.exe", true, "startmenuexperiencehost.exe", true, "applicationframehost.exe", true,
            "taskmgr.exe", true, "cmd.exe", true, "conhost.exe", true, "lockapp.exe", true,
            "autohotkey64.exe", true, "autohotkey32.exe", true, "nexus.exe", true, "teknoparrotui.exe", true,
            "idea64.exe", true, "code.exe", true, "chrome.exe", true, "msedge.exe", true, "firefox.exe", true, "steam.exe", true
        )

        this.TeknoLoaders := Map()
        this.TeknoLoaders.CaseSense := "Off"
        this.TeknoLoaders.Set(
            "budgieloader.exe", true, "elfldr2.exe", true, "sdaemon.exe", true, "teknoparrot.exe", true,
            "parrotloader.exe", true, "openparrotloader.exe", true, "openparrotkonamiloader.exe", true,
            "openparrotloader64.exe", true, "dolphin.exe", true, "dolphinnogui.exe", true, "play.exe", true,
            "rpcs3.exe", true, "game.exe", true, "amauth.exe", true, "houseofthedead4.exe", true,
            "id6_dump_.exe", true, "id6_dump.exe", true, "bg4.exe", true, "soundvoltex.exe", true,
            "teknoparrotui.exe", true, "racing.exe", true
        )
    }

    static CheckForTeknoWindow() {
        try {
            hwnd := WinExist("A")
            if (!hwnd)
                return 0
            if (WinGetPID("ahk_id " hwnd) == ProcessExist())
                return 0
            processName := WinGetProcessName("ahk_id " hwnd)
            if (this.TeknoLoaders.Has(processName))
                return hwnd
            if (!this.IgnoreList.Has(processName)) {
                class := WinGetClass("ahk_id " hwnd)
                WinGetPos(, , &w, &h, "ahk_id " hwnd)
                if (w > 100 && h > 100 && class != "Shell_TrayWnd" && class != "ConsoleWindowClass" && class != "WorkerW") {
                    return hwnd
                }
            }
        }
        return 0
    }

    static RegisterGame(pid, gameId, targetMonitor := 0, knownExeName := "") {
        this.ActiveGameId := gameId
        this.TargetMonitor := targetMonitor
        Logger.Info("WinMgr: Registering Game [" gameId "] PID: " pid " EXE: " knownExeName)

        if (knownExeName != "")
            this.ActiveGameExe := knownExeName

        this.SetGameContext("ahk_pid " pid, targetMonitor)

        SetTimer () => this.ApplyGameSettings(), -500
        SetTimer () => this.ApplyGameSettings(), -2500
        SetTimer () => this.ApplyGameSettings(), -5000
    }

    static ApplyGameSettings() {
        hwnd := this.GetValidHwnd()
        if !hwnd {
            return
        }

        game := ConfigManager.Games.Has(this.ActiveGameId) ? ConfigManager.Games[this.ActiveGameId] : ""

        if (game && (Type(game) == "Map" ? game.Has("HasWindowProfile") : game.HasOwnProp("HasWindowProfile"))) {
            val := (k) => (Type(game) == "Map" ? game[k] : game.%k%)
            x := val("WinX"), y := val("WinY")
            w := val("WinW"), h := val("WinH")

            Logger.Info("WinMgr: Applying Saved Profile -> x" x " y" y " w" w " h" h)
            this.ApplyFakeFullscreen(hwnd, w, h, 0, {})
            WinMove(x, y, w, h, "ahk_id " hwnd)
            DialogsGui.CustomStatusPop("Saved Settings Applied")
        }
        else if (this.TargetMonitor > 0) {
            mon := MonitorHelper.GetMonitorGeometry(this.TargetMonitor)
            if mon
                this.ApplyFakeFullscreen(hwnd, mon.Width, mon.Height, this.TargetMonitor, {})
            DialogsGui.CustomStatusPop("Forced: Monitor " . this.TargetMonitor)
        }
        else {
            monIdx := MonitorHelper.GetMonitorIndexFromWindow(hwnd)
            mon := MonitorHelper.GetMonitorGeometry(monIdx)
            if mon
                this.ApplyFakeFullscreen(hwnd, mon.Width, mon.Height, monIdx, {})
            DialogsGui.CustomStatusPop("Default: Borderless")
        }
    }

    static SaveCurrentPosition() {
        hwnd := this.GetValidHwnd()
        if (!hwnd) {
            DialogsGui.CustomStatusPop("No Game Tracked")
            return
        }
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            Logger.Info("WinMgr: Saving Profile -> x" x " y" y " w" w " h" h)
            success := ConfigManager.UpdateGameWindowProfile(this.ActiveGameId, x, y, w, h)
            if (success)
                DialogsGui.CustomStatusPop("Position Saved! 💾")
        } catch {
            DialogsGui.CustomStatusPop("Error Saving")
        }
    }

    static CloseActiveGame() {
        if (this.ActiveGamePid > 0) {

            ; [SAFETY CHECK] Never kill critical system processes or the IDE
            try {
                pName := WinGetProcessName("ahk_pid " this.ActiveGamePid)
                if (this.IgnoreList.Has(pName)) {
                    Logger.Error("WinMgr: PREVENTED KILL of protected process: " pName)
                    this.ActiveGamePid := 0 ; Drop the dangerous lock
                    return
                }
            }

            try {
                exe := this.ActiveGameExe
                if (exe == "")
                    exe := WinGetProcessName("ahk_pid " this.ActiveGamePid)

                if (this.TeknoLoaders.Has(exe)) {
                    Logger.Info("WinMgr: Emulator detected (" exe "), performing ForceKillAll")
                    this.ForceKillAll()
                    DialogsGui.CustomStatusPop("Emulator Closed")
                    return
                }
            }
            try {
                if WinExist("ahk_pid " this.ActiveGamePid)
                    WinClose("ahk_pid " this.ActiveGamePid)
                else
                    ProcessClose(this.ActiveGamePid)
                DialogsGui.CustomStatusPop("Game Closed")
            } catch {
                ProcessClose(this.ActiveGamePid)
            }
            this.ActiveGamePid := 0
        }
    }

    static KillActiveGame() {
        this.ForceKillAll()
        DialogsGui.CustomStatusPop("⚠️ Hard Reset (All Games)")
        this.ActiveGamePid := 0
    }

    static ForceKillAll() {
        count := 0
        for exeName, _ in this.TeknoLoaders {
            ; [SAFETY] Ensure we never accidentally added a system app to TeknoLoaders
            if (this.IgnoreList.Has(exeName))
                continue

            if ProcessExist(exeName) {
                try {
                    ProcessClose(exeName)
                    count++
                    Logger.Info("WinMgr: Force killed " exeName)
                }
            }
        }

        ; Kill Active PID only if it's safe
        if (this.ActiveGamePid > 0 && ProcessExist(this.ActiveGamePid)) {
            try {
                pName := WinGetProcessName("ahk_pid " this.ActiveGamePid)
                if (!this.IgnoreList.Has(pName)) {
                    ProcessClose(this.ActiveGamePid)
                    count++
                }
            }
        }
        return count
    }

    static PauseMonitoring() {
        this.IsPaused := true
    }

    static ResumeMonitoring() {
        this.IsPaused := false
        Logger.Debug("WindowManager Resumed")
    }

    ; CORE PUBLIC API

    ; Set the active game context (UPDATED)
    static SetGameContext(identifier, forceTargetMonitor := 0) {
        this.ActiveGameHwnd := 0
        this.ActiveGamePid := 0

        Logger.Debug("WinMgr: Setting Context -> " identifier)

        if (identifier == "")
            return

        if InStr(identifier, "ahk_pid") {
            this.ActiveGamePid := Integer(StrReplace(identifier, "ahk_pid ", ""))

            try {
                exe := WinGetProcessName("ahk_pid " this.ActiveGamePid)
                if (exe != "")
                    this.ActiveGameExe := exe
            }
            this.ActiveGameHwnd := this.FindRealGameWindow("ahk_pid " this.ActiveGamePid)
        }
        else {
            this.ActiveGameExe := StrReplace(identifier, "ahk_exe ", "")
            this.ActiveGameHwnd := this.FindRealGameWindow("ahk_exe " this.ActiveGameExe)
            try this.ActiveGamePid := ProcessExist(this.ActiveGameExe)
        }

        if (this.ActiveGameHwnd && forceTargetMonitor > 0) {
            this.MoveToMonitor(forceTargetMonitor)
        }
        else if (forceTargetMonitor > 0 && this.ActiveGamePid > 0) {
            SetTimer(() => this.RetryMove(identifier, forceTargetMonitor), -1000)
        }

        return this.ActiveGameHwnd
    }

    ; [NEW HELPER] Retries finding the window after a delay
    static RetryMove(identifier, targetMonitor) {
        hwnd := this.FindRealGameWindow(identifier)
        if (hwnd) {
            this.ActiveGameHwnd := hwnd
            this.MoveToMonitor(targetMonitor)
            Logger.Info("Delayed Move Successful.")
        }
    }

    ; Apply a Preset
    static ApplyPreset(presetName, monitorIndex := 0) {
        if !this.Presets.Has(presetName)
            return

        hwnd := this.GetValidHwnd()
        if !hwnd
            return

        cfg := this.Presets[presetName]

        if (monitorIndex == 0)
            monitorIndex := MonitorHelper.GetMonitorIndexFromWindow(hwnd)

        if cfg.HasOwnProp("Mode") {
            this.ApplyMode(hwnd, cfg.Mode, monitorIndex, cfg)
        }
        else if cfg.HasOwnProp("Width") && cfg.HasOwnProp("Height") {
            this.ApplyFakeFullscreen(hwnd, cfg.Width, cfg.Height, monitorIndex, cfg)
        }
    }

    static Nudge(dx, dy, dw, dh, symmetric := false) {
        hwnd := this.GetValidHwnd()
        if !hwnd
            return

        WinGetPos(&x, &y, &w, &h, hwnd)

        newW := Max(200, w + dw)
        newH := Max(200, h + dh)
        newX := x + dx
        newY := y + dy

        if (symmetric) {
            if (dw != 0)
                newX := x - (dw // 2)
            if (dh != 0)
                newY := y - (dh // 2)
        }

        WinMove(newX, newY, newW, newH, hwnd)
        this.SaveState(hwnd)
    }

    ; Move to Monitor
    static MoveToMonitor(targetMonitorIndex) {
        hwnd := this.GetValidHwnd()
        if !hwnd
            return

        mon := MonitorHelper.GetMonitorGeometry(targetMonitorIndex)
        if !mon
            return

        WinGetPos(, , &w, &h, hwnd)
        newX := mon.Left + (mon.Width - w) // 2
        newY := mon.Top + (mon.Height - h) // 2

        WinMove(newX, newY, , , hwnd)
        this.SaveState(hwnd)
    }

    ; Force Focus (New Feature)
    static ForceFocus(hwnd) {
        if !WinExist("ahk_id " hwnd)
            return

        ; Restore if minimized
        if WinGetMinMax("ahk_id " hwnd) = -1
            WinRestore("ahk_id " hwnd)

        WinActivate("ahk_id " hwnd)

        ; Focus stealing workaround (Toggle AlwaysOnTop)
        WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        Sleep(50)
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)

        Logger.Info("Forced focus on HWND: " hwnd)
    }

    static ApplyMode(hwnd, mode, monitorIndex, options) {
        switch mode {
            case "FullScreen":
                WinRestore(hwnd)
                WinMaximize(hwnd)

            case "Windowed":
                WinSetStyle("+0xC00000", hwnd)
                WinSetStyle("+0x800000", hwnd)
                WinRestore(hwnd)

            case "Borderless":
                mon := MonitorHelper.GetMonitorGeometry(monitorIndex)
                if mon
                    this.ApplyFakeFullscreen(hwnd, mon.Width, mon.Height, monitorIndex, options)

            case "FitScreen":
                mon := MonitorHelper.GetMonitorGeometry(monitorIndex)
                if mon
                    this.ApplyFakeFullscreen(hwnd, mon.Width, mon.Height, monitorIndex, options)

            case "Overscan":
                mon := MonitorHelper.GetMonitorGeometry(monitorIndex)
                if mon {
                    w := mon.Width + 20
                    h := mon.Height + 20
                    newX := mon.Left - 10
                    newY := mon.Top - 10
                    this.ApplyFakeFullscreen(hwnd, w, h, monitorIndex, options)
                    WinMove(newX, newY, w, h, "ahk_id " hwnd)
                }

            case "Hidden":
                WinHide(hwnd)

            case "Restored":
                WinShow(hwnd)
                WinRestore(hwnd)

            case "Minimized":
                WinMinimize(hwnd)

            case "Maximized":
                WinMaximize(hwnd)
        }
    }

    static ApplyFakeFullscreen(hwnd, w, h, monitorIndex, options := {}) {
        if (w < 100 || h < 100) {
            Logger.Warn("WinMgr: Blocked apply of too-small size: " w "x" h)
            return
        }

        WinSetStyle("-0xC00000", hwnd)
        WinSetStyle("-0x800000", hwnd)
        WinSetStyle("-0x00040000", hwnd)

        this.DwmMarginFix(hwnd)

        targetMon := (monitorIndex > 0) ? monitorIndex : (this.TargetMonitor > 0 ? this.TargetMonitor : 0)

        if (targetMon > 0) {
            mon := MonitorHelper.GetMonitorGeometry(targetMon)
            if mon {
                newX := mon.Left + (mon.Width - w) // 2
                newY := mon.Top + (mon.Height - h) // 2
                WinMove(newX, newY, w, h, hwnd)
            }
        } else {
            WinMove(, , w, h, hwnd)
        }

        if options.HasOwnProp("Topmost") && options.Topmost
            WinSetAlwaysOnTop(1, hwnd)

        WinActivate(hwnd)
        WinShow(hwnd)
        this.SaveState(hwnd)
    }

    static GetValidHwnd() {
        if (this.ActiveGameHwnd && WinExist(this.ActiveGameHwnd)) {
            WinGetPos(, , &w, &h, "ahk_id " this.ActiveGameHwnd)
            if (w < 50 || h < 50) {
                Logger.Info("WinMgr: Dropping zombie window (Size: " w "x" h ")")
                this.ActiveGameHwnd := 0
            }
            else
                return this.ActiveGameHwnd
        } else {
            this.ActiveGameHwnd := 0
        }

        if (this.ActiveGamePid > 0 && !ProcessExist(this.ActiveGamePid)) {
            Logger.Warn("WinMgr: Tracked PID died: " this.ActiveGamePid)
            this.ActiveGamePid := 0
        }

        if (this.ActiveGamePid > 0) {
            this.ActiveGameHwnd := this.FindRealGameWindow("ahk_pid " this.ActiveGamePid)
        }

        if (!this.ActiveGameHwnd && this.ActiveGameExe != "") {
            this.ActiveGameHwnd := this.FindRealGameWindow("ahk_exe " this.ActiveGameExe)
            if (this.ActiveGameHwnd) {
                this.ActiveGamePid := WinGetPID("ahk_id " this.ActiveGameHwnd)
                Logger.Info("WinMgr: Re-acquired game via EXE scan -> PID " this.ActiveGamePid)
            }
        }
        return this.ActiveGameHwnd
    }

    ; [CRITICAL FIX] Removed the "Scan Everything" fallback.
    ; This method now ONLY returns windows that match the requested criteria.
    static FindRealGameWindow(winTitle) {
        prev := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        bestHwnd := 0
        bestScore := -99999

        ids := WinGetList(winTitle)

        ; Note: We removed the "if ids.Length == 0 -> WinGetList()" block.
        ; If we can't find the specific game window, we return 0.
        ; This prevents us from accidentally latching onto the IDE or Explorer.

        for this_id in ids {
            currentScore := 0

            title := WinGetTitle(this_id)
            cls := WinGetClass(this_id)
            style := WinGetStyle(this_id)
            WinGetPos(, , &w, &h, this_id)
            area := w * h

            if (InStr(title, "Play!") || InStr(title, "TeknoParrot") || InStr(title, "TK5"))
                currentScore += 5000

            if (style & 0x10000000)
                currentScore += 500
            else
                currentScore -= 100

            if (area > 500000)
                currentScore += 200
            else if (area < 2500)
                currentScore -= 5000

            if (cls = "ConsoleWindowClass" || cls = "D3DProxyWindow" || cls = "DIEmWin" || InStr(cls, "HwndWrapper") || cls = "CiceroUIWndFrame" || cls = "IME" || cls = "MSCTFIME UI")
                currentScore -= 10000
            if (title == "")
                currentScore -= 500

            ; Heuristic: Match Process Name
            try {
                procName := WinGetProcessName(this_id)
                if (this.ActiveGameExe != "" && procName = this.ActiveGameExe)
                    currentScore += 3000
            }

            if (currentScore > bestScore && currentScore > 0) {
                bestScore := currentScore
                bestHwnd := this_id
            }
        }
        DetectHiddenWindows(prev)
        return bestHwnd
    }

    static SaveState(hwnd) {
        WinGetPos(&x, &y, &w, &h, hwnd)
        this.LastKnownRect := { X: x, Y: y, W: w, H: h }
    }

    static DwmMarginFix(hwnd) {
        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 34, "int*", 0xFFFFFF, "int", 4)
            DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 35, "int*", 0xFFFFFF, "int", 4)
            margins := Buffer(16, 0)
            DllCall("dwmapi\DwmExtendFrameIntoClientArea", "ptr", hwnd, "ptr", margins)
        }
    }

    static ApplyHorizontalOverscan(extraPixels) {
        hwnd := this.GetValidHwnd()
        if !hwnd
            return

        monIdx := MonitorHelper.GetMonitorIndexFromWindow(hwnd)
        mon := MonitorHelper.GetMonitorGeometry(monIdx)
        if (!mon)
            return

        newW := mon.Width + extraPixels
        newH := mon.Height
        newX := mon.Left - (extraPixels // 2)
        newY := mon.Top

        try {
            WinSetStyle("-0xC00000", "ahk_id " hwnd)
            WinSetStyle("-0x800000", "ahk_id " hwnd)
            WinMove(newX, newY, newW, newH, "ahk_id " hwnd)
            WinSetAlwaysOnTop(1, "ahk_id " hwnd)
            WinSetAlwaysOnTop(0, "ahk_id " hwnd)
            this.SaveState(hwnd)
            Logger.Info("WinMgr: Applied H-Overscan: " extraPixels "px")
            if IsSet(DialogsGui)
                DialogsGui.CustomStatusPop("H-Overscan: +" . extraPixels . "px")
        } catch {
            Logger.Error("WinMgr: Overscan Failed")
        }
    }
}

class WindowStabilizer {
    static HookActive := false
    static Enable() {
        if this.HookActive
            return
        DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
        msgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
        OnMessage(msgNum, this.OnShellMessage.Bind(this))
        this.HookActive := true
    }

    static OnShellMessage(wParam, lParam, msg, hwnd) {
        ; wParam 4 = HSHELL_WINDOWACTIVATED
        ; wParam 32772 = HSHELL_RUDEAPPACTIVATED (Fullscreen apps)
        if (wParam == 4 || wParam == 32772) {
            ; lParam contains the HWND of the activated window
            this.Reapply(lParam)
        }
    }

    static Reapply(hwnd) {
        if (WindowManager.IsPaused)
            return

        ; Verify the activated window is actually our target game
        if (hwnd != WindowManager.ActiveGameHwnd)
            return

        ; Logic remains the same...
        rect := WindowManager.LastKnownRect
        if (rect.W == 0)
            return

        WinGetPos(&cX, &cY, &cW, &cH, hwnd)

        ; Added a tolerance check to prevent infinite loops
        if (Abs(cX - rect.X) > 10 || Abs(cY - rect.Y) > 10) {
            Logger.Debug("Window Snapback Detected. Correcting...")
            ; Use a bound function for the timer to ensure passing params works
            SetTimer(() => WinMove(rect.X, rect.Y, rect.W, rect.H, hwnd), -50)
        }
    }
}