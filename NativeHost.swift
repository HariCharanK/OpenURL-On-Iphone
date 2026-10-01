import AppKit
import ApplicationServices
import Foundation

private let phoneName = "Hari’s iPhone"

private func readMessage() -> URL? {
    let input = FileHandle.standardInput
    let prefix = input.readData(ofLength: 4)
    guard prefix.count == 4 else { return nil }
    let length = prefix.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
    guard length > 0, length <= 1_000_000 else { return nil }
    let data = input.readData(ofLength: Int(length))
    guard data.count == Int(length),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let value = json["url"] as? String,
          let url = URL(string: value),
          ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
    return url
}

private func writeMessage(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
    var length = UInt32(data.count).littleEndian
    let output = FileHandle.standardOutput
    withUnsafeBytes(of: &length) { output.write(Data($0)) }
    output.write(data)
}

private func axValue(_ element: AXUIElement, _ key: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key, &value) == .success else { return nil }
    return value
}

private func matchingButtons(in element: AXUIElement, title: String? = nil, description: String? = nil, depth: Int = 0) -> [AXUIElement] {
    guard depth < 12 else { return [] }
    let role = axValue(element, kAXRoleAttribute as CFString) as? String
    let actualTitle = axValue(element, kAXTitleAttribute as CFString) as? String
    let actualDescription = axValue(element, kAXDescriptionAttribute as CFString) as? String
    if role == (kAXButtonRole as String),
       (title == nil || actualTitle == title),
       (description == nil || actualDescription == description) { return [element] }
    guard let children = axValue(element, kAXChildrenAttribute as CFString) as? [AXUIElement] else { return [] }
    return children.flatMap { matchingButtons(in: $0, title: title, description: description, depth: depth + 1) }
}

private func findButton(title: String? = nil, description: String? = nil) -> AXUIElement? {
    let application = AXUIElementCreateApplication(getpid())
    guard let windows = axValue(application, kAXWindowsAttribute as CFString) as? [AXUIElement] else { return nil }
    let matches = windows
        .filter { (axValue($0, kAXTitleAttribute as CFString) as? String) == "AirDrop" }
        .flatMap { matchingButtons(in: $0, title: title, description: description) }
    return matches.count == 1 ? matches[0] : nil
}

@MainActor
private final class AirDropHost: NSObject, NSApplicationDelegate, NSSharingServiceDelegate {
    private let url: URL
    private var service: NSSharingService?
    private var finished = false

    init(url: URL) { self.url = url }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard AXIsProcessTrusted() else {
            finish(error: "Allow Open on iPhone in System Settings → Privacy & Security → Accessibility, then try again.")
            return
        }
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: [url]) else {
            finish(error: "AirDrop is unavailable. Check Wi-Fi and Bluetooth.")
            return
        }
        self.service = service
        service.delegate = self
        service.perform(withItems: [url])

        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            self.finish(error: "AirDrop did not complete within 20 seconds.")
        }

        // AirDrop's public API has no supported recipient selector. Select only
        // the exact device named above in its accessibility list.
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<100 {
                if let target = findButton(description: phoneName) {
                    let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
                    if result == .success {
                        fputs("Selected iPhone in AirDrop.\n", stderr)
                        for _ in 0..<50 {
                            if let done = findButton(title: "Done") ?? findButton(description: "Done"),
                               AXUIElementPerformAction(done, kAXPressAction as CFString) == .success {
                                fputs("Closed AirDrop picker.\n", stderr)
                                return
                            }
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                        return
                    }
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            DispatchQueue.main.async {
                self.finish(error: "Hari’s iPhone was not found in AirDrop.")
            }
        }
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(error: nil)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        finish(error: error.localizedDescription)
    }

    private func finish(error: String?) {
        guard !finished else { return }
        finished = true
        writeMessage(error.map { ["ok": false, "error": $0] } ?? ["ok": true])
        NSApp.terminate(nil)
    }
}

@main
private struct Main {
    @MainActor static func main() {
        guard let url = readMessage() else {
            writeMessage(["ok": false, "error": "Only web links can be sent."])
            return
        }
        let app = NSApplication.shared
        let delegate = AirDropHost(url: url)
        app.delegate = delegate
        app.run()
    }
}
