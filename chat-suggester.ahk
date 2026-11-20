#Requires AutoHotkey v2.0
#SingleInstance Force
#Include chat-common.ahk

; ============================================================
; Chat Suggester - shows a popup with 3 AI versions of the message
; you are typing (Professional / Friendly / Concise). Click "Use this"
; (or press 1 / 2 / 3) on the one you like and it replaces your draft.
; Hotkey: Ctrl+Alt+R   (select text first, or select nothing to use
;         everything in the current text box)
; Keys: see chat-common.ahk (GEMINI_API_KEY or ANTHROPIC_API_KEY).
; ============================================================

LABELS := ["Professional", "Friendly", "Concise"]
SYSTEM_PROMPT := "You help write messages for a workplace team chat (Google Chat). "
    . "Given a draft message, write exactly 3 improved versions in this order: "
    . "1) Professional, 2) Friendly, 3) Concise. Keep the original meaning, language, @mentions, links and names. "
    . "Fix grammar and clarity. Do not add greetings or sign-offs that were not in the draft. "
    . "Output ONLY the 3 messages, separated by a line containing exactly ### . No numbering, no labels, no quotes, no explanation."

global gSavedClip := ""
global gSelectedAll := false

InitPopupKeys()
gPickFn := UseText
gAutoCloseFn := RestoreClip

^!r:: Suggest()

RestoreClip() {
    global gSavedClip
    if (gSavedClip != "")
        A_Clipboard := gSavedClip
}

Suggest() {
    global gSavedClip, gTarget, gBusy, gSelectedAll, SYSTEM_PROMPT
    if (gBusy)
        return
    if (gPopup != "") {          ; pressing the hotkey again closes the popup
        CancelPopup()
        return
    }
    gTarget := WinExist("A")
    gSelectedAll := false
    text := GrabSelection(&gSavedClip)
    if (Trim(text) = "") {
        Send "^a"                ; nothing selected -> take the whole text box
        Sleep 80
        gSelectedAll := true
        text := GrabSelection(&ignored)   ; keep the ORIGINAL clipboard saved by the first grab
    }
    if (Trim(text) = "") {
        A_Clipboard := gSavedClip
        Notify("No text found.", 1500)
        return
    }

    gBusy := true
    Notify("✨ Getting suggestions...", 30000)
    try {
        reply := Ask(SYSTEM_PROMPT, SubStr(text, 1, 3000))
    } catch as e {
        gBusy := false
        A_Clipboard := gSavedClip
        Deselect()
        ErrorBox("Chat Suggester", "Request failed:`n" e.Message)
        return
    }
    gBusy := false
    ToolTip

    options := []
    for part in StrSplit(reply, "###") {
        p := Trim(part, " `t`r`n")
        if (p != "")
            options.Push(p)
    }
    if (options.Length = 0) {
        A_Clipboard := gSavedClip
        Deselect()
        ErrorBox("Chat Suggester", "No suggestions returned. Try again.")
        return
    }
    ShowPopup(options)
}

; If we pressed Ctrl+A ourselves, don't leave the whole draft selected
; (the next keystroke would replace it).
Deselect() {
    global gSelectedAll
    if (gSelectedAll) {
        gSelectedAll := false
        Send "^{End}"
    }
}

ShowPopup(options) {
    global gPopup, gPicks, LABELS
    colors := ["1A73E8", "188038", "E37400"]
    g := Gui("+AlwaysOnTop +ToolWindow -Caption +Border")
    g.BackColor := "FFFFFF"
    g.MarginX := 14
    g.MarginY := 12
    g.SetFont("s11 Bold", "Segoe UI")
    g.AddText("x0 y0 w488 h42 Center +0x200 Background1A73E8 cWhite", "✨  AI suggestions for your message")
    g.SetFont("s10 Bold", "Segoe UI")
    g.AddButton("x452 y8 w28 h26", "✕").OnEvent("Click", (*) => CancelPopup())

    picks := []
    first := true
    for i, opt in options {
        picks.Push(opt)
        color := colors[Mod(i - 1, colors.Length) + 1]
        label := i " · " ((i <= LABELS.Length) ? LABELS[i] : "Option " i)
        g.SetFont("s9 Bold", "Segoe UI")
        g.AddText("xm " (first ? "y+14" : "y+16") " w132 h26 Center +0x200 Background" color " cWhite", label)
        first := false
        g.AddButton("x388 yp w86 h26", "Use this ➜").OnEvent("Click", MakeUse(opt))
        g.SetFont("s10 Norm", "Segoe UI")
        nl := StrLen(opt) - StrLen(StrReplace(opt, "`n"))
        rows := Max(2, Ceil(StrLen(opt) / 58) + nl)
        g.AddEdit("xm y+6 w460 r" rows " ReadOnly -Tabstop -VScroll -E0x200 BackgroundF1F3F4", opt)
    }
    g.SetFont("s8 Norm c777777", "Segoe UI")
    g.AddText("xm y+14 w340", "Press 1-" Min(options.Length, 6) " to use  ·  Esc to close  ·  closes when you switch window")
    g.SetFont("s9 Norm cDefault", "Segoe UI")
    g.AddButton("x388 yp-4 w86 h26", "Cancel").OnEvent("Click", (*) => CancelPopup())
    g.AddText("xm h6")
    g.OnEvent("Escape", (*) => CancelPopup())
    g.OnEvent("Close", (*) => CancelPopup())

    ClosePopup()
    gPicks := picks
    ShowPopupWindow(g)
}

MakeUse(text) {
    return (*) => UseText(text)
}

UseText(text) {
    global gSavedClip, gTarget
    ClosePopup()
    if (gTarget)
        WinActivate "ahk_id " gTarget
    Sleep 200
    PasteText(text, gSavedClip)    ; replaces the selected draft, then restores your clipboard
}

CancelPopup() {
    global gTarget
    ClosePopup()
    if (gTarget)
        WinActivate "ahk_id " gTarget
    RestoreClip()
    Deselect()
}
