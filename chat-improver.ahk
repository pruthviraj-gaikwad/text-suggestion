#Requires AutoHotkey v2.0
#SingleInstance Force
#Include chat-common.ahk

; ============================================================
; Chat Improver - instantly rewrites the message you are typing.
; Hotkey: Ctrl+Alt+I  (select text first, or select nothing and it
;         takes everything in the current text box). Ctrl+Z undoes it.
; Uses Gemini or Claude, whichever API key is set (see chat-common.ahk).
; (Ctrl+Alt+R is the 3-options popup in chat-suggester.ahk.)
; ============================================================

SYSTEM_PROMPT := "You rewrite draft chat messages for a workplace team chat (Google Chat). "
    . "Improve clarity, grammar and tone: friendly, professional, concise. Keep the original meaning, "
    . "language and any @mentions, links or names unchanged. Do not add greetings or sign-offs that were not there. "
    . "Reply with ONLY the improved message, no quotes, no explanation."

^!i:: ImproveSelection()

ImproveSelection() {
    global gBusy, SYSTEM_PROMPT
    if (gBusy)
        return
    selectedAll := false
    text := GrabSelection(&saved)
    if (Trim(text) = "") {
        ; nothing selected -> take the whole text box
        Send "^a"
        Sleep 80
        selectedAll := true
        text := GrabSelection(&ignored)   ; keep the ORIGINAL clipboard saved by the first grab
    }
    if (Trim(text) = "") {
        A_Clipboard := saved
        Notify("No text found.", 1500)
        return
    }

    gBusy := true
    Notify("✨ Improving message...", 30000)
    try {
        result := Ask(SYSTEM_PROMPT, SubStr(text, 1, 3000))
    } catch as e {
        gBusy := false
        A_Clipboard := saved
        if (selectedAll)
            Send "^{End}"       ; don't leave the whole draft selected
        ErrorBox("Chat Improver", "Request failed:`n" e.Message)
        return
    }
    gBusy := false

    ; models sometimes wrap the answer in quotes
    if (StrLen(result) > 1 && SubStr(result, 1, 1) = '"' && SubStr(result, -1) = '"')
        result := SubStr(result, 2, StrLen(result) - 2)

    if (result = "") {
        A_Clipboard := saved
        ToolTip
        return
    }
    PasteText(result, saved)
    Notify("✓ Improved - Ctrl+Z to undo", 2000)
}
