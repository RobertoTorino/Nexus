#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Optional beta authentication manager (backend token flow).
; * @class AuthManager
; * @location lib/security/AuthManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ============================================================================== 

; --- DEPENDENCY IMPORTS ---
#Include ..\core\Logger.ahk
#Include ..\core\JSON.ahk
#Include ..\config\ConfigManager.ahk
#Include SecureTokenStore.ahk

class AuthManager {
    static _Initialized := false
    static _TokenData := Map()
    static _AccessToken := ""
    static _ClockSkewSeconds := 60

    static IsEnabled() {
        return (this._ReadSetting("BetaAuthEnabled", "0") = "1")
    }

    static Init() {
        if !this.IsEnabled()
            return true
        if this._Initialized
            return true

        this._TokenData := SecureTokenStore.Load()
        this._AccessToken := this._TokenData.Has("access_token") ? this._TokenData["access_token"] : ""
        this._Initialized := true
        Logger.Info("AuthManager initialized.", "AuthManager")
        return true
    }

    static EnsureSession() {
        if !this.IsEnabled()
            return true

        this.Init()

        if this._HasValidAccessToken()
            return true

        if this._CanRefresh() {
            if this.RefreshSession()
                return true
        }

        inviteCode := Trim(this._ReadSetting("BetaAuthInviteCode", ""))
        if (inviteCode = "") {
            Logger.Warn("AuthManager: BetaAuthEnabled=1 but BetaAuthInviteCode is empty.", "AuthManager")
            return false
        }

        return this.RegisterDevice(inviteCode)
    }

    static GetAccessToken() {
        if !this.EnsureSession()
            return ""
        return this._AccessToken
    }

    static IsHealthCheckEnabled() {
        return (this._ReadSetting("BetaAuthHealthCheckOnStartup", "0") = "1")
    }

    static RunStartupHealthCheck() {
        if !this.IsEnabled() || !this.IsHealthCheckEnabled()
            return false

        endpoint := Trim(this._ReadSetting("BetaAuthHealthEndpoint", "/nexus/health"))
        if (endpoint = "")
            endpoint := "/nexus/health"

        result := this.RequestAuthorized("GET", endpoint)
        if result["ok"] {
            Logger.Info("Beta auth health check OK (" endpoint ").", "AuthManager")
            return true
        }

        Logger.Warn("Beta auth health check failed (" endpoint ") HTTP " result["status"], "AuthManager")
        return false
    }

    ; Performs an authenticated API request using the current access token.
    ; Returns: Map("ok", bool, "status", int, "text", str, "data", Map)
    static RequestAuthorized(method, endpoint, payload := "", retryOn401 := true) {
        if !this.EnsureSession()
            return Map("ok", false, "status", 0, "text", "", "data", Map())

        result := this._Request(method, endpoint, payload, this._AccessToken)

        if (retryOn401 && result["status"] = 401) {
            if this.RefreshSession()
                result := this._Request(method, endpoint, payload, this._AccessToken)
        }

        return result
    }

    ; Convenience helper for endpoints that return JSON { data: { ... } }.
    ; Returns empty Map() on failure.
    static GetAuthorizedJson(endpoint, method := "GET", payload := "", retryOn401 := true) {
        result := this.RequestAuthorized(method, endpoint, payload, retryOn401)
        if !result["ok"]
            return Map()
        return (Type(result["data"]) = "Map") ? result["data"] : Map()
    }

    static RegisterDevice(inviteCode := "") {
        code := Trim(inviteCode)
        if (code = "")
            return false

        payload := Map(
            "invite_code", code,
            "device_id", this.GetDeviceId(),
            "client", "nexus-ahk",
            "platform", "windows",
            "app_version", "1.0.00"
        )

        result := this._Request("POST", "/auth/register", payload)
        if !result["ok"] {
            Logger.Warn("Auth register failed. HTTP " result["status"], "AuthManager")
            return false
        }

        return this._StoreFromResponse(result["data"])
    }

    static RefreshSession() {
        if !this._CanRefresh()
            return false

        payload := Map(
            "refresh_token", this._TokenData["refresh_token"],
            "device_id", this.GetDeviceId()
        )

        result := this._Request("POST", "/auth/refresh", payload)
        if !result["ok"] {
            Logger.Warn("Auth refresh failed. HTTP " result["status"], "AuthManager")
            return false
        }

        return this._StoreFromResponse(result["data"])
    }

    static RevokeSession() {
        if !this.IsEnabled()
            return true

        token := this._TokenData.Has("refresh_token") ? this._TokenData["refresh_token"] : ""
        if (token != "") {
            payload := Map("refresh_token", token, "device_id", this.GetDeviceId())
            this._Request("POST", "/auth/revoke", payload)
        }

        this._TokenData := Map()
        this._AccessToken := ""
        return SecureTokenStore.Clear()
    }

    static GetDeviceId() {
        id := IniRead(ConfigManager.IniPath, "BETA", "DeviceId", "")
        if (id != "")
            return id

        id := this._GenerateGuid()
        if (id = "")
            id := "NEXUS-" A_ComputerName "-" A_UserName

        IniWrite(id, ConfigManager.IniPath, "BETA", "DeviceId")
        return id
    }

    static _GenerateGuid() {
        guidBin := Buffer(16, 0)
        if DllCall("Ole32\CoCreateGuid", "Ptr", guidBin, "Int") != 0
            return ""

        guidStr := Buffer(80, 0)
        if (DllCall("Ole32\StringFromGUID2", "Ptr", guidBin, "Ptr", guidStr, "Int", 39, "Int") <= 0)
            return ""

        raw := StrGet(guidStr)
        return Trim(raw, "{}")
    }

    static _ReadSetting(key, fallback := "") {
        try return IniRead(ConfigManager.IniPath, "SETTINGS", key, fallback)
        catch
            return fallback
    }

    static _HasValidAccessToken() {
        if (this._AccessToken = "")
            return false

        expiresAt := this._TokenData.Has("expires_at_unix") ? Integer(this._TokenData["expires_at_unix"]) : 0
        if (expiresAt <= 0)
            return true

        now := this._NowUnix()
        return (expiresAt - now > this._ClockSkewSeconds)
    }

    static _CanRefresh() {
        return (this._TokenData.Has("refresh_token") && Trim(this._TokenData["refresh_token"]) != "")
    }

    static _NowUnix() {
        return DateDiff("19700101000000", A_NowUTC, "Seconds")
    }

    static _StoreFromResponse(data) {
        if (Type(data) != "Map") {
            Logger.Warn("Auth response data was not a JSON object.", "AuthManager")
            return false
        }

        token := Map()
        for key in ["access_token", "refresh_token", "token_type", "scope", "beta_user_id"] {
            if data.Has(key)
                token[key] := data[key]
        }

        if data.Has("expires_at_unix") {
            token["expires_at_unix"] := Integer(data["expires_at_unix"])
        } else if data.Has("expires_in") {
            token["expires_at_unix"] := this._NowUnix() + Integer(data["expires_in"])
        }

        if !token.Has("access_token") {
            Logger.Warn("Auth response missing access_token.", "AuthManager")
            return false
        }

        this._TokenData := token
        this._AccessToken := token["access_token"]

        if !SecureTokenStore.Save(token) {
            Logger.Warn("Auth token acquired but failed to persist encrypted token store.", "AuthManager")
        }

        Logger.Info("Auth session established.", "AuthManager")
        return true
    }

    static _BuildUrl(endpoint) {
        ep := Trim(endpoint)
        if RegExMatch(ep, "i)^https?://")
            return ep

        base := Trim(this._ReadSetting("BetaAuthBaseUrl", ""))
        if (base = "")
            return ""

        return RTrim(base, "/") "/" LTrim(ep, "/")
    }

    static _Request(method, endpoint, payload := "", bearer := "") {
        result := Map("ok", false, "status", 0, "text", "", "data", Map())
        url := this._BuildUrl(endpoint)

        if (url = "") {
            Logger.Warn("AuthManager: BetaAuthBaseUrl is not configured.", "AuthManager")
            return result
        }

        body := ""
        if IsObject(payload)
            body := JSON.stringify(payload)
        else if (payload != "")
            body := String(payload)

        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.SetTimeouts(5000, 5000, 12000, 12000)
            req.Open(method, url, false)
            req.SetRequestHeader("Accept", "application/json")
            req.SetRequestHeader("Content-Type", "application/json")

            if (bearer != "")
                req.SetRequestHeader("Authorization", "Bearer " bearer)

            req.Send(body)
            status := req.Status
            text := req.ResponseText

            result["status"] := status
            result["text"] := text

            parsed := Map()
            try {
                parsedObj := JSON.parse(text, false, true)
                if (Type(parsedObj) = "Map")
                    parsed := parsedObj
            }

            if (status >= 200 && status < 300) {
                result["ok"] := true
                if (parsed.Has("data") && Type(parsed["data"]) = "Map")
                    result["data"] := parsed["data"]
                else
                    result["data"] := parsed
            }
        } catch as err {
            Logger.Warn("Auth request failed: " err.Message, "AuthManager")
        }

        return result
    }
}
