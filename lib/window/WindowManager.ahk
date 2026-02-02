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
        ; --- Basic States ---
        "SizeFull",       { Mode: "FullScreen" },
        "SizeWindowed",   { Mode: "Windowed" },
        "SizeBorderless", { Mode: "Borderless" },
        "SizeHidden",     { Mode: "Hidden" },
        "SizeMinimized",  { Mode: "Minimized" },
        "SizeMaximized",  { Mode: "Maximized" },
        "SizeRestored",   { Mode: "Restored" },
        "SizeTopmost",    { Mode: "Topmost" },
        "SizeTool",       { Mode: "ToolWindow" },
        "SizeLayered",    { Mode: "Layered" },
        "SizeNoActivate", { Mode: "NoActivate" },

        ; --- Standard Resolutions ---
        "Size640x480",    { Width: 640, Height: 480 },
        "Size800x600",    { Width: 800, Height: 600 },
        "Size1024x768",   { Width: 1024, Height: 768 },
        "Size1280x720",   { Width: 1280, Height: 720 },
        "Size1366x768",   { Width: 1366, Height: 768 },
        "Size1600x900",   { Width: 1600, Height: 900 },
        "Size1920x1080",  { Width: 1920, Height: 1080 },
        "Size1920x1200",  { Width: 1920, Height: 1200 },
        "Size1920x1440",  { Width: 1920, Height: 1440 },
        "Size2048x1152",  { Width: 2048, Height: 1152 },
        "Size2048x1536",  { Width: 2048, Height: 1536 },
        "Size2560x1440",  { Width: 2560, Height: 1440 },
        "Size2560x1600",  { Width: 2560, Height: 1600 },
        "Size3840x2160",  { Width: 3840, Height: 2160 },
        "Size7680x4320",  { Width: 7680, Height: 4320 },

        ; --- 1920x1080 Extended Variants ---
        "SizeBorderless1920",           { Width: 1920, Height: 1080, Mode: "Borderless" },
        "SizeBorderlessTopmost1920",    { Width: 1920, Height: 1080, Mode: "Borderless", Topmost: true },
        "SizeBorderlessTool1920",       { Width: 1920, Height: 1080, Mode: "Borderless", ToolWindow: true },
        "SizeBorderlessLayered1920",    { Width: 1920, Height: 1080, Mode: "Borderless", Layered: true, NoActivate: true },
        "SizeFakeFullAll1920",          { Width: 1920, Height: 1080, Mode: "Borderless", Topmost: true, Layered: true, ToolWindow: true, NoActivate: true },
        "SizeWindowedTopLayered1920",   { Width: 1920, Height: 1080, Mode: "Windowed", Topmost: true, Layered: true },

        ; --- 2560x1440 Extended Variants ---
        "SizeBorderless2560",           { Width: 2560, Height: 1440, Mode: "Borderless" },
        "SizeBorderlessTopmost2560",    { Width: 2560, Height: 1440, Mode: "Borderless", Topmost: true },
        "SizeBorderlessLayered2560",    { Width: 2560, Height: 1440, Mode: "Borderless", Layered: true, NoActivate: true },
        "SizeFakeFullAll2560",          { Width: 2560, Height: 1440, Mode: "Borderless", Topmost: true, Layered: true, ToolWindow: true, NoActivate: true },

        ; --- Utility & Complex ---
        "SizeFakeFull1920", { Width: 1920, Height: 1080, Mode: "Borderless", Topmost: true },
        "SizeFitScreen",    { Mode: "FitScreen" },
        "SizeOverscan",     { Mode: "Overscan" }
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

    ; Call this once in your main script's initialization (e.g., in WindowManager.__New())
    static StartGlobalWatcher() {
        SetTimer(() => this.AutoDetectAndApply(), 2000)
    }

    static AutoDetectAndApply() {
        ; If we aren't tracking a game, but the ConfigManager says one was just played...
        if (this.ActiveGameHwnd == 0 && ConfigManager.CurrentGameId != "") {
            hwnd := this.GetValidHwnd()
            if (hwnd) {
                Logger.Info("GlobalWatcher: Auto-detected active game window. Applying profile...", "WindowManager")
                this.ApplyGameSettings()
            }
        }
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

    static RegisterGame(pid, gameId, targetMonitor := 0, exeName := "") {
        this.ActiveGamePid := pid
        this.ActiveGameId := gameId
        this.ActiveGameExe := exeName

        Logger.Info("Registering Game: " . gameId, "WindowManager")

        ; Start the polling loop to wait for the visible window
        SetTimer(() => this.ApplyGameSettings(), -1000)
    }

    static ApplyGameSettings(isAuto := false) {
        hwnd := this.GetValidHwnd()
        if !hwnd {
            if (isAuto)
                SetTimer(() => this.ApplyGameSettings(true), -1000)
            return
        }

        targetId := (this.ActiveGameId != "") ? this.ActiveGameId : ConfigManager.CurrentGameId
        game := ConfigManager.Games.Has(targetId) ? ConfigManager.Games[targetId] : ""

        if (game && (Type(game) == "Map" ? game.Has("HasWindowProfile") : game.HasOwnProp("HasWindowProfile"))) {
            val := (k) => (Type(game) == "Map" ? game[k] : game.%k%)

            Logger.Info("WinMgr: Profile found for [" . targetId . "]. Applying to HWND: " . hwnd, "WindowManager")

            if (isAuto) {
                Logger.Debug("WinMgr: Auto-load detected. Sleeping 1.8s for GPU sync...", "WindowManager")
                Sleep(1800) ; Increased for Dolphin Vulkan initialization
            }

            ; Apply Styles & Move
            WinSetStyle("-0xC00000", "ahk_id " hwnd)
            WinSetStyle("-0x800000", "ahk_id " hwnd)

            x := val("WinX"), y := val("WinY"), w := val("WinW"), h := val("WinH")
            Logger.Debug("WinMgr: Moving to " x "," y " (" w "x" h ")", "WindowManager")
            WinMove(x, y, w, h, "ahk_id " hwnd)

            ; Force DWM Refresh
            WinSetAlwaysOnTop(1, "ahk_id " hwnd)
            Sleep(100)
            WinSetAlwaysOnTop(0, "ahk_id " hwnd)

            ; Only show popup on manual clicks to avoid confusion
            if (!isAuto) {
                SoundPlay("*64")
                DialogsGui.CustomStatusPop("Layout Forced")
            }
        } else {
            Logger.Warn("WinMgr: Target window found, but no saved profile exists in JSON for " . targetId, "WindowManager")
        }
    }

    static SaveCurrentPosition() {
        hwnd := this.GetValidHwnd()
        if (!hwnd) {
            DialogsGui.CustomStatusPop("No Window Detected")
            return
        }

        ; FALLBACK: If ActiveGameId is lost, grab it from the ConfigManager's last known game
        if (this.ActiveGameId == "")
            this.ActiveGameId := ConfigManager.CurrentGameId

        if (this.ActiveGameId == "") {
            DialogsGui.CustomStatusPop("Error: No Game ID Linked")
            return
        }

        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            ; This call performs the JSON write
            success := ConfigManager.UpdateGameWindowProfile(this.ActiveGameId, x, y, w, h)
            if (success)
                DialogsGui.CustomStatusPop("Position Saved to JSON! 💾")
            else
                DialogsGui.CustomStatusPop("JSON Write Failed")
        } catch {
            DialogsGui.CustomStatusPop("Error during Save")
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
                    Logger.Info("WinMgr: Emulator detected (" exe "), performing ForceKillAll", "WindowManager")
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
                    Logger.Info("WinMgr: Force killed " exeName, "WindowManager")
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
            Logger.Info("Delayed Move Successful.", "WindowManager")
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

        Logger.Info("Forced focus on HWND: " hwnd, "WindowManager")
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

            case "Topmost":
                WinSetAlwaysOnTop(-1, hwnd) ; Toggle

            case "ToolWindow":
                WinSetExStyle("^0x00000080", hwnd) ; Toggle WS_EX_TOOLWINDOW

            case "Layered":
                WinSetExStyle("^0x00080000", hwnd) ; Toggle WS_EX_LAYERED

            case "NoActivate":
                WinSetExStyle("^0x08000000", hwnd) ; Toggle WS_EX_NOACTIVATE
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

; --- Handle Multiple Attributes ---
        if options.HasOwnProp("Topmost")
            WinSetAlwaysOnTop(options.Topmost ? 1 : 0, hwnd)

        if options.HasOwnProp("ToolWindow")
            WinSetExStyle(options.ToolWindow ? "+0x00000080" : "-0x00000080", hwnd)

        if options.HasOwnProp("Layered")
            WinSetExStyle(options.Layered ? "+0x00080000" : "-0x00080000", hwnd)

        if options.HasOwnProp("NoActivate")
            WinSetExStyle(options.NoActivate ? "+0x08000000" : "-0x08000000", hwnd)

        WinActivate(hwnd)
        WinShow(hwnd)
        this.SaveState(hwnd)
    }

    static GetValidHwnd() {
        ; Force visibility check
        prev := A_DetectHiddenWindows
        DetectHiddenWindows(false)

        hwnd := 0
        ; 1. Try existing Handle (if it's still visible)
        if (this.ActiveGameHwnd && WinExist("ahk_id " this.ActiveGameHwnd)) {
            hwnd := this.ActiveGameHwnd
        }
        ; 2. Try Global Active Process Name
        else if (ConfigManager.ActiveProcessName != "") {
            hwnd := this.FindRealGameWindow("ahk_exe " . ConfigManager.ActiveProcessName)
        }
        ; 3. Fallback to internal PID
        else if (this.ActiveGamePid > 0) {
            hwnd := this.FindRealGameWindow("ahk_pid " this.ActiveGamePid)
        }

        DetectHiddenWindows(prev)

        if (hwnd) {
            this.ActiveGameHwnd := hwnd
            ; Sync the ID if missing
            if (this.ActiveGameId == "")
                this.ActiveGameId := ConfigManager.CurrentGameId
        }

        return hwnd
    }

    ; [CRITICAL FIX] Removed the "Scan Everything" fallback.
    ; This method now ONLY returns windows that match the requested criteria.
    static FindRealGameWindow(winTitle) {
        ; Force hidden windows OFF for this search
        prev := A_DetectHiddenWindows
        DetectHiddenWindows(false)

        bestHwnd := 0
        bestScore := -99999

        ; This now ONLY retrieves visible windows matching the title/exe/pid
        ids := WinGetList(winTitle)

        for this_id in ids {
            title := WinGetTitle(this_id)
            cls := WinGetClass(this_id)
            WinGetPos(, , &w, &h, this_id)
            area := w * h

            ; Start with a base score
            currentScore := 100

            ; Filter out system "visible" windows that have no size or title
            if (title == "" || area < 10000) {
                currentScore -= 5000
                continue
            }

            ; Ignore common system/utility classes that are technically visible
            if (cls = "ConsoleWindowClass" || cls = "IME" || cls = "MSCTFIME UI")
                continue

            ; Heuristic: Bigger windows (the game) score higher
            currentScore += (area // 1000)

            if (currentScore > bestScore) {
                bestScore := currentScore
                bestHwnd := this_id
            }
        }

        if (bestHwnd)
            Logger.Info("WinMgr: Target acquired (Visible Only): " WinGetTitle(bestHwnd) " | Class: " WinGetClass(bestHwnd), "WindowManager")
        else
            Logger.Warn("WinMgr: Search failed. No visible window matches: " winTitle)

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

        ; Call the private helper to apply AND save
        this._ExecuteOverscan(hwnd, newX, newY, newW, newH, "Horizontal", extraPixels)
    }

    static ApplyVerticalOverscan(extraPixels) {
        hwnd := this.GetValidHwnd()
        if !hwnd
        return

        monIdx := MonitorHelper.GetMonitorIndexFromWindow(hwnd)
        mon := MonitorHelper.GetMonitorGeometry(monIdx)
        if (!mon)
        return

        WinGetPos(, , &w, , "ahk_id " hwnd)
        newW := w
        newH := mon.Height + extraPixels
        newX := mon.Left + (mon.Width - w) // 2
        newY := mon.Top - (extraPixels // 2)

        ; Call the private helper to apply AND save
        this._ExecuteOverscan(hwnd, newX, newY, newW, newH, "Vertical", extraPixels)
    }

    ; Private helper to handle the actual movement and JSON persistence
    static _ExecuteOverscan(hwnd, x, y, w, h, type, val) {
        try {
            ; 1. Apply Styles (remove borders/title bar)
            WinSetStyle("-0xC00000", "ahk_id " hwnd)
            WinSetStyle("-0x800000", "ahk_id " hwnd)

            ; 2. Move the window to the calculated overscan position
            WinMove(x, y, w, h, "ahk_id " hwnd)

            ; 3. Refresh DWM and internal state
            WinSetAlwaysOnTop(1, "ahk_id " hwnd)
            WinSetAlwaysOnTop(0, "ahk_id " hwnd)
            this.SaveState(hwnd)

            ; 4. PERSISTENCE FIX: Identify the target game ID
            ; Use the active tracking ID, or fallback to the last played game in the ConfigManager
            targetId := (this.ActiveGameId != "") ? this.ActiveGameId : ConfigManager.CurrentGameId

            if (targetId != "") {
                ; Update JSON via ConfigManager
                ConfigManager.UpdateGameWindowProfile(targetId, x, y, w, h)
                Logger.Info("WinMgr: " type "-Overscan saved to ID: " targetId, "WindowManager")

                if IsSet(DialogsGui)
                    DialogsGui.CustomStatusPop(type "-Overscan Saved")
            } else {
                Logger.Warn("WinMgr: Position applied but NOT saved - No Game ID identified.")
                if IsSet(DialogsGui)
                    DialogsGui.CustomStatusPop(type "-Overscan Applied (Not Saved)")
            }
        } catch as err {
            Logger.Error("WinMgr: Overscan Failed: " err.Message)
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