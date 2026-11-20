; ============================================================
; chat-common.ahk - shared code for the chat helper scripts.
; Not run directly: chat-replies.ahk, chat-suggester.ahk and
; chat-improver.ahk #Include it.
;
; API key (user environment variable, restart the script after setting):
;   GEMINI_API_KEY      free key from aistudio.google.com/apikey  (preferred)
;   ANTHROPIC_API_KEY   Claude key
;   CHAT_PROVIDER       optional: "gemini" or "claude" to force one when both exist
; ============================================================
#Requires AutoHotkey v2.0

GEMINI_MODEL := "gemini-2.5-flash"
CLAUDE_MODEL := "claude-haiku-5-5"

; ---- popup state (shared by the two popup scripts) ----
global gPopup := ""          ; the popup Gui, or ""
global gTarget := 0          ; window that was active when the hotkey was pressed
global gOpenTick := 0
global gOpenTitle := ""
global gSeen := false        ; popup has had focus at least once
global gMiss := 0
global gPicks := []          ; texts reachable with number keys 1-6
global gPickFn := ""         ; called with the picked text
global gAutoCloseFn := ""    ; called when the popup closes by itself
global gBusy := false        ; a request is in flight

; ------------------------------------------------------------
; Small helpers
; ------------------------------------------------------------
Notify(text, ms := 1800) {
    ToolTip text
    SetTimer(ClearTip, -ms)
}

ClearTip() {
    ToolTip
}

ErrorBox(title, text) {
    ToolTip
    MsgBox text, title, "Iconx"
}

; The hotkey's own modifiers (Shift/Alt/Ctrl) must be released before we
; send Ctrl+C / Ctrl+V, otherwise the app sees e.g. Ctrl+Shift+Alt+C.
WaitModifiersUp() {
    for k in ["Shift", "Alt", "Ctrl", "LWin", "RWin"]
        KeyWait k, "T1"
}

; Copies the current selection. Returns the text ("" if nothing selected)
; and puts the user's original clipboard in `saved` so the caller can restore it.
GrabSelection(&saved) {
    WaitModifiersUp()
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    return ClipWait(0.6) ? A_Clipboard : ""
}

; Pastes `text` into the active window. If `restore` is given, the
; clipboard is put back afterwards; otherwise the text stays on the
; clipboard so Ctrl+V still works if the box was not focused.
PasteText(text, restore?) {
    A_Clipboard := text
    if !ClipWait(1) {
        if IsSet(restore)
            A_Clipboard := restore
        return false
    }
    WaitModifiersUp()
    Send "^v"
    if IsSet(restore) {
        Sleep 300   ; let the app read the clipboard before we replace it
        A_Clipboard := restore
    }
    return true
}

; ------------------------------------------------------------
; LLM call (Gemini or Claude, chosen by which key is set)
; ------------------------------------------------------------
GetProvider() {
    gem := EnvGet("GEMINI_API_KEY")
    cla := EnvGet("ANTHROPIC_API_KEY")
    pref := StrLower(EnvGet("CHAT_PROVIDER"))
    if (pref = "claude" && cla != "")
        return "claude"
    if (pref = "gemini" && gem != "")
        return "gemini"
    if (gem != "")
        return "gemini"
    if (cla != "")
        return "claude"
    return ""
}

; Returns the model's text reply, or throws Error(message).
Ask(systemText, userText) {
    global GEMINI_MODEL, CLAUDE_MODEL
    provider := GetProvider()
    if (provider = "")
        throw Error("No API key found.`nSet the user environment variable GEMINI_API_KEY (or ANTHROPIC_API_KEY), then restart this script.")

    if (provider = "gemini") {
        url := "https://generativelanguage.googleapis.com/v1beta/models/" GEMINI_MODEL ":generateContent"
        headers := Map("x-goog-api-key", EnvGet("GEMINI_API_KEY"))
        ; thinkingBudget 0 = no hidden "thinking" pass, much faster for short chat replies
        body := '{"systemInstruction":{"parts":[{"text":"' JsonEscape(systemText) '"}]},'
            . '"contents":[{"role":"user","parts":[{"text":"' JsonEscape(userText) '"}]}],'
            . '"generationConfig":{"thinkingConfig":{"thinkingBudget":0}}}'
    } else {
        url := "https://api.anthropic.com/v1/messages"
        headers := Map("x-api-key", EnvGet("ANTHROPIC_API_KEY"), "anthropic-version", "2023-06-01")
        body := '{"model":"' CLAUDE_MODEL '","max_tokens":800,"system":"' JsonEscape(systemText)
            . '","messages":[{"role":"user","content":"' JsonEscape(userText) '"}]}'
    }

    lastErr := "Unknown error"
    Loop 3 {
        try {
            resp := HttpPost(url, headers, body, &status)
        } catch as e {
            lastErr := "Network error: " e.Message
            Sleep 800
            continue
        }
        if (status = 200) {
            if !RegExMatch(resp, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
                throw Error("The model returned no text (the message may have been blocked).")
            return Trim(JsonUnescape(m[1]), " `t`r`n")
        }
        em := ""
        RegExMatch(resp, '"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &em)
        lastErr := "HTTP " status (em ? ": " JsonUnescape(em[1]) : "")
        if !(status = 429 || status = 500 || status = 503 || status = 529)
            break   ; not worth retrying (bad key, bad request...)
        Sleep 1200 * A_Index
    }
    throw Error(lastErr)
}

HttpPost(url, headers, body, &status) {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(5000, 5000, 15000, 40000)
    http.Open("POST", url, false)
    for k, v in headers
        http.SetRequestHeader(k, v)
    http.SetRequestHeader("content-type", "application/json")
    http.Send(body)
    status := http.Status
    return http.ResponseText
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r`n", "\n")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\n")
    s := StrReplace(s, "`t", "\t")
    if RegExMatch(s, "[\x00-\x1F]") {   ; any other control char would make the JSON invalid
        t := ""
        Loop Parse, s
            t .= (Ord(A_LoopField) < 32) ? Format("\u{:04x}", Ord(A_LoopField)) : A_LoopField
        s := t
    }
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
            case "b", "f": i += 2
            case '"': out .= '"', i += 2
            case "\": out .= "\", i += 2
            case "/": out .= "/", i += 2
            case "u": out .= Chr(Integer("0x" SubStr(s, i + 2, 4))), i += 6
            default: out .= n, i += 2
        }
    }
    return out
}

; ------------------------------------------------------------
; Popup support: placement, auto-close, number keys
; ------------------------------------------------------------
NormTitle(hwnd) {
    try t := WinGetTitle("ahk_id " hwnd)
    catch
        return ""
    return RegExReplace(t, "^\(\d+\)\s*")   ; ignore unread counters like "(2) "
}

; Work area (screen minus taskbar) of the monitor that contains point x,y.
WorkAreaAt(x, y, &l, &t, &r, &b) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (x >= ml && x < mr && y >= mt && y < mb) {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
}

; Shows the (already built) Gui `g` just above the message box of the
; target window and starts watching for "user went elsewhere".
; Calibrate the spot once with Ctrl+Alt+P (see chat-replies.ahk).
ShowPopupWindow(g) {
    global gPopup, gTarget, gOpenTick, gOpenTitle, gSeen, gMiss
    gPopup := g
    gOpenTitle := NormTitle(gTarget)
    gSeen := false
    gMiss := 0

    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " gTarget)
    } catch {
        wx := 100, wy := 100, ww := 800, wh := 600
    }
    ini := A_ScriptDir "\chat-popup.ini"
    relX := IniRead(ini, "pos", "relX", "")
    relB := IniRead(ini, "pos", "relBottom", "")
    if (relX != "" && relB != "") {
        nx := wx + relX - w // 2
        ny := wy + wh - relB - h - 8
    } else {
        nx := wx + (ww - w) // 2
        ny := wy + wh - h - 110
    }
    if (ny < wy)
        ny := wy + 20
    ; keep it fully on screen
    WorkAreaAt(wx + ww // 2, wy + wh // 2, &l, &t, &r, &b)
    nx := Max(l, Min(nx, r - w))
    ny := Max(t, Min(ny, b - h))

    g.Show("x" nx " y" ny)
    try WinActivate "ahk_id " g.Hwnd
    gOpenTick := A_TickCount
    SetTimer(CheckFocus, 300)
}

ClosePopup() {
    global gPopup, gPicks
    SetTimer(CheckFocus, 0)
    gPicks := []
    if (gPopup != "") {
        try gPopup.Destroy()
        gPopup := ""
    }
}

; Close when the user clicks outside the popup or switches tab/window.
CheckFocus() {
    global gPopup, gTarget, gOpenTick, gOpenTitle, gSeen, gMiss, gAutoCloseFn
    if (gPopup = "") {
        SetTimer(CheckFocus, 0)
        return
    }
    if (A_TickCount - gOpenTick < 1000)
        return   ; let the popup finish appearing
    active := WinExist("A")
    if (active = 0)
        return   ; focus is in transition
    if (active = gPopup.Hwnd) {
        gSeen := true   ; from now on, losing focus means "clicked outside"
        gMiss := 0
        return
    }
    if (!gSeen && NormTitle(gTarget) = gOpenTitle) {
        gMiss := 0
        return   ; popup never got focus and nothing changed: stay open
    }
    gMiss += 1
    if (gMiss < 2)
        return
    gMiss := 0
    ClosePopup()
    if (gAutoCloseFn != "")
        gAutoCloseFn.Call()
}

; Number keys 1-6 pick a suggestion while the popup is the active window.
; Call once from the script's startup code.
InitPopupKeys() {
    HotIf (*) => (gPopup != "" && WinActive("ahk_id " gPopup.Hwnd))
    Loop 6
        Hotkey(String(A_Index), PickN.Bind(A_Index))
    HotIf
}

PickN(n, *) {
    global gPicks, gPickFn
    if (n <= gPicks.Length && gPickFn != "")
        gPickFn.Call(gPicks[n])
}
