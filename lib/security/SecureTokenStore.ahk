#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Secure token storage using Windows DPAPI.
; * @class SecureTokenStore
; * @location lib/security/SecureTokenStore.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\core\Logger.ahk
#Include ..\core\JSON.ahk

class SecureTokenStore {
    static TokenPath := A_ScriptDir "\data\auth\beta_tokens.bin"

    static Save(tokenData) {
        try {
            this._EnsureDir()
            jsonText := JSON.stringify(tokenData)
            plain := Buffer(StrPut(jsonText, "UTF-8"), 0)
            StrPut(jsonText, plain, "UTF-8")

            encrypted := this._Protect(plain)
            if !IsObject(encrypted) {
                Logger.Error("SecureTokenStore: token encryption failed.", "SecureTokenStore")
                return false
            }

            f := FileOpen(this.TokenPath, "w")
            if !IsObject(f) {
                Logger.Error("SecureTokenStore: could not open token file for writing.", "SecureTokenStore")
                return false
            }
            f.RawWrite(encrypted, encrypted.Size)
            f.Close()
            return true
        } catch as err {
            Logger.Error("SecureTokenStore Save failed: " err.Message, "SecureTokenStore")
            return false
        }
    }

    static Load() {
        if !FileExist(this.TokenPath)
            return Map()

        try {
            sz := FileGetSize(this.TokenPath)
            if (sz <= 0)
                return Map()

            raw := Buffer(sz, 0)
            f := FileOpen(this.TokenPath, "r")
            if !IsObject(f)
                return Map()
            read := f.RawRead(raw, sz)
            f.Close()
            if (read != sz)
                return Map()

            decrypted := this._Unprotect(raw)
            if !IsObject(decrypted)
                return Map()

            jsonText := StrGet(decrypted, "UTF-8")
            if (Trim(jsonText) = "")
                return Map()

            parsed := JSON.parse(jsonText, false, true)
            return (Type(parsed) = "Map") ? parsed : Map()
        } catch as err {
            Logger.Warn("SecureTokenStore Load failed: " err.Message, "SecureTokenStore")
            return Map()
        }
    }

    static Clear() {
        try {
            if FileExist(this.TokenPath)
                FileDelete(this.TokenPath)
            return true
        } catch as err {
            Logger.Warn("SecureTokenStore Clear failed: " err.Message, "SecureTokenStore")
            return false
        }
    }

    static _EnsureDir() {
        targetDir := A_ScriptDir "\data\auth"
        if !DirExist(targetDir)
            DirCreate(targetDir)
    }

    static _Blob(ptrData, cbData) {
        blob := Buffer(A_PtrSize * 2, 0)
        NumPut("UInt", cbData, blob, 0)
        NumPut("Ptr", ptrData, blob, A_PtrSize)
        return blob
    }

    static _Protect(plainBuf) {
        inBlob := this._Blob(plainBuf.Ptr, plainBuf.Size)
        outBlob := this._Blob(0, 0)
        flags := 0x1 ; CRYPTPROTECT_UI_FORBIDDEN

        ok := DllCall("Crypt32\CryptProtectData"
            , "Ptr", inBlob
            , "Ptr", 0
            , "Ptr", 0
            , "Ptr", 0
            , "Ptr", 0
            , "UInt", flags
            , "Ptr", outBlob
            , "Int")

        if !ok
            return 0

        cb := NumGet(outBlob, 0, "UInt")
        pb := NumGet(outBlob, A_PtrSize, "Ptr")
        if (cb <= 0 || !pb)
            return 0

        out := Buffer(cb, 0)
        DllCall("Kernel32\RtlMoveMemory", "Ptr", out.Ptr, "Ptr", pb, "UPtr", cb)
        DllCall("Kernel32\LocalFree", "Ptr", pb)
        return out
    }

    static _Unprotect(encBuf) {
        inBlob := this._Blob(encBuf.Ptr, encBuf.Size)
        outBlob := this._Blob(0, 0)
        flags := 0x1 ; CRYPTPROTECT_UI_FORBIDDEN

        ok := DllCall("Crypt32\CryptUnprotectData"
            , "Ptr", inBlob
            , "Ptr*", 0
            , "Ptr", 0
            , "Ptr", 0
            , "Ptr", 0
            , "UInt", flags
            , "Ptr", outBlob
            , "Int")

        if !ok
            return 0

        cb := NumGet(outBlob, 0, "UInt")
        pb := NumGet(outBlob, A_PtrSize, "Ptr")
        if (cb <= 0 || !pb)
            return 0

        out := Buffer(cb, 0)
        DllCall("Kernel32\RtlMoveMemory", "Ptr", out.Ptr, "Ptr", pb, "UPtr", cb)
        DllCall("Kernel32\LocalFree", "Ptr", pb)
        return out
    }
}
