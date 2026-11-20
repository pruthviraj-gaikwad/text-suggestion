const keyInput = document.getElementById("key");
const status = document.getElementById("status");

chrome.storage.local.get("geminiKey", ({ geminiKey }) => {
  if (geminiKey) keyInput.placeholder = "Key saved (paste a new one to replace)";
});

document.getElementById("save").addEventListener("click", async () => {
  const v = keyInput.value.trim();
  if (!v) { status.style.color = "#b3261e"; status.textContent = "Paste a key first."; return; }
  await chrome.storage.local.set({ geminiKey: v });
  keyInput.value = "";
  keyInput.placeholder = "Key saved (paste a new one to replace)";
  status.style.color = "#188038";
  status.textContent = "Saved ✓";
});
