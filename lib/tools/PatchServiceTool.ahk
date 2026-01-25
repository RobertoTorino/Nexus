#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Tool for Game Mode Switching (T6BR) and Permanent Patching.
; * @class PatchServiceTool
; * @location lib/tools/PatchServiceTool.ahk
; * @author Philip
; * @date 2026/01/18
; * @version 1.0.00
; ======================================================================

; --- DEPENDENCY IMPORTS ---
; None

class PatchServiceTool {
    ; PATCH DATABASE
    static KnownPatches := Map(
        "EBOOT.BIN", {
            Name: "Tekken 6 BR",
            Type: "MODE_SWITCH",
            Strategy: "FILE_SWAP",
            ; FIX: Set to filename only (No "USRDIR\") to prevent path doubling.
            ; This assumes EBOOT.BIN and VER.206 are in the SAME folder.
            TargetFile: "VER.206",
            PatchSourceDir: "t6br",
            ; INTEGRITY: Shared CRC for both regions (We distinguish by VER file)
            Integrity: Map(
                "0xC4C4B3D0", "SHARED_BINARY"
            ),
            ; VARIANTS: Unique CRCs determine the region
            Variants: Map(
                ; --- JP VARIANTS (Suffixes: T, G, O) ---
                "0x7A9D7676", { Label: "TEST MODE", Suffix: "T", Desc: "Settings & Config" },
                "0x6BB61A3F", { Label: "GAME MODE", Suffix: "G", Desc: "Play Mode" },
                "0x2AF4A61F", { Label: "ORIG MODE", Suffix: "O", Desc: "Original JP Backup" },
                ; --- CN VARIANTS (Suffixes: CNT, CNG, CNO) ---
                "0xF8FA8F76", { Label: "TEST MODE", Suffix: "CNT", Desc: "Settings & Config" },
                "0x619EDB21", { Label: "GAME MODE", Suffix: "CNG", Desc: "Play Mode" },
                "0x619EDB21", { Label: "ORIG MODE", Suffix: "CNO", Desc: "Original CN Backup" }
            )
        }
    )

    ; LEGACY SUPPORT (Crucial for Registrar)
    static IdentifyPatchableGame(filename, fullPath) {
        if (this.KnownPatches.Has(filename)) {
            return this.KnownPatches[filename]
        }
        return ""
    }

    ; DIAGNOSTICS (Smart Region Detection)
    static RunDiagnostics(gameObj, patchData) {
        result := { Integrity: "Unknown", CurrentState: "Unknown", DetectedRegion: "" }

        basePath := this.SafeGet(gameObj, "ApplicationPath")
        if (basePath == "")
            basePath := this.SafeGet(gameObj, "EbootIsoPath")

        ; Normalize Path
        basePath := StrReplace(basePath, "/", "\")
        SplitPath(basePath, , &baseDir)

        if IsSet(Logger)
            Logger.Debug("[PatchTool] Checking: " . basePath)

        ; --- CHECK TARGET FILE (VER.206) FIRST ---
        ; This is our most reliable indicator of region.
        targetPath := baseDir . "\" . patchData.TargetFile

        if FileExist(targetPath) {
            targetCRC := this.CalculateCRC32(targetPath)

            if (patchData.Variants.Has(targetCRC)) {
                variant := patchData.Variants[targetCRC]
                result.CurrentState := variant.Label

                ; DETECT REGION FROM SUFFIX
                if (InStr(variant.Suffix, "CN")) {
                    result.DetectedRegion := "CN"
                } else {
                    result.DetectedRegion := "JP"
                }
            } else {
                result.CurrentState := "Unknown (" . targetCRC . ")"
            }
        } else {
            result.CurrentState := "File Missing"
        }

        ; --- CHECK INTEGRITY (EBOOT.BIN) ---
        if FileExist(basePath) {
            size := FileGetSize(basePath)
            if (size < 50 * 1024 * 1024) {
                crc := this.CalculateCRC32(basePath)

                if (patchData.Integrity.Has(crc)) {
                    regionType := patchData.Integrity[crc]

                    if (regionType == "SHARED_BINARY") {
                        ; 1. Trust the VER file if we found one
                        if (result.DetectedRegion == "CN") {
                            result.Integrity := "CN Region (Verified)"
                        }
                        else if (result.DetectedRegion == "JP") {
                            result.Integrity := "JP Region (Verified)"
                        }
                        else {
                            ; 2. Fallback: Guess from Path/Name (Only if VER file is missing/unknown)
                            pathCheck := basePath
                            nameCheck := this.SafeGet(gameObj, "SavedName")
                            if (InStr(pathCheck, "CN") || InStr(nameCheck, "CN") || InStr(nameCheck, "China") || InStr(pathCheck, "001")) {
                                result.Integrity := "CN Region (Assumed)"
                                result.DetectedRegion := "CN"
                            } else {
                                result.Integrity := "JP Region (Assumed)"
                                result.DetectedRegion := "JP"
                            }
                        }
                    } else {
                        result.Integrity := regionType . " (Verified)"
                    }
                } else {
                    result.Integrity := "Unknown Version (" . crc . ")"
                }
            } else {
                result.Integrity := "Skipped (Large File)"
            }
        } else {
            result.Integrity := "File Not Found"
        }

        return result
    }

    ; ENTRY POINT & UI
    static OpenPatcher(gameObj, patchKey := "") {
        patchData := ""

        if (patchKey != "" && this.KnownPatches.Has(patchKey)) {
            patchData := this.KnownPatches[patchKey]
        }
        else {
            appFile := this.SafeGet(gameObj, "GameApplication")
            patchData := this.KnownPatches.Get(appFile, "")
        }

        if (!IsObject(patchData)) {
            DialogsGui.CustomMsgBox("Error", "Patch configuration not found.", 0x10)
            return
        }

        diag := this.RunDiagnostics(gameObj, patchData)

        if (patchData.Type == "MODE_SWITCH") {
            this.ShowModeSelectorGui(gameObj, patchData, diag)
        }
        else {
            MsgBox("Patcher UI coming soon...")
        }
    }

    static ShowModeSelectorGui(gameObj, patchData, diag) {
        this.SelectedVariant := ""

        ; Use Detected Region from RunDiagnostics
        isCn := (diag.DetectedRegion == "CN")

        g := Gui("+AlwaysOnTop -Caption +Border +Owner" . (IsSet(GuiBuilder) ? GuiBuilder.MainGui.Hwnd : ""), "Mode Selector")
        g.BackColor := "202020"
        g.SetFont("s10 cWhite", "Segoe UI")

        g.Add("Text", "x20 y15 w300 Bold Center", "LAUNCH MODE: " . patchData.Name)

        g.SetFont("s8 cGray")
        g.Add("Text", "x20 y+5 w300 Center", "Integrity: " . diag.Integrity)
        g.Add("Text", "x20 y+2 w300 Center", "Current Mode: " . diag.CurrentState)
        g.SetFont("s10 cWhite")

        y := 95

        for crc, info in patchData.Variants {
            isCnVariant := (SubStr(info.Suffix, 1, 2) == "CN")
            if (isCn != isCnVariant)
                continue

            isCurrent := (diag.CurrentState == info.Label)
            bgColor := isCurrent ? "Background006600" : "Background333333"

            g.SetFont("s10 Bold")
            btn := g.Add("Text", "x20 y" y " w300 h30 +0x200 Center +Border " bgColor, info.Label)
            btn.OnEvent("Click", this.MakeCallback(g, info.Suffix))

            g.SetFont("s8 cGray")
            g.Add("Text", "x20 y+0 w300 h15 Center Background222222", info.Desc)
            y += 55
        }

        g.SetFont("s10 cWhite")
        g.Add("Text", "x20 y" y + 10 " w300 h30 Center cGray", "Cancel").OnEvent("Click", (*) => g.Destroy())

        g.Show("w340")
        WinWaitClose(g.Hwnd)

        if (this.SelectedVariant != "") {
            this.ApplyFileSwap(gameObj, patchData, this.SelectedVariant)
        }
    }

    static MakeCallback(guiObj, suffix) {
        return (ctrl, *) => (this.SelectedVariant := suffix, guiObj.Destroy())
    }

    ; UTILITIES
static ApplyFileSwap(gameObj, patchData, suffix) {
        basePath := this.SafeGet(gameObj, "ApplicationPath")
        if (basePath == "")
            basePath := this.SafeGet(gameObj, "EbootIsoPath")

        basePath := StrReplace(basePath, "/", "\")
        SplitPath(basePath, , &baseDir)

        target := baseDir . "\" . patchData.TargetFile
        source := ConfigManager.RootDir . "\data\patches\" . patchData.PatchSourceDir . "\" . "VER.206" . suffix

        try {
            if !FileExist(source) {
                DialogsGui.CustomMsgBox("Error", "Source file missing:`n" . source, 0x10)
                return
            }
            if FileExist(target)
                FileDelete(target)

            FileCopy(source, target, 1)

            ; [FIXED] CustomTrayTip only accepts (Text, IconType).
            ; We merged the title "Mode Switched" into the text string.
            DialogsGui.CustomTrayTip("Mode Switched: " . suffix, 2)

        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Failed to switch mode:`n" . err.Message, 0x10)
        }
    }

    static SafeGet(gameObj, key) {
        if (Type(gameObj) == "Map") {
            return gameObj.Has(key) ? gameObj[key] : ""
        }
        return gameObj.HasProp(key) ? gameObj.%key% : ""
    }

    static CalculateCRC32(filePath) {
        try {
            f := FileOpen(filePath, "r")
            f.Pos := 0
            len := f.Length
            if (len > 0) {
                data := Buffer(len)
                f.RawRead(data, len)
                f.Close()
                return Format("0x{1:X}", DllCall("ntdll\RtlComputeCrc32", "UInt", 0, "Ptr", data, "UInt", len, "UInt"))
            }
        }
        return "0x00000000"
    }
}