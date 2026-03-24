#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Clones specialized games and registers them in JSON.
; * @class CloneWizardTool
; * @location lib/tools/CloneWizardTool.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; ---- DEPENDENCY IMPORTS ----
#Include ..\core\Logger.ahk
#Include ..\config\ConfigManager.ahk
#Include ..\core\Utilities.ahk
#include ..\ui\DialogsGui.ahk

class CloneWizardTool {

    ; CONFIGURATION: VALID SOURCE HASHES
    ; Add the MD5 hashes of the EBOOT.BIN files you allow to be cloned.
    ; Use the FileValidatorTool to find these values first!
    static ValidSourceHashes := Map(
        ; MD5_HASH_HERE, Description
        "98340915d5211d5683e571a388b1d477", "Time Crisis Razing Storm",
        "6a768c7e09bcf4f2566d0b9f1346104f", "Tekken 6 (2007)",
        "6de14b54142ea4df3e450cbdafccbddb", "Tekken 6 Bloodline Rebellion (2008 - JP)",
        "2539ddb1731fb503ceed6247511d8913", "Tekken 6 Bloodline Rebellion (2008 - CN)",
        "6de14b54142ea4df3e450cbdafccbddb", "Tekken Tag Tournament 2 (2011)",
        "6de14b54142ea4df3e450cbdafccbddb", "Tekken Tag Tournament 2 Unlimited (2011)",
        "25ea4125f7d5119171c34d111d040ff5", "Dragon Ball Zenkai Battle Royale (2017)"
    )

    static CloneGame(sourceEboot, newId, friendlyName, buildType) {
        if !FileExist(sourceEboot)
            return false

        ; VALIDATION (NEW: HASH BASED)
        Logger.Info("Validating source file: " sourceEboot)

        ; Calculate hash synchronously
        fileHash := this.GetFileHash(sourceEboot, "MD5")

        if (fileHash == "") {
            Logger.Error("Validation Failed: Could not calculate hash.")
            return false
        }

        ; Check against Allowlist
        if (!this.ValidSourceHashes.Has(fileHash)) {
            Logger.Error("Validation Failed: Source EBOOT hash (" . fileHash . ") is not recognized.")

            ; Optional: Show User what happened
            ; Correct: Title, Message, Options (0x10 = Error Icon)
            DialogsGui.CustomMsgBox("Validation Failed", "The selected file is not a valid source.`n`nComputed MD5: " . fileHash, 0x10)
            return false
        }

        Logger.Info("Validation Passed: " . this.ValidSourceHashes[fileHash])

        ; PATH SETUP
        SplitPath(sourceEboot, &ebootName, &usrDir)
        SplitPath(usrDir, , &oldGameDir)
        SplitPath(oldGameDir, &oldId, &baseDir)

        newGameDir := baseDir . "\" . newId

        ; PHYSICAL CLONE
        try {
            DirCopy(oldGameDir, newGameDir)
        } catch as err {
            Logger.Error("Clone Failed: " err.Message)
            return false
        }

        ; SFO PATCH
        newSfo := newGameDir . "\PARAM.SFO"
        if !this.PatchSfoFile(newSfo, oldId, newId) {
            try DirDelete(newGameDir, true)
            return false
        }

        ; REGISTER IN JSON & INI
        cleanName := Utilities.SanitizeName(friendlyName)
        newPath := newGameDir . "\USRDIR\" . ebootName

        IniWrite(cleanName, ConfigManager.IniPath, "ReservedIDs", newId)
        ConfigManager.AddOrUpdateGame(friendlyName, newPath, buildType)

        Logger.Info("CloneWizardTool: Cloned " oldId " to " newId " as " cleanName)
        return newPath
    }

    ; HASH CALCULATION UTILITY (Synchronous)
    static GetFileHash(filePath, algo := "MD5") {
        try {
            ; Use CertUtil via Command Line (Hidden)
            tmpFile := A_Temp . "\nexus_hash_calc.tmp"
            if FileExist(tmpFile)
                FileDelete(tmpFile)

            cmd := Format('cmd /c certutil -hashfile "{1}" {2} > "{3}"', filePath, algo, tmpFile)
            RunWait(cmd, , "Hide")

            if !FileExist(tmpFile)
                return ""

            content := FileRead(tmpFile)
            FileDelete(tmpFile)

            ; CertUtil output format:
            ; Line 1: Algorithm info
            ; Line 2: The Hash <--- We want this
            ; Line 3: CertUtil completed

            hashVal := ""
            loop parse, content, "`n", "`r" {
                line := Trim(A_LoopField)
                ; Filter out headers/footers
                if (line != "" && !InStr(line, ":") && !InStr(line, "CertUtil")) {
                    hashVal := StrReplace(line, " ", "") ; Remove spaces if present
                    break
                }
            }
            return hashVal
        } catch as err {
            Logger.Error("Hash Calculation Failed: " . err.Message)
            return ""
        }
    }

    ; EXISTING HELPERS

    static GetFolderSize(path) {
        size := 0
        Loop Files, path . "\*.*", "R"
            size += A_LoopFileSize

        mb := size / 1024 / 1024
        if (mb > 1024)
            return Round(mb / 1024, 2) . " GB"
        return Round(mb, 0) . " MB"
    }

    static GetNextFreeId() {
        prefix := "SCEEXE"
        rpcs3Path := IniRead(ConfigManager.IniPath, "RPCS3_TEKKEN6BR", "Rpcs3SpecialPath", "")

        gamesDir := ""
        if (rpcs3Path != "") {
            SplitPath(rpcs3Path, , &rpcs3Dir)
            gamesDir := rpcs3Dir . "\dev_hdd0\game"
        }

        Loop 999 {
            suffix := Format("{:03}", A_Index)
            checkId := prefix . suffix

            folderExists := (gamesDir != "" && DirExist(gamesDir . "\" . checkId))
            iniValue := IniRead(ConfigManager.IniPath, "ReservedIDs", checkId, "")
            isReserved := (iniValue != "")

            if (!folderExists && !isReserved) {
                return checkId
            }
        }
        return "FULL"
    }

    static PatchSfoFile(filePath, findStr, replaceStr) {
        try {
            f := FileOpen(filePath, "rw")
            size := f.Length
            buf := Buffer(size)
            f.RawRead(buf, size)

            needle := Buffer(StrPut(findStr, "UTF-8") - 1)
            StrPut(findStr, needle, "UTF-8")
            replacement := Buffer(StrPut(replaceStr, "UTF-8") - 1)
            StrPut(replaceStr, replacement, "UTF-8")

            offset := 0
            patched := 0

            Loop size - needle.Size {
                match := true
                Loop needle.Size {
                    if (NumGet(buf, A_Index - 1 + offset, "UChar") != NumGet(needle, A_Index - 1, "UChar")) {
                        match := false
                        break
                    }
                }
                if (match) {
                    f.Pos := offset
                    f.RawWrite(replacement, replacement.Size)
                    patched++
                    offset += needle.Size
                    continue
                }
                offset++
            }
            f.Close()
            return (patched > 0)
        } catch {
            return false
        }
    }
}