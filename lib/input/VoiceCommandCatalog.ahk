#Requires AutoHotkey v2.0
; ==============================================================================
; * @description  Voice command vocabulary catalog (canonical commands + aliases).
; * @class VoiceCommandCatalog
; * @location lib/input/VoiceCommandCatalog.ahk
; ==============================================================================

class VoiceCommandCatalog {
    static SupportedLanguages := ["EN", "CN", "JP", "IT", "ES", "FR", "RU"]
    static SearchPrefixes := [
        "search",      ; EN
        "searching",
        "find",        ; EN
        "lookup",
        "look up",
        "buscar",      ; ES
        "recherche",   ; FR
        "chercher",    ; FR
        "cerca",       ; IT
        "ricerca",     ; IT
        "搜索",         ; CN
        "搜",           ; CN
        "查找",         ; CN
        "検索",         ; JP
        "искать",       ; RU
        "поиск",        ; RU
        "найти"         ; RU
    ]

    static LogCatalog(logger := "") {
        if !IsObject(logger)
            logger := Logger

        aliases := this.GetAllAliases()
        logger.Info("Voice catalog loaded for languages: " . this._Join(this.SupportedLanguages), "VoiceCommands")
        logger.Info("Voice search prefixes: " . this._Join(this.GetSearchPrefixes()), "VoiceCommands")

        for command, words in aliases {
            logger.Info("Voice keywords [" command "]: " . this._Join(words), "VoiceCommands")
        }
    }

    static RegisterAll(voice, callbacks) {
        if !IsObject(voice) || !IsObject(callbacks)
            return

        allAliases := this.GetAllAliases()

        for command, fn in callbacks {
            voice.Add(command, fn)

            if !allAliases.Has(command)
                continue

            for _, alias in allAliases[command] {
                try voice.AddSynonym(alias, command)
            }
        }
    }

    static GetAllAliases() {
        merged := Map()

        for _, lang in this.SupportedLanguages {
            perLang := this.GetAliasesForLanguage(lang)
            for command, aliases in perLang {
                if !merged.Has(command)
                    merged[command] := []

                for _, alias in aliases
                    this._PushUnique(merged[command], alias)
            }
        }

        return merged
    }

    static GetAliasesForLanguage(langCode := "EN") {
        lang := StrUpper(Trim(langCode))

        if (lang = "CN")
            return this._CN()
        if (lang = "JP")
            return this._JP()
        if (lang = "IT")
            return this._IT()
        if (lang = "ES")
            return this._ES()
        if (lang = "FR")
            return this._FR()
        if (lang = "RU")
            return this._RU()

        return this._EN()
    }

    static GetSearchPrefixes() {
        prefixes := []
        for _, prefix in this.SearchPrefixes
            this._PushUnique(prefixes, prefix)
        return prefixes
    }

    static _EN() {
        return Map(
            "start", ["go", "launch", "start game"],
            "restart", ["reset", "reload", "relaunch", "retry"],
            "exit", ["quit", "end", "stop", "terminate"],
            "help", ["assist", "manual", "support", "question", "question mark", "help me", "halp",
                      "elder", "helped", "helpful", "helping", "health", "held", "hill"],
            "browser", ["explorer"],
            "database", ["db", "library", "data"],
            "gallery", ["photos"],
            "snapshot", ["snap", "photo", "capture"],
            "burst", ["rapid"],
            "focus", ["refocus"],
            "music", ["song"],
            "video", ["movie"]
        )
    }

    static _CN() {
        return Map(
            "start", ["开始"],
            "restart", ["重启"],
            "exit", ["退出"],
            "help", ["帮助"],
            "browser", ["浏览器"],
            "database", ["数据库", "资料库", "数据"],
            "gallery", ["画廊"],
            "snapshot", ["截图", "快照"],
            "burst", ["连拍"],
            "focus", ["聚焦"],
            "music", ["音乐"],
            "video", ["视频"]
        )
    }

    static _JP() {
        return Map(
            "start", ["開始"],
            "restart", ["再起動"],
            "exit", ["終了"],
            "help", ["ヘルプ"],
            "browser", ["ブラウザ"],
            "database", ["データベース", "でーたべーす", "db"],
            "gallery", ["ギャラリー"],
            "snapshot", ["スナップ"],
            "burst", ["連写"],
            "focus", ["フォーカス"],
            "music", ["音楽"],
            "video", ["ビデオ"]
        )
    }

    static _IT() {
        return Map(
            "start", ["avvia"],
            "restart", ["riavvia"],
            "exit", ["esci"],
            "help", ["aiuto"],
            "browser", ["esplora"],
            "database", ["database", "archivio", "dati", "bancadati", "banca dati"],
            "gallery", ["galleria"],
            "snapshot", ["istantanea"],
            "burst", ["raffica"],
            "focus", ["focus"],
            "music", ["musica"],
            "video", ["video"]
        )
    }

    static _ES() {
        return Map(
            "start", ["iniciar"],
            "restart", ["reiniciar"],
            "exit", ["salir"],
            "help", ["ayuda"],
            "browser", ["navegador"],
            "database", ["basedatos", "base de datos", "datos", "biblioteca"],
            "gallery", ["galeria", "galería"],
            "snapshot", ["captura"],
            "burst", ["rafaga", "ráfaga"],
            "focus", ["foco"],
            "music", ["musica", "música"],
            "video", ["video"]
        )
    }

    static _FR() {
        return Map(
            "start", ["demarrer", "démarrer"],
            "restart", ["redemarrer", "redémarrer"],
            "exit", ["quitter"],
            "help", ["aide"],
            "browser", ["navigateur"],
            "database", ["base", "base de donnees", "base de données", "donnees", "données", "bdd"],
            "gallery", ["galerie"],
            "snapshot", ["capture"],
            "burst", ["rafale"],
            "focus", ["focus"],
            "music", ["musique"],
            "video", ["video"]
        )
    }

    static _RU() {
        return Map(
            "start", ["старт", "запуск", "запусти", "начать", "поехали"],
            "restart", ["перезапуск", "перезапусти", "рестарт", "сброс"],
            "exit", ["выход", "выйти", "закрыть", "стоп", "завершить"],
            "help", ["помощь", "справка", "подсказка"],
            "browser", ["браузер", "проводник"],
            "database", ["база", "база данных", "бд", "данные", "библиотека"],
            "gallery", ["галерея", "фото"],
            "snapshot", ["снимок", "скриншот", "скрин"],
            "burst", ["серия", "очередь"],
            "focus", ["фокус"],
            "music", ["музыка", "песня"],
            "video", ["видео", "фильм"]
        )
    }

    static _PushUnique(arr, value) {
        v := Trim(value)
        if (v = "")
            return

        n := StrLower(v)
        for _, existing in arr {
            if (StrLower(existing) = n)
                return
        }

        arr.Push(v)
    }

    static _Join(items, sep := ", ") {
        out := ""
        for idx, value in items {
            if (idx > 1)
                out .= sep
            out .= value
        }
        return out
    }
}
