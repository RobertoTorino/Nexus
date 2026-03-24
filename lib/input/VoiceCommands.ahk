#Requires AutoHotkey v2.0
; ==============================================================================
; * @description  VoiceCommands - Speech command recognizer (SAPI) for Nexus (v2).
; * @class VoiceCommands
; * Location: lib/input/VoiceCommands.ahk
; * @author Philip
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class VoiceCommands {
__New(logger := "", preferDirect := ["microphone (realtek", "microphone", "mic"], preferVM := ["voicemeeter out b1", "voicemeeter"]) {
    ; allow callers to omit a logger or accidentally pass a numeric HWND
    if !IsObject(logger)
        logger := Logger
    this.logger := logger
    this.map := Map()
    this.aliasMap := Map()
    this.listening := false
    this.debugHeard := false
    this.pttGraceMs := 500
    this._lastListenOffTick := 0
    this._lastAudioLevel := 0
    this._lastAudioTick := 0
    this._canSwitchInput := false
    this._lastLowConfidenceTipTick := 0
    this._lastHeardText := ""
    this._lastHeardTick := 0
    this.onUnmatched := ""
    this.commandFilter := ""
    this.onWhisperDone := ""
    this._whisperActive := false
    this._whisperPid := 0
    this._whisperTempFile := ""
    this._whisperStartTick := 0
    this._useWhisperOverride := ""  ; "" = read INI, "1" = forced on, "0" = forced off

    this.preferDirect := preferDirect
    this.preferVM := preferVM

    ; LAZY INIT PLACEHOLDERS
    this.reco := ""
    this.ctx  := ""
    this.gram := ""
    this.rule := ""
    this.state := ""
    this._null := ""
    this._initialized := false
}

    _InitSapi() {
        if this._initialized
            return

        ; Use in-process recognizer to avoid triggering Windows Speech setup UI.
        this.reco := ComObject("SAPI.SpInprocRecognizer")
        ; Keep explicit input switching disabled for stability/performance.
        this._canSwitchInput := false
        this.ctx  := this.reco.CreateRecoContext()
        this.gram := this.ctx.CreateGrammar(1)
        try this.ctx.EventInterests := -1

        this.gram.DictationSetState(1)

        rules := this.gram.Rules()
        this.rule := rules.Add("cmds", 0x1 | 0x20)
        this.rule.Clear()
        this.state := this.rule.InitialState()
        this._null := ComValue(13, 0)
        rules.Commit()

        ComObjConnect(this.ctx, this)

        this._initialized := true

        ; One-time direct mic bind (mirrors smoke-test behavior) without
        ; runtime cycling/fallback loops.
        this._BindConfiguredStartupInput()

        this.logger.Info("VoiceCommands: SAPI initialized.", "VoiceCommands")
    }

    ; PUBLIC API

    Add(phrase, fn) {
        this._InitSapi()

        p := this._NormalizePhrase(phrase)
        if (p = "")
            return

        this.map[p] := fn
        this.aliasMap[p] := p
        this.state.AddWordTransition(this._null, p)
    }

    AddSynonym(aliasPhrase, targetPhrase) {
        this._InitSapi()

        alias := this._NormalizePhrase(aliasPhrase)
        target := this._NormalizePhrase(targetPhrase)
        if (alias = "" || target = "")
            return false

        if !this.map.Has(target)
            return false

        this.aliasMap[alias] := target
        this.state.AddWordTransition(this._null, alias)
        return true
    }

    Commit() {
        this._InitSapi()

        this.gram.Rules().Commit()
        this.gram.CmdSetRuleState("cmds", 1)
        this.gram.DictationSetState(1)
    }

    Enable(on := true) {
        this._InitSapi()

        this.listening := !!on
        if !this.listening
            this._lastListenOffTick := A_TickCount
    }

    SetUnmatchedHandler(fn := "") {
        this.onUnmatched := fn
    }

    SetCommandFilter(fn := "") {
        this.commandFilter := fn
    }

    ; OPTIONAL VOICEMEETER SWITCHING:
    ; - on=true  => prefer Voicemeeter bus, fallback to direct mic
    ; - on=false => prefer direct mic, fallback to Voicemeeter
    UseVoicemeeter(on := true) {
    this._InitSapi()

        if !this._canSwitchInput {
            this.logger.Info("VoiceCommands: explicit device switching disabled.", "VoiceCommands")
            return false
        }

        wasOn := this.listening
        if wasOn
            this.Enable(false)

        ok := false
        if on {
            if !this._IsVoicemeeterRunning() {
                this.logger.Warn("VoiceCommands: Voicemeeter process not running; skipping Voicemeeter input switch.", "VoiceCommands")
                return false
            }
            ok := this._SelectFirstMatch(this.preferVM, "voicemeeter")
        } else {
            ok := this._SelectFirstMatch(this.preferDirect, "direct")
        }

        if wasOn
            this.Enable(true)

        return ok
    }

    LogSapiAudioInputs() {
        try {
            inputs := this.reco.GetAudioInputs()
        } catch as err {
            this.logger.Error("SAPI: GetAudioInputs failed: " err.Message, "VoiceCommands")
            return
        }

        this.logger.Info("SAPI audio inputs:", "VoiceCommands")
        idx := 0
        for token in inputs {
            idx++
            name := ""
            try {
                name := token.GetDescription()
            } catch {
                name := "(unknown)"
            }
            this.logger.Info(idx ". " name, "VoiceCommands")
        }
    }

    ; COM EVENT HANDLER
    ; USE VARIADIC SIGNATURE TO AVOID “TOO MANY PARAMETERS PASSED”
    Recognition(args*) {
        Result := ""
        confidence := 1.0
        try {
            ; In practice, SAPI recognition result is commonly at arg #4.
            if (args.Length >= 4)
                Result := args[4]
            if (!IsObject(Result) && args.Length >= 1)
                Result := args[args.Length]

            if !IsObject(Result)
                return

            heardRaw := Result.PhraseInfo.GetText()
            text := this._NormalizePhrase(heardRaw)
            confidence := this._GetRecognitionConfidence(Result)
            ; keep UI mic meter responsive even when audio-level COM paths are quiet
            this._lastAudioLevel := 70
            this._lastAudioTick := A_TickCount
        } catch {
            return
        }

        activeWindow := this.listening || (this._lastListenOffTick > 0 && (A_TickCount - this._lastListenOffTick) <= this.pttGraceMs)

        if !activeWindow
            return

        if this.debugHeard {
            isRuHeard := this._HasCyrillic(heardRaw) || this._HasCyrillic(text)
            this.logger.Info((isRuHeard ? "Heard [RU]: " : "Heard: ") heardRaw " => " text, "VoiceCommands")
        }

        this._DispatchText(text, heardRaw, confidence)
    }

    _DispatchText(text, heardRaw, confidence := 1.0) {
        ; Suppress identical phrase repeated within 800ms (handles SAPI event bursts).
        isRuText := this._HasCyrillic(text) || this._HasCyrillic(heardRaw)
        debounceMs := 800
        if (text = this._lastHeardText && (A_TickCount - this._lastHeardTick) < debounceMs) {
            if this.debugHeard
                this.logger.Info((isRuText ? "Debounced duplicate phrase [RU]: " : "Debounced duplicate phrase: ") text, "VoiceCommands")
            return
        }
        this._lastHeardText := text
        this._lastHeardTick := A_TickCount

        dbMode := false
        try dbMode := IsObject(GameDatabaseTool.MainGui)

        ; Deterministic DB mode routing: while DB is open, treat speech as
        ; DB intent (search/close), except explicit "database" reopen command.
        if dbMode {
            isDatabaseCommand := (text = "database")
                || (this.aliasMap.Has(text) && this.aliasMap[text] = "database")

            ; Match close words as first token so multi-word SAPI phrases like
            ; "exit the" or "close it" still trigger DB close.
            ; Also resolve via aliasMap so multilingual exit aliases (esci, salir,
            ; quitter, закрыть, выйти, etc.) correctly close the DB instead of leaking to search.
            static closeWords := Map("close",1,"closes",1,"cloze",1,"clothes",1,"stop",1,"quit",1,"exit",1,"ext",1,"end",1,"those",1,"fermer",1,"chiudi",1,"cerrar",1,"関閉",1,"閉じる",1,"закрыть",1,"выход",1,"выйти",1,"стоп",1,"завершить",1)
            firstWord := StrSplit(text, " ")[1]
            closeIntent := closeWords.Has(firstWord)
                || (this.aliasMap.Has(firstWord) && this.aliasMap[firstWord] = "exit")
                || (this.aliasMap.Has(text) && this.aliasMap[text] = "exit")

            wakeRequired := this._DbRequireWakeWord()
            wakeWord := this._NormalizePhrase(this._DbWakeWord())
            hasWake := false
            if (wakeWord != "") {
                hasWake := (text = wakeWord)
                    || (SubStr(text, 1, StrLen(wakeWord) + 1) = wakeWord " ")
            }

            if this._DbUseConfidenceGate() {
                minConf := this._DbConfidenceMin()
                if (confidence < minConf) {
                    this._NotifyLowConfidence("DB", confidence, minConf)
                    if this.debugHeard
                        this.logger.Info((isRuText ? "DB mode ignored low confidence [RU]: " : "DB mode ignored low confidence: ") Round(confidence, 2), "VoiceCommands")
                    return
                }
            }

            if (wakeRequired && !hasWake && !closeIntent && !isDatabaseCommand) {
                if this.debugHeard
                    this.logger.Info((isRuText ? "DB mode ignored (missing wake word) [RU]: " : "DB mode ignored (missing wake word): ") text, "VoiceCommands")
                return
            }

            if closeIntent {
                isRuClose := this._HasCyrillic(firstWord) || this._HasCyrillic(text)
                try GameDatabaseTool.Hide()
                this.logger.Info(isRuClose ? "Voice DB close [RU]" : "Voice DB close", "VoiceCommands")
                return
            }

            if !isDatabaseCommand {
                phrase := Trim(heardRaw)
                if (phrase = "")
                    phrase := text

                query := StrLower(Trim(phrase))

                if (wakeRequired && wakeWord != "") {
                    qn := this._NormalizePhrase(query)
                    if (SubStr(qn, 1, StrLen(wakeWord) + 1) = wakeWord " ")
                        query := Trim(SubStr(query, StrLen(wakeWord) + 1))
                }

                hasPrefix := false
                try {
                    prefixes := VoiceCommandCatalog.GetSearchPrefixes()
                    for _, prefix in prefixes {
                        p := StrLower(Trim(prefix))
                        pLen := StrLen(p)
                        if (p != "" && StrLen(query) > pLen && SubStr(query, 1, pLen) = p) {
                            query := Trim(SubStr(query, pLen + 1))
                            hasPrefix := true
                            break
                        }
                    }
                }

                query := this._SanitizeDbQuery(query)

                if (this._DbRequireSearchPrefix() && !hasPrefix) {
                    if this.debugHeard
                        this.logger.Info((this._HasCyrillic(query) ? "DB mode ignored (missing search prefix) [RU]: " : "DB mode ignored (missing search prefix): ") query, "VoiceCommands")
                    return
                }

                if (hasPrefix && this._DbUseHybridStt()) {
                    sttQuery := this._RunHybridDbSttQuery()
                    if (sttQuery != "") {
                        query := this._SanitizeDbQuery(sttQuery)
                        if this.debugHeard
                            this.logger.Info((this._HasCyrillic(query) ? "DB hybrid STT query [RU]: " : "DB hybrid STT query: ") query, "VoiceCommands")
                    }
                }

                if !hasPrefix {
                    if this._IsLikelyNoisePhrase(query) {
                        if this.debugHeard
                            this.logger.Info((this._HasCyrillic(query) ? "DB mode noise ignored [RU]: " : "DB mode noise ignored: ") query, "VoiceCommands")
                        return
                    }

                    ; Block single-word action terms removed from command aliases
                    ; to prevent accidental launches—they would otherwise leak into DB search.
                    static dbActionBlock := Map("begin",1,"run",1,"play",1,"go",1,"launch",1,"start",1,"end",1,"load",1,"open",1)
                    if (!InStr(query, " ") && dbActionBlock.Has(query)) {
                        if this.debugHeard
                            this.logger.Info((this._HasCyrillic(query) ? "DB mode action-word suppressed [RU]: " : "DB mode action-word suppressed: ") query, "VoiceCommands")
                        return
                    }

                    if this.aliasMap.Has(query) || this.map.Has(query) {
                        if this.debugHeard
                            this.logger.Info((this._HasCyrillic(query) ? "DB mode command-like query ignored [RU]: " : "DB mode command-like query ignored: ") query, "VoiceCommands")
                        return
                    }
                }

                if (StrLen(query) >= 2) {
                    isRuQuery := this._HasCyrillic(query)
                    ok := false
                    try ok := GameDatabaseTool.VoiceSearch(query)
                    if ok
                        this.logger.Info((isRuQuery ? "Voice DB search [RU]: " : "Voice DB search: ") query, "VoiceCommands")
                    else
                        this.logger.Warn((isRuQuery ? "Voice DB search skipped [RU]: " : "Voice DB search skipped: ") query, "VoiceCommands")
                }

                if this.debugHeard
                    this.logger.Info((isRuText ? "DB mode phrase [RU]: " : "DB mode phrase: ") text, "VoiceCommands")
                return
            }
        }

        key := ""
        if this.map.Has(text)
            key := text
        else if this.aliasMap.Has(text)
            key := this.aliasMap[text]
        else {
            parts := StrSplit(text, A_Space)
            if (parts.Length >= 1 && this.map.Has(parts[1]))
                key := parts[1]
            else if (parts.Length >= 1 && this.aliasMap.Has(parts[1]))
                key := this.aliasMap[parts[1]]
        }

        if (key != "") {
            if this._GlobalUseConfidenceGate() {
                minConf := this._GlobalConfidenceMin()
                if (confidence < minConf) {
                    this._NotifyLowConfidence("Command", confidence, minConf)
                    if this.debugHeard
                        this.logger.Info((isRuText ? "Command ignored low confidence [RU]: " : "Command ignored low confidence: ") key " @" Round(confidence, 2), "VoiceCommands")
                    return
                }
            }

            if IsObject(this.commandFilter) {
                allow := true
                try allow := this.commandFilter(key, text, heardRaw)
                if !allow {
                    return
                }
            }

            this.logger.Info((isRuText ? "Command matched [RU]: " : "Command matched: ") key, "VoiceCommands")
            fn := this.map[key]
            SetTimer(ObjBindMethod(this, "_RunSafeCmd", fn, key), -1)
        } else {
            if IsObject(this.onUnmatched) {
                try this.onUnmatched(text, heardRaw)
            }
            if this.debugHeard
                this.logger.Info((isRuText ? "Unmatched phrase [RU]: " : "Unmatched phrase: ") text, "VoiceCommands")
        }
    }

    _RunSafeCmd(fn, key) {
        try fn()
        catch as ex
            this.logger.Warn("Command callback error [" key "]: " ex.Message, "VoiceCommands")
    }

    ; =========================================================================
    ; WHISPER COMMAND MODE
    ; =========================================================================

    IsWhisperMode() {
        if (this._useWhisperOverride != "")
            return (this._useWhisperOverride = "1")
        return (Trim(this._ReadIniSetting("VoiceUseWhisper", "0")) = "1")
    }

    SetWhisperMode(on) {
        this._useWhisperOverride := on ? "1" : "0"
        val := on ? "1" : "0"
        try IniWrite(val, ConfigManager.IniPath, "SETTINGS", "VoiceUseWhisper")
        if on {
            ; ensure SAPI is not actively listening when switching to Whisper
            if this.listening
                this.Enable(false)
        }
        this.logger.Info("Voice mode switched: " (on ? "Whisper" : "SAPI"), "VoiceCommands")
    }

    IsWhisperActive() {
        return this._whisperActive
    }

    TriggerWhisperCmd() {
        if this._whisperActive {
            this.logger.Info("Whisper already recording", "VoiceCommands")
            return
        }
        cmd := this._WhisperCmdCommand()
        if (cmd = "") {
            this.logger.Warn("VoiceWhisperCommand is empty", "VoiceCommands")
            return
        }
        this._whisperTempFile := A_Temp "\nexus_vc_" A_TickCount ".txt"
        this._whisperStartTick := A_TickCount
        this._whisperActive := true
        pid := 0
        try Run(A_ComSpec " /C " cmd " > " Chr(34) this._whisperTempFile Chr(34) " 2>NUL", , "Hide", &pid)
        catch as ex {
            this._whisperActive := false
            this.logger.Warn("Whisper launch failed: " ex.Message, "VoiceCommands")
            return
        }
        this._whisperPid := pid
        this.logger.Info("Whisper recording started", "VoiceCommands")
        SetTimer(ObjBindMethod(this, "_PollWhisperCmd"), 200)
    }

    _PollWhisperCmd() {
        if !this._whisperActive {
            SetTimer(ObjBindMethod(this, "_PollWhisperCmd"), 0)
            return
        }
        timeoutMs := this._WhisperTimeoutMs()
        if ((A_TickCount - this._whisperStartTick) > timeoutMs) {
            try ProcessClose(this._whisperPid)
            this._whisperActive := false
            this._whisperPid := 0
            SetTimer(ObjBindMethod(this, "_PollWhisperCmd"), 0)
            this.logger.Warn("Whisper cmd timeout", "VoiceCommands")
            try {
                if IsObject(this.onWhisperDone)
                    this.onWhisperDone("")
            }
            return
        }
        if ProcessExist(this._whisperPid)
            return
        SetTimer(ObjBindMethod(this, "_PollWhisperCmd"), 0)
        this._whisperActive := false
        this._whisperPid := 0
        whisperText := ""
        try {
            if FileExist(this._whisperTempFile) {
                whisperText := FileRead(this._whisperTempFile)
                try FileDelete(this._whisperTempFile)
            }
        }
        this._whisperTempFile := ""
        whisperText := Trim(whisperText)
        if (whisperText != "") {
            this.logger.Info((this._HasCyrillic(whisperText) ? "Whisper cmd heard [RU]: " : "Whisper cmd heard: ") whisperText, "VoiceCommands")
            normalized := this._NormalizePhrase(whisperText)
            this._DispatchText(normalized, whisperText, 1.0)
        } else {
            this.logger.Info("Whisper cmd: no speech detected", "VoiceCommands")
        }
        try {
            if IsObject(this.onWhisperDone)
                this.onWhisperDone(whisperText)
        }
    }

    _WhisperCmdCommand() {
        defaultCmd := "python " Chr(34) "{SCRIPT_DIR}\tools\stt\whisper_db_once.py" Chr(34) " --seconds 2 --model tiny"
        cmd := this._ReadIniSetting("VoiceWhisperCommand", defaultCmd)
        cmd := StrReplace(cmd, "{SCRIPT_DIR}", A_ScriptDir)
        return Trim(cmd)
    }

    _WhisperTimeoutMs() {
        raw := this._ReadIniSetting("VoiceWhisperTimeoutMs", "10000")
        ms := 10000
        try ms := Integer(raw)
        catch
            ms := 10000
        return ms
    }

    AudioLevel(args*) {
        try {
            lvl := (args.Length >= 3) ? Integer(args[3]) : Integer(args[args.Length])
            if (lvl < 0)
                lvl := 0
            else if (lvl > 100)
                lvl := 100
            this._lastAudioLevel := lvl
            this._lastAudioTick := A_TickCount
        } catch {
        }
    }

    ; GET MICROPHONE LEVEL (0-100)
    GetMicLevel() {
        if !this._initialized
            return 0

        level := 0

        try {
            if (this.reco) {
                ; Most reliable path observed in smoke test.
                raw := this.reco.Status.AudioStatus.AudioLevel
                level := this._NormalizeAudioLevel(raw)
            }
        } catch {
        }

        if (level <= 0) {
            try {
                if (this.reco) {
                    raw := this.reco.AudioLevel
                    level := this._NormalizeAudioLevel(raw)
                }
            } catch {
            }
        }

        if (level <= 0) {
            try {
                raw := this.ctx.Recognizer.AudioLevel
                level := this._NormalizeAudioLevel(raw)
            } catch {
            }
        }

        if (level <= 0) {
            if ((A_TickCount - this._lastAudioTick) <= 1500)
                level := this._lastAudioLevel
        }

        if (level < 0)
            level := 0
        else if (level > 100)
            level := 100

        return level
    }

    GetCurrentInputName() {
        if !this._initialized
            return ""

        try {
            if this.reco && this.reco.AudioInput {
                return this.reco.AudioInput.GetDescription()
            }
        } catch {
        }

        return ""
    }

    CycleAudioInput() {
        this._InitSapi()

        if !this._canSwitchInput
            return ""

        try {
            inputs := this.reco.GetAudioInputs()
        } catch as err {
            this.logger.Error("SAPI: GetAudioInputs failed: " err.Message, "VoiceCommands")
            return ""
        }

        names := []
        for token in inputs {
            desc := ""
            try desc := token.GetDescription()
            catch
                continue
            names.Push(desc)
        }

        if (names.Length = 0)
            return ""

        current := this.GetCurrentInputName()
        nextIdx := 1
        if (current != "") {
            for idx, name in names {
                if (name = current) {
                    nextIdx := idx + 1
                    break
                }
            }
            if (nextIdx > names.Length)
                nextIdx := 1
        }

        selected := names[nextIdx]
        if this._SelectFirstMatch([selected], "cycle")
            return selected

        ; Fallback: move ahead and try one more non-current name.
        for idx, name in names {
            if (name = selected || name = current)
                continue
            if this._SelectFirstMatch([name], "cycle/fallback")
                return name
        }

        this.logger.Warn("SAPI cycle: no switchable input found.", "VoiceCommands")
        return ""
    }

    _NormalizeAudioLevel(raw) {
        n := 0
        try n := Integer(raw)
        catch {
            try n := Round(raw)
            catch
                n := 0
        }

        ; Some SAPI paths report 0..100, others can report larger raw values.
        if (n > 100)
            n := Round(n / 655.35)

        if (n < 0)
            n := 0
        else if (n > 100)
            n := 100

        return n
    }

    ; INTERNALS

    _BindConfiguredStartupInput() {
        devName := ""
        try devName := IniRead(ConfigManager.IniPath, "CAPTURE", "AudioDeviceNormal", "")
        catch
            devName := ""

        if (devName != "") {
            if this._SelectFirstMatch([devName], "startup/config")
                return true
        }

        ; Minimal safe fallback: only microphone-like names.
        return this._SelectFirstMatch(["microphone", "headset microphone"], "startup/mic")
    }

    _ApplyStartupInputSelection() {
        this._LoadPreferredInputsFromIni()

        if this._SelectFirstMatch(this.preferDirect, "direct/startup")
            return true

        ; Generic fallback for systems where configured names don't match exactly.
        if this._SelectFirstMatch(["microphone", "mic", "headset microphone"], "direct/generic")
            return true

        ; Last resort: choose first non-voicemeeter/non-stereo-mix input.
        return this._SelectFirstAvailableNonVmInput("startup/default")
    }

    _LoadPreferredInputsFromIni() {
        iniPath := ""
        try iniPath := ConfigManager.IniPath
        catch
            iniPath := ""

        if (iniPath = "")
            return

        directName := ""
        vmName := ""
        try directName := IniRead(iniPath, "CAPTURE", "AudioDeviceNormal", "")
        try vmName := IniRead(iniPath, "CAPTURE", "AudioDeviceVoicemeeter", "")

        if (directName != "")
            this._PrependUniquePreference(this.preferDirect, directName)
        if (vmName != "")
            this._PrependUniquePreference(this.preferVM, vmName)
    }

    _PrependUniquePreference(arr, value) {
        v := StrLower(Trim(value))
        if (v = "")
            return

        for _, existing in arr {
            if (StrLower(Trim(existing)) = v)
                return
        }

        arr.InsertAt(1, value)
    }

    _SelectFirstMatch(substrList, label := "") {
        try {
            inputs := this.reco.GetAudioInputs()
        } catch as err {
            this.logger.Error("SAPI: GetAudioInputs failed: " err.Message, "VoiceCommands")
            return false
        }

        for _, sub in substrList {
            s := StrLower(Trim(sub))
            if (s = "")
                continue

            for token in inputs {
                name := ""
                try {
                    name := token.GetDescription()
                } catch {
                    continue
                }

                if InStr(StrLower(name), s) {
                    try {
                        this.reco.AudioInput := token
                        this.logger.Info("SAPI selected (" label "): " name, "VoiceCommands")
                        return true
                    } catch as err {
                        this.logger.Error("SAPI set AudioInput failed (" name "): " err.Message, "VoiceCommands")
                        return false
                    }
                }
            }
        }

        this.logger.Warn("SAPI: no match for " label " inputs. Keeping current/default input.", "VoiceCommands")
        return false
    }

    _SelectFirstAvailableInput(label := "") {
        try {
            inputs := this.reco.GetAudioInputs()
        } catch as err {
            this.logger.Error("SAPI: GetAudioInputs failed: " err.Message, "VoiceCommands")
            return false
        }

        for token in inputs {
            name := ""
            try name := token.GetDescription()
            catch
                name := "(unknown)"

            try {
                this.reco.AudioInput := token
                this.logger.Info("SAPI selected (" label "): " name, "VoiceCommands")
                return true
            } catch {
                continue
            }
        }

        this.logger.Warn("SAPI: no audio input token available for " label ".", "VoiceCommands")
        return false
    }

    _SelectFirstAvailableNonVmInput(label := "") {
        try {
            inputs := this.reco.GetAudioInputs()
        } catch as err {
            this.logger.Error("SAPI: GetAudioInputs failed: " err.Message, "VoiceCommands")
            return false
        }

        for token in inputs {
            name := ""
            try name := token.GetDescription()
            catch
                name := ""

            lower := StrLower(name)
            if InStr(lower, "voicemeeter") || InStr(lower, "stereo mix")
                continue

            try {
                this.reco.AudioInput := token
                this.logger.Info("SAPI selected (" label "): " name, "VoiceCommands")
                return true
            } catch {
                continue
            }
        }

        this.logger.Warn("SAPI: no non-voicemeeter audio input token available for " label ".", "VoiceCommands")
        return false
    }

    _IsVoicemeeterRunning() {
        return !!(ProcessExist("voicemeeter8.exe")
            || ProcessExist("voicemeeterpro.exe")
            || ProcessExist("voicemeeterbanana.exe")
            || ProcessExist("voicemeeter.exe"))
    }

    _NormalizePhrase(text) {
        t := StrLower(Trim(text))
        t := RegExReplace(t, "[^\p{L}\p{N} ]", " ")
        t := RegExReplace(t, "\s+", " ")
        return Trim(t)
    }

    _SanitizeDbQuery(text) {
        t := this._NormalizePhrase(text)
        if (t = "")
            return ""

        out := []
        stopWords := Map(
            "the", true,
            "a", true,
            "an", true,
            "and", true,
            "or", true,
            "to", true,
            "of", true,
            "in", true,
            "on", true,
            "for", true,
            "with", true,
            "is", true,
            "are", true,
            "was", true,
            "were", true,
            "that", true,
            "this", true,
            "these", true,
            "those", true,
            "using", true,
            "visit", true,
            "visited", true,
            "visiting", true,
            "news", true,
            "more", true,
            "than", true,
            "work", true,
            "live", true,
            "get", true,
            "gets", true
        )

        for _, token in StrSplit(t, A_Space) {
            tk := Trim(token)
            if (tk = "")
                continue
            if stopWords.Has(tk)
                continue
            out.Push(tk)
        }

        if (out.Length = 0)
            return ""

        joined := ""
        for i, item in out {
            if (i > 1)
                joined .= " "
            joined .= item
        }

        return joined
    }

    _IsLikelyNoisePhrase(text) {
        t := Trim(text)
        if (t = "")
            return true

        if RegExMatch(t, "^\d+$")
            return true

        parts := StrSplit(t, A_Space)
        if (parts.Length = 1 && StrLen(parts[1]) <= 2)
            return true

        return false
    }

    _HasCyrillic(text) {
        t := Trim(text)
        if (t = "")
            return false
        return !!RegExMatch(t, "[А-Яа-яЁё]")
    }

    _GetRecognitionConfidence(resultObj) {
        conf := -1.0
        try conf := resultObj.PhraseInfo.Rule.EngineConfidence
        catch {
            conf := -1.0
        }

        if (conf >= 0.0 && conf <= 1.0)
            return conf

        ; Fallback: average element confidence when available.
        try {
            elems := resultObj.PhraseInfo.Elements
            total := 0.0
            count := 0
            for el in elems {
                c := -1.0
                try c := el.EngineConfidence
                if (c >= 0.0 && c <= 1.0) {
                    total += c
                    count += 1
                }
            }
            if (count > 0)
                return total / count
        }

        ; Unknown confidence path: do not block recognition.
        return 1.0
    }

    _ReadIniSetting(key, fallback := "") {
        val := fallback
        try val := IniRead(ConfigManager.IniPath, "SETTINGS", key, fallback)
        return val
    }

    _DbUseHybridStt() {
        return (Trim(this._ReadIniSetting("VoiceDbHybridStt", "1")) = "1")
    }

    _DbHybridSttTimeoutMs() {
        raw := this._ReadIniSetting("VoiceDbHybridSttTimeoutMs", "7000")
        ms := 7000
        try ms := Integer(raw)
        if (ms < 1000)
            ms := 1000
        if (ms > 30000)
            ms := 30000
        return ms
    }

    _DbHybridSttCommand() {
        defaultCmd := "python " Chr(34) "{SCRIPT_DIR}\tools\stt\whisper_db_once.py" Chr(34) " --seconds 3 --model tiny"
        cmd := this._ReadIniSetting("VoiceDbHybridSttCommand", defaultCmd)
        cmd := StrReplace(cmd, "{SCRIPT_DIR}", A_ScriptDir)
        return Trim(cmd)
    }

    _RunHybridDbSttQuery() {
        cmd := this._DbHybridSttCommand()
        if (cmd = "")
            return ""

        timeoutMs := this._DbHybridSttTimeoutMs()
        out := ""
        err := ""

        try {
            shell := ComObject("WScript.Shell")
            exec := shell.Exec(A_ComSpec " /C " cmd)
            start := A_TickCount

            while (exec.Status = 0) {
                if ((A_TickCount - start) > timeoutMs) {
                    try exec.Terminate()
                    this.logger.Warn("DB hybrid STT timeout", "VoiceCommands")
                    return ""
                }
                Sleep(50)
            }

            try out := exec.StdOut.ReadAll()
            try err := exec.StdErr.ReadAll()
        } catch as ex {
            this.logger.Warn("DB hybrid STT failed: " ex.Message, "VoiceCommands")
            return ""
        }

        if (Trim(err) != "")
            this.logger.Warn("DB hybrid STT stderr: " Trim(err), "VoiceCommands")

        return Trim(out)
    }

    _DbRequireWakeWord() {
        return (Trim(this._ReadIniSetting("VoiceDbRequireWakeWord", "0")) = "1")
    }

    _DbWakeWord() {
        return this._ReadIniSetting("VoiceDbWakeWord", "nexus")
    }

    _DbUseConfidenceGate() {
        return (Trim(this._ReadIniSetting("VoiceDbUseConfidenceGate", "1")) = "1")
    }

    _DbConfidenceMin() {
        raw := this._ReadIniSetting("VoiceDbConfidenceMin", "0.45")
        v := 0.45
        try v := raw + 0.0
        if (v < 0.0)
            v := 0.0
        if (v > 1.0)
            v := 1.0
        return v
    }

    _GlobalUseConfidenceGate() {
        return (Trim(this._ReadIniSetting("VoiceUseConfidenceGate", "0")) = "1")
    }

    _GlobalConfidenceMin() {
        raw := this._ReadIniSetting("VoiceConfidenceMin", "0.40")
        v := 0.40
        try v := raw + 0.0
        if (v < 0.0)
            v := 0.0
        if (v > 1.0)
            v := 1.0
        return v
    }

    _NotifyLowConfidence(scope, confidence, threshold) {
        now := A_TickCount
        cooldown := 3000
        raw := this._ReadIniSetting("VoiceLowConfidenceTipCooldownMs", "3000")
        try cooldown := Integer(raw)
        if (cooldown < 0)
            cooldown := 0

        if ((now - this._lastLowConfidenceTipTick) < cooldown)
            return

        this._lastLowConfidenceTipTick := now
        msg := scope " low confidence ignored (" Round(confidence, 2) " < " Round(threshold, 2) ")"
        try DialogsGui.CustomTrayTip(msg)
        try GuiBuilder.SetVoiceStatus(msg)
    }

    _DbRequireSearchPrefix() {
        value := "1"
        try value := IniRead(ConfigManager.IniPath, "SETTINGS", "VoiceDbRequirePrefix", "0")
        return (Trim(value) = "1")
    }
}