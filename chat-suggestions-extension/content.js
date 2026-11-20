(() => {
  let btn = null;
  let panel = null;
  let previous = [];
  let source = "";
  let panelUrl = "";

  // ---- find the message box (lowest visible editable textbox on the page) ----
  function findInput() {
    const cands = [...document.querySelectorAll('[role="textbox"][contenteditable="true"], div[contenteditable="true"]')];
    let best = null;
    for (const el of cands) {
      const r = el.getBoundingClientRect();
      if (r.width < 120 || r.height < 10 || r.bottom <= 0 || r.top >= innerHeight) continue;
      if (!best || r.bottom > best.getBoundingClientRect().bottom) best = el;
    }
    return best;
  }

  // The box's outer rounded container is a better anchor than the inner editable.
  function inputRect(input) {
    let el = input;
    let r = input.getBoundingClientRect();
    for (let i = 0; i < 4 && el.parentElement; i++) {
      const pr = el.parentElement.getBoundingClientRect();
      if (pr.width > r.width + 2 && pr.width < innerWidth && pr.height < 220) {
        el = el.parentElement;
        r = pr;
      } else break;
    }
    return r;
  }

  // ---- the message to answer: selected text, else the last message on screen ----
  function getSourceMessage() {
    const sel = String(getSelection() || "").trim();
    if (sel) return sel;
    const nodes = [...document.querySelectorAll("[data-message-id]")];
    for (let i = nodes.length - 1; i >= 0; i--) {
      const t = (nodes[i].innerText || "").trim();
      if (t) return t.slice(0, 600);
    }
    return "";
  }

  function ensureButton() {
    if (btn) return;
    btn = document.createElement("button");
    btn.id = "cs-btn";
    btn.type = "button";
    btn.title = "Suggest replies (Shift+Alt+2)";
    btn.innerHTML = "✦ <span>Suggest</span>";
    btn.addEventListener("mousedown", e => e.preventDefault()); // keep text selection
    btn.addEventListener("click", () => open(false));
    document.body.appendChild(btn);
  }

  function place() {
    ensureButton();
    const input = findInput();
    if (!input) {
      btn.style.display = "none";
      closePanel();
      return;
    }
    const r = inputRect(input);
    btn.style.display = panel ? "none" : "inline-flex";
    btn.style.left = Math.max(8, r.right - 120) + "px";
    btn.style.top = Math.max(8, r.top - 40) + "px";
    if (panel) {
      const w = Math.min(Math.max(r.width, 520), innerWidth - 16);
      panel.style.width = w + "px";
      panel.style.left = Math.max(8, Math.min(r.left, innerWidth - w - 8)) + "px";
      panel.style.bottom = Math.max(8, innerHeight - r.top + 10) + "px";
    }
  }

  function closePanel() {
    if (panel) { panel.remove(); panel = null; }
  }

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  function buildPanel() {
    closePanel();
    panel = el("div");
    panel.id = "cs-panel";
    panel.addEventListener("mousedown", e => e.preventDefault()); // don't steal focus from the box
    document.body.appendChild(panel);
    panelUrl = location.href;
    place();
    return panel;
  }

  function header() {
    const h = el("div", "cs-head");
    h.append(el("span", "cs-spark", "✦"), el("span", "cs-title", "Chat Suggestions"));
    const x = el("button", "cs-close", "✕");
    x.type = "button";
    x.addEventListener("click", closePanel);
    h.append(x);
    return h;
  }

  function showMessage(text, isErr) {
    const p = panel || buildPanel();
    p.replaceChildren(header(), el("div", "cs-msg" + (isErr ? " cs-err" : ""), text));
    place();
  }

  function showLoading() {
    const p = panel || buildPanel();
    const grid = el("div", "cs-grid");
    for (let i = 0; i < 6; i++) grid.append(el("div", "cs-chip cs-skel"));
    p.replaceChildren(header(), grid);
    place();
  }

  function insertReply(text) {
    const input = findInput();
    closePanel();
    if (!input) return;
    input.focus();
    document.execCommand("insertText", false, text);
  }

  function showReplies(replies) {
    const p = panel || buildPanel();
    const grid = el("div", "cs-grid");
    for (const r of replies) {
      const chip = el("button", "cs-chip");
      chip.type = "button";
      chip.append(el("span", "cs-e", r.emoji || "💬"), el("span", "cs-t", r.text));
      chip.title = r.text;
      chip.addEventListener("click", () => insertReply(r.text));
      grid.append(chip);
    }
    const more = el("button", "cs-chip cs-more", "↻ More options");
    more.type = "button";
    more.addEventListener("click", () => open(true));
    grid.append(more);
    p.replaceChildren(header(), grid);
    place();
  }

  function open(more) {
    if (!more) {
      source = getSourceMessage();
      previous = [];
    }
    if (!source) {
      showMessage("Couldn't find a message to reply to. Select the message text first, then click Suggest.", true);
      return;
    }
    showLoading();
    chrome.runtime.sendMessage({ type: "suggest", message: source, previous }, res => {
      if (chrome.runtime.lastError) { showMessage(chrome.runtime.lastError.message, true); return; }
      if (!res || res.error) { showMessage((res && res.error) || "No response.", true); return; }
      previous = res.replies.map(r => r.text);
      showReplies(res.replies);
    });
  }

  // ---- close when clicking outside, pressing Esc, switching tab/conversation ----
  document.addEventListener("mousedown", e => {
    if (panel && !panel.contains(e.target) && !(btn && btn.contains(e.target))) closePanel();
  }, true);
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") { closePanel(); return; }
    // Shift+Alt+2 toggles suggestions (e.code works on every keyboard layout)
    if (e.shiftKey && e.altKey && !e.ctrlKey && !e.metaKey && e.code === "Digit2") {
      e.preventDefault();
      e.stopPropagation();
      if (panel) closePanel(); else open(false);
    }
  }, true);
  document.addEventListener("visibilitychange", () => { if (document.hidden) closePanel(); });
  window.addEventListener("blur", () => closePanel());

  setInterval(() => {
    if (panel && location.href !== panelUrl) closePanel();
    place();
  }, 400);
  window.addEventListener("resize", place);
})();
