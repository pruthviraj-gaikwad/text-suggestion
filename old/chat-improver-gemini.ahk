#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Chat Improver - rewrites the message you are typing using Claude.
; Hotkey: Ctrl+Alt+R  (select text first, or leave nothing selected
;         and it will take everything in the current text box)
; Setup:  set a Windows user environment variable ANTHROPIC_API_KEY
;         (see README steps in chat), then restart this script.
; ============================================================

MODEL := "gemini-2.5-flash"
SYSTEM_PROMPT := "You rewrite draft chat messages for a workplace team chat (Google Chat). "
    . "Improve clarity, grammar and tone: friendly, professional, concise. Keep the original meaning, "
    . "language and any @mentions, links or names unchanged. Do not add greetings or sign-offs that were not there. "
    . "Reply with ONLY the improved message, no quotes, no explanation."

^!r:: ImproveSelection()

ImproveSelection() {
    apiKey := EnvGet("GEMINI_API_KEY")
    if (apiKey = "") {
        MsgBox "GEMINI_API_KEY environment variable is not set.", "Chat Improver", "Iconx"
        return
    }

    saved := ClipboardAll()
    text := CopySelection()
    if (Trim(text) = "") {
        ; nothing selected -> take the whole text box
        Send "^a"
        Sleep 80
        text := CopySelection()
    }
    if (Trim(text) = "") {
        A_Clipboard := saved
        ToolTip "No text found."
        SetTimer () => ToolTip(), -1500
        return
    }

    ToolTip "Improving message..."
    try {
        result := CallClaude(apiKey, text)
    } catch as e {
        ToolTip
        A_Clipboard := saved
        MsgBox "Request failed:`n" e.Message, "Chat Improver", "Iconx"
        return
    }
    ToolTip

    if (result = "") {
        A_Clipboard := saved
        return
    }
    A_Clipboard := result
    if !ClipWait(1) {
        A_Clipboard := saved
        return
    }
    Send "^v"
    Sleep 300
    A_Clipboard := saved
}

CopySelection() {
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.6)
        return ""
    return A_Clipboard
}

CallClaude(apiKey, userText) {
    global MODEL, SYSTEM_PROMPT
    body := '{"systemInstruction":{"parts":[{"text":"' JsonEscape(SYSTEM_PROMPT)
        . '"}]},"contents":[{"role":"user","parts":[{"text":"' JsonEscape(userText) '"}]}]}'

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(5000, 5000, 15000, 30000)
    http.Open("POST", "https://generativelanguage.googleapis.com/v1beta/models/" MODEL ":generateContent", false)
    http.SetRequestHeader("x-goog-api-key", apiKey)
    http.SetRequestHeader("content-type", "application/json")
    http.Send(body)

    resp := http.ResponseText
    if (http.Status != 200) {
        RegExMatch(resp, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &em)
        throw Error("HTTP " http.Status (IsSet(em) ? ": " JsonUnescape(em[1]) : ""))
    }
    if !RegExMatch(resp, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
        throw Error("Could not read the response.")
    return Trim(JsonUnescape(m[1]), " `t`r`n")
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r`n", "\n")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

JsonUnescape(s) {
    out := ""
    i := 1
    len := StrLen(s)
    while (i <= len) {
        c := SubStr(s, i, 1)
        if (c != "\") {
            out .= c
            i++
            continue
        }
        n := SubStr(s, i + 1, 1)
        switch n {
            case "n": out .= "`n", i += 2
            case "t": out .= "`t", i += 2
            case "r": i += 2
            case '"': out .= '"', i += 2
            case "\": out .= "\", i += 2
            case "/": out .= "/", i += 2
            case "u": out .= Chr(Integer("0x" SubStr(s, i + 2, 4))), i += 6
            default: out .= n, i += 2
        }
    }
    ; chat boxes expect Enter-less line breaks; keep newlines as-is
    return out
}
