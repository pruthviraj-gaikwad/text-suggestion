#Requires AutoHotkey v2.0
#SingleInstance Force
#Include chat-common.ahk

; ============================================================
; Chat Replies - quick-reply suggestions for a message someone sent you.
;   1. Select the message you received (or copy it with Ctrl+C).
;   2. Press Shift+Alt+2   (Ctrl+Alt+S also works).
;   3. A popup shows reply chips. Click one - or press its number key -
;      and it is pasted into the message box (it also stays on the
;      clipboard, so Ctrl+V works if the box was not focused).
; Ctrl+Alt+P  calibrates where the popup appears (see below).
; Keys: see chat-common.ahk (GEMINI_API_KEY or ANTHROPIC_API_KEY).
; ============================================================

PROMPT := "You suggest quick replies for a workplace team chat (Google Chat). "
    . "You are given a message the user RECEIVED. Write 6 short, natural reply options the user could send back "
    . "(max 8 words each), varied: positive, thanks, ask back, busy, catch up later, confirm. "
    . "Reply in the same language as the received message. "
    . "Output exactly 6 lines in the format: emoji|reply  (one fitting emoji, then a | character, then the reply). "
    . "No numbering, no quotes, no extra text."

global gSource := ""
global gShown := []

InitPopupKeys()
gPickFn := UseReply

+!2:: Start()
^!s:: Start()

; Calibrate: put the mouse pointer on the TOP EDGE of the message box
; (centre of it), press Ctrl+Alt+P. Popups will then sit right above it.
^!p:: {
    CoordMode "Mouse", "Screen"
    MouseGetPos &mx, &my
    WinGetPos &wx, &wy, &ww, &wh, "A"
    ini := A_ScriptDir "\chat-popup.ini"
    IniWrite(mx - wx, ini, "pos", "relX")
    IniWrite((wy + wh) - my, ini, "pos", "relBottom")
    Notify("Saved! Popups will appear right above this spot.", 2000)
}

Start() {
    global gTarget, gSource, gBusy
    if (gBusy)
        return
    if (gPopup != "") {          ; pressing the hotkey again closes the popup
        CancelPopup()
        return
    }
    gTarget := WinExist("A")
    sel := GrabSelection(&saved)
    A_Clipboard := saved                     ; give the user their clipboard back
    if (Trim(sel) = "")
        sel := A_Clipboard                   ; nothing selected: use what was already copied
    if (Trim(sel) = "") {
        Notify("Select the message you received first (or copy it), then press Shift+Alt+2.", 2800)
        return
    }
    gSource := Trim(sel)
    Load(false)
}

Load(more) {
    global gSource, gShown, gBusy, PROMPT
    gBusy := true
    Notify("✦ Getting suggestions...", 30000)
    msg := "Received message:`n" SubStr(gSource, 1, 1500)
    if (more && gShown.Length)
        msg .= "`n`nGive DIFFERENT replies than these: " JoinReplies(gShown)
    try {
        reply := Ask(PROMPT, msg)
    } catch as e {
        gBusy := false
        ErrorBox("Chat Replies", "Request failed:`n" e.Message)
        return
    }
    gBusy := false
    ToolTip
    items := []
    for line in StrSplit(reply, "`n", "`r") {
        line := Trim(line)
        pos := InStr(line, "|")
        if (!pos)
            continue
        emoji := Trim(SubStr(line, 1, pos - 1))
        text := Trim(SubStr(line, pos + 1))
        if (text != "")
            items.Push([emoji, text])
    }
    if (items.Length = 0) {
        ErrorBox("Chat Replies", "No suggestions returned. Try again.")
        return
    }
    gShown := items
    ShowPopup(items)
}

JoinReplies(items) {
    s := ""
    for it in items
        s .= it[2] "; "
    return s
}

ShowPopup(items) {
    global gPopup, gPicks
    ClosePopup()
    BTN_W := 250
    g := Gui("+AlwaysOnTop +ToolWindow -Caption +Border")
    g.BackColor := "EEF0FF"
    g.MarginX := 16
    g.MarginY := 14
    totalW := BTN_W * 2 + 8
    g.SetFont("s12 Bold c5B3FE0", "Segoe UI")
    g.AddText("xm ym w" (totalW - 40), "✦  Chat Suggestions")
    g.SetFont("s11 Bold cDefault", "Segoe UI")
    g.AddButton("x" (16 + totalW - 32) " ym-4 w32 h30", "✕").OnEvent("Click", (*) => CancelPopup())
    g.SetFont("s10 Norm cDefault", "Segoe UI")

    picks := []
    col := 0
    for it in items {
        picks.Push(it[2])
        label := A_Index "   " (it[1] != "" ? it[1] "  " : "") it[2]
        opt := (col = 0) ? "xm y+" ((A_Index = 1) ? 12 : 8) : "x+8 yp"
        b := g.AddButton(opt " w" BTN_W " h46 Left Wrap", label)
        b.OnEvent("Click", MakeUse(it[2]))
        col := Mod(col + 1, 2)
    }
    ; "More options" goes in the next free slot
    opt := (col = 0) ? "xm y+8" : "x+8 yp"
    g.AddButton(opt " w" BTN_W " h46", "↻  More options").OnEvent("Click", (*) => Load(true))

    g.SetFont("s8 Norm c777777", "Segoe UI")
    g.AddText("xm y+10 w" totalW, "Press 1-" Min(items.Length, 6) " to pick  ·  Esc to close  ·  Shift+Alt+2 again to close")
    g.OnEvent("Escape", (*) => CancelPopup())
    g.OnEvent("Close", (*) => CancelPopup())

    gPicks := picks
    ShowPopupWindow(g)
    g.GetPos(, , &w, &h)
    try WinSet "Region", "0-0 W" w " H" h " R18-18", "ahk_id " g.Hwnd
}

MakeUse(text) {
    return (*) => UseReply(text)
}

UseReply(text) {
    global gTarget
    ClosePopup()
    if (gTarget)
        WinActivate "ahk_id " gTarget
    Sleep 250
    PasteText(text)     ; stays on the clipboard on purpose
}

CancelPopup() {
    global gTarget
    ClosePopup()
    if (gTarget)
        WinActivate "ahk_id " gTarget
}
