# Chat Suggestions

AI quick-reply and message-rewrite helpers for Google Chat. Two ways to use it:

- **AutoHotkey scripts** – work in any app on Windows via global hotkeys.
- **Chrome extension** – adds a "Suggest" button and popup inside Google Chat.

Both use the free Gemini API (or Claude, for the AutoHotkey scripts).

## Project layout

```
chat-common.ahk          Shared code (API calls, clipboard, popup helpers). Not run directly.
chat-replies.ahk         Reply suggestions for a message you received
chat-suggester.ahk       3 rewrites of your draft (Professional / Friendly / Concise)
chat-improver.ahk        One-shot rewrite of your draft, in place
old/                     Archived script (chat-improver-gemini.ahk), no longer needed
chat-suggestions-extension/
  manifest.json          Chrome extension (Manifest V3)
  content.js / .css      Button, popup and Shift+Alt+2 shortcut inside Google Chat
  background.js          Calls the Gemini API
  options.html / .js     Page where you paste your API key
```

## Hotkeys (AutoHotkey)

| Hotkey | Script | What it does |
|---|---|---|
| **Shift+Alt+2** (or Ctrl+Alt+S) | `chat-replies.ahk` | Select a message you received, get 6 reply chips. Click one or press 1–6 to paste it. |
| **Ctrl+Alt+R** | `chat-suggester.ahk` | Select your draft (or select nothing to use the whole box), get 3 rewrites. Click "Use this" or press 1–3. |
| **Ctrl+Alt+I** | `chat-improver.ahk` | Rewrites your draft in place. Ctrl+Z undoes it. |
| **Ctrl+Alt+P** | `chat-replies.ahk` | Calibrate: hover the top edge of the message box and press it, so popups appear right above the box. |

Press the hotkey again, or Esc, to close a popup. Popups also close when you switch window or tab.

## Setup

### 1. Get an API key
Create a free Gemini key at <https://aistudio.google.com/apikey>.

### 2. AutoHotkey scripts
1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Set a **user environment variable** (Windows Settings → search "environment variables"):
   - `GEMINI_API_KEY` = your key  *(preferred)*
   - or `ANTHROPIC_API_KEY` = a Claude key
   - optional `CHAT_PROVIDER` = `gemini` or `claude` to force one when both are set
3. Restart the scripts (or sign out/in) so they pick up the variable.
4. Double-click the scripts you want: `chat-replies.ahk`, `chat-suggester.ahk`, `chat-improver.ahk`.
   They must stay in the same folder as `chat-common.ahk`.

### 3. Chrome extension
1. Open `chrome://extensions` and turn on **Developer mode**.
2. Click **Load unpacked** and choose the `chat-suggestions-extension` folder.
3. Right-click the extension icon → **Options**, paste your Gemini key, click **Save**.
   (The extension stores its key separately from the environment variable.)
4. Open Google Chat (`chat.google.com` or Gmail's chat) and refresh.

In Google Chat, select a message (or leave nothing selected to use the last message on screen) and press **Shift+Alt+2** or click **✦ Suggest** above the message box. Click a chip to insert it.

## Notes

- **Shift+Alt+2 is used by both the AutoHotkey script and the extension.** With the script running, it takes the key first and the extension never sees it. Run one or the other, or change the hotkey in `chat-replies.ahk` (`+!2::`) or `content.js`.
- Selected text is sent to the Gemini or Claude API to generate suggestions. Don't use it on messages you aren't allowed to share with those services.
- Keep your API key private. It is never stored in the project files. If it leaks, regenerate it.
- The scripts copy and paste using the clipboard and restore your original clipboard afterwards (except `chat-replies.ahk`, which leaves the chosen reply on the clipboard on purpose).

## Troubleshooting

| Problem | Fix |
|---|---|
| "No API key found" | Set `GEMINI_API_KEY`, then restart the script. |
| Hotkey does nothing | Another script may hold it. Exit old AutoHotkey scripts from the tray icon. |
| Popup appears in the wrong place | Use Ctrl+Alt+P to calibrate. |
| "HTTP 429 / 503" | The API is busy or rate limited. The scripts retry automatically; wait a moment and try again. |
| Extension says "No API key yet" | Paste the key on the extension's Options page. |
| Extension shows nothing | Reload it at `chrome://extensions`, then refresh the Google Chat tab. |
