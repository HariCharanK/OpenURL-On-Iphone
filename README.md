# Open on iPhone for Brave

Right-click a web page or link in Brave and choose **Open on iPhone**. The extension sends that URL to a local Mac helper. It opens AirDrop and selects the device whose AirDrop name is exactly **Hari’s iPhone**. It never selects a different device.

The helper has no ordinary window and runs as an accessory app, keeping Brave in front. macOS may briefly show its AirDrop picker during device discovery. Apple does not provide a supported way to suppress the picker or specify the recipient directly.

## Install

1. Run `./install.sh` in Terminal from this folder. It builds the Mac helper from source with Swift and registers it for Brave. Xcode Command Line Tools are required.
2. Visit `brave://extensions`, enable **Developer mode**, click **Load unpacked**, and select `~/Library/Application Support/Open on iPhone/extension`.
3. Open **System Settings → Privacy & Security → Accessibility** and allow **Open on iPhone**. This lets the helper select only the named device in Apple's AirDrop picker.

If you rebuild the helper after granting Accessibility access, macOS may keep showing the old entry as enabled while denying the new local signature. Remove **Open on iPhone** from the Accessibility list, add the installed app at `~/Library/Application Support/Open on iPhone/Open on iPhone.app` again, and enable it.

Keep Wi-Fi and Bluetooth on for both devices, and enable AirDrop receiving on the iPhone. The devices need to be nearby, but they do not need the same Wi-Fi network.

The extension has no server and does not read page content. It sends only the chosen HTTP or HTTPS URL to the local helper. For links to a website with an associated iPhone app, iOS may open that app instead of the default browser.
