#Requires AutoHotkey v2.0
; ==============================================================================
; Class: TeknoParrotLauncher
; Location: lib/emulator/types/TeknoParrotLauncher.ahk
; Description: Handles TeknoParrot launching.
;              - V1.2.09: Fixes EmulatorMap Crash & XML Parsing Logic
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\config\TeknoParrotManager.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\core\Logger.ahk

; --- INHERIT FROM EMULATORBASE ---
class TeknoParrotLauncher extends EmulatorBase {
    TpPid := 0

    static EmulatorMap := Map(
        "Play", "Play.exe", "ElfLdr2", "elfldr2.exe", "Sdaemon", "sdaemon.exe",
        "TeknoParrot", "TeknoParrot.exe", "ParrotLoader", "parrotloader.exe",
        "OpenParrot", "OpenParrotLoader.exe", "Lindbergh", "BudgieLoader.exe",
        "SegaTools", "BudgieLoader.exe", "RingEdge", "BudgieLoader.exe",
        "TypeX", "game.exe", "Nesica", "game.exe", "Dolphin", "Dolphin.exe"
    )

    Launch(gameObj) {
        this.GameId := gameObj.Id
        Logger.Info("TP Launcher: Starting sequence for " gameObj.Id, "TeknoParrotLauncher")

        Logger.Info("TP Launcher: Cleaning up old processes...", "TeknoParrotLauncher")
        WindowManager.ForceKillAll()
        Sleep(100)

        tpPath := TeknoParrotManager.GetPath()
        profileName := gameObj.HasProp("ProfileFile") ? gameObj.ProfileFile : ""

        if (!tpPath || !profileName) {
            Logger.Error("TP Launcher: Missing Path or Profile.")
            DialogsGui.CustomMsgBox("Error", "TeknoParrot path missing.")
            return false
        }

        SplitPath(tpPath, , &tpDir)
        profilePath := (InStr(profileName, "\")) ? profileName : tpDir "\UserProfiles\" profileName

        if !FileExist(profilePath) {
            Logger.Error("TP Launcher: XML Profile not found at " profilePath)
            DialogsGui.CustomMsgBox("Error", "XML not found:`n" profilePath)
            return false
        }

        gameInfo := this.ParseProfileXml(profilePath)

        ; Stop launch if the game executable doesn't exist
        if (gameInfo.Path != "" && !FileExist(gameInfo.Path)) {
            Logger.Error("TP Launcher: Game file missing at " gameInfo.Path)
            DialogsGui.CustomMsgBox("Launch Error", "The game file was not found:`n`n" gameInfo.Path)
            return false
        }

        expectedExe := gameInfo.Exe

        ; Fallback for Tekken if Regex failed
        if (expectedExe == "" && InStr(profileName, "tekken")) {
            Logger.Warn("TP Launcher: Applying Tekken fallback")
            expectedExe := "Play.exe"
        }

        Logger.Info("TP Launcher: Target Exe Resolved -> [" expectedExe "] (EmuType: " gameInfo.EmuType ")", "TeknoParrotLauncher")

        if (expectedExe != "") {
            WindowManager.SetGameContext("ahk_exe " . expectedExe, 1)
        }

        runCmd := Format('"{1}" --profile="{2}"', tpPath, profilePath)
        Logger.Debug("TP Launcher: Executing -> " runCmd)

        try {
            Run(runCmd, tpDir, "Min", &tpPid)
            this.TpPid := tpPid
            Logger.Info("TP Launcher: TeknoParrotUI started with PID " tpPid, "TeknoParrotLauncher")

            ; Start the popup killer
            SetTimer(this.NagScreenKiller.Bind(this), 500)
            SetTimer(() => SetTimer(this.NagScreenKiller.Bind(this), 0), -20000)

            Logger.Info("TP Launcher: Waiting for game process...", "TeknoParrotLauncher")

            ; This waits up to 45 seconds for the REAL game (e.g. BudgieLoader.exe) to appear
            realPid := this.WaitForGameProcess(expectedExe, tpPid, 45000)

            if (realPid) {
                this.Pid := realPid
                Logger.Info("TP Launcher: Game Process FOUND! PID: " realPid, "TeknoParrotLauncher")

                ; --- THE FIX: TRACK THE REAL PROCESS ---
                ; We pass the PID of the game (BudgieLoader), not the UI.
                ; This ensures ProcessManager watches the correct RAM usage.
                this.TrackProcess(realPid, gameInfo.Path, this.GameId)

                Sleep(2000) ; Give the game a moment to render

                ; Force Context
                WindowManager.SetGameContext("ahk_pid " realPid, 1)

                GuiBuilder.SetRecordingStatus(true)
                return true
            } else {
                Logger.Error("TP Launcher: Timeout waiting for [" expectedExe "]")
                DialogsGui.CustomTrayTip("Game process timed out.", 3)
                if ProcessExist(tpPid)
                    ProcessClose(tpPid)
                return false
            }
        } catch as err {
            Logger.Error("TP Launcher: Crash -> " err.Message)
            DialogsGui.CustomMsgBox("Launch Failure", err.Message)
            return false
        }
    }

    ; ... (Keep ParseProfileXml, WaitForGameProcess, and NagScreenKiller exactly as they were) ...
    ParseProfileXml(xmlPath) {
        try {
            content := FileRead(xmlPath)
            info := { Exe: "", Path: "", EmuType: "" }
            if RegExMatch(content, "i)<GamePath>\s*(.*?)\s*</GamePath>", &match)
                info.Path := Trim(match[1])
            if RegExMatch(content, "i)<ExecutableName>\s*(.*?)\s*</ExecutableName>", &match)
                info.Exe := Trim(match[1])
            if RegExMatch(content, "i)<EmulatorType>\s*(.*?)\s*</EmulatorType>", &match)
                info.EmuType := Trim(match[1])

            needsMapping := (SubStr(info.Exe, -4) = ".zip" || SubStr(info.Exe, -4) = ".rar" || info.Exe == "")
            if (needsMapping && TeknoParrotLauncher.EmulatorMap.Has(info.EmuType))
                info.Exe := TeknoParrotLauncher.EmulatorMap[info.EmuType]
            else if (info.EmuType = "Play")
                info.Exe := "Play.exe"

            return info
        } catch {
            return { Exe: "", Path: "", EmuType: "" }
        }
    }

    WaitForGameProcess(expectedExe, tpLauncherPid, timeoutMs) {
        startTime := A_TickCount
        while ((A_TickCount - startTime) < timeoutMs) {
            if (expectedExe != "" && ProcessExist(expectedExe))
                return ProcessExist(expectedExe)
            foundHwnd := WindowManager.CheckForTeknoWindow()
            if (foundHwnd) {
                return WinGetPID("ahk_id " foundHwnd)
            }
            Sleep(500)
        }
        return 0
    }

    NagScreenKiller() {
        if (!this.TpPid || !ProcessExist(this.TpPid))
            return
        try {
            for this_id in WinGetList("ahk_pid " this.TpPid) {
                title := WinGetTitle(this_id)
                txt := WinGetText(this_id)
                if (InStr(txt, "already be running") || title = "Question" || title = "Error") {
                    WinActivate(this_id), Sleep(50), Send("{Enter}")
                    continue
                }
                if (WinGetStyle(this_id) & 0x10000000) {
                    WinGetPos(, , &w, &h, this_id)
                    (w < 600 && h < 450) ? (WinActivate(this_id), Send("{Enter}")) : WinHide(this_id)
                }
            }
        }
    }

    Stop() {
        ; 1. Manually trigger the session end report because we are overriding Base.Stop()
        if IsSet(ProcessManager)
            ProcessManager.EndSession()

        ; 2. Nuke everything
        Logger.Info("TP Launcher: Stopping PID " this.Pid, "TeknoParrotLauncher")
        WindowManager.ForceKillAll()
        this.Pid := 0
        this.TpPid := 0
    }
}