const MODEL = "gemini-2.5-flash";
const PROMPT =
  "You suggest quick replies for a workplace team chat (Google Chat). " +
  "You are given a message (with sender name and time) that the user RECEIVED. Ignore the name and time. " +
  "Write 5 short, natural reply options the user could send back (max 8 words each), varied: " +
  "positive, thanks, ask back, busy, catch up later or confirm, whichever fit. " +
  "Reply in the same language as the received message. " +
  "Output exactly 5 lines in the format: emoji|reply (one fitting emoji, then a | character, then the reply). " +
  "No numbering, no quotes, no extra text.";

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type !== "suggest") return;
  (async () => {
    try {
      const { geminiKey } = await chrome.storage.local.get("geminiKey");
      if (!geminiKey) {
        sendResponse({ error: "No API key yet. Right-click the extension icon > Options and paste your Gemini key." });
        return;
      }
      let text = "Received message:\n" + msg.message;
      if (msg.previous && msg.previous.length) {
        text += "\n\nGive DIFFERENT replies than these: " + msg.previous.join("; ");
      }
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;
      let lastErr = "Unknown error";
      for (let attempt = 0; attempt < 2; attempt++) {
        const r = await fetch(url, {
          method: "POST",
          headers: { "content-type": "application/json", "x-goog-api-key": geminiKey },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: PROMPT }] },
            contents: [{ role: "user", parts: [{ text }] }]
          })
        });
        const j = await r.json().catch(() => ({}));
        if (r.ok) {
          const out = (j.candidates?.[0]?.content?.parts || []).map(p => p.text || "").join("");
          const replies = out
            .split("\n")
            .map(l => l.trim())
            .filter(l => l.includes("|"))
            .map(l => {
              const i = l.indexOf("|");
              return { emoji: l.slice(0, i).trim(), text: l.slice(i + 1).trim() };
            })
            .filter(x => x.text);
          if (!replies.length) { sendResponse({ error: "No suggestions returned." }); return; }
          sendResponse({ replies });
          return;
        }
        lastErr = j.error?.message || "HTTP " + r.status;
        if (r.status !== 429 && r.status !== 503) break;
        await new Promise(res => setTimeout(res, 1500));
      }
      sendResponse({ error: lastErr });
    } catch (e) {
      sendResponse({ error: String(e) });
    }
  })();
  return true; // async response
});
