const MENU_ID = "open-on-iphone";
const HOST_NAME = "local.open_on_iphone";

function createMenu() {
  chrome.contextMenus.create({
    id: MENU_ID,
    title: "Open on iPhone",
    contexts: ["page", "link"],
  }, () => void chrome.runtime.lastError);
}

chrome.runtime.onInstalled.addListener(createMenu);
chrome.runtime.onStartup.addListener(createMenu);

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== MENU_ID) return;
  const url = info.linkUrl || info.pageUrl || tab?.url;
  if (!url || !/^https?:\/\//i.test(url)) return;

  try {
    console.info("Open on iPhone: contacting Mac helper");
    const result = await chrome.runtime.sendNativeMessage(HOST_NAME, { url });
    if (!result?.ok) throw new Error(result?.error || "AirDrop did not complete.");
    console.info("Open on iPhone: AirDrop completed");
  } catch (error) {
    console.error("Open on iPhone failed:", error);
    chrome.notifications.create({
      type: "basic",
      iconUrl: "icon.png",
      title: "Open on iPhone",
      message: String(error?.message || error),
    });
  }
});
