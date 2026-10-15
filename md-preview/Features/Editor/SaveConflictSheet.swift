import Cocoa
import WebKit

enum SaveConflictSheet {
    static func make(localMarkdown: String, externalMarkdown: String,
                     fileName: String, changedAgain: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: changedAgain
            ? NSLocalizedString("“%@” changed again on disk", comment: "Refreshed conflict title")
            : NSLocalizedString("“%@” changed on disk", comment: "External edit conflict alert title"), fileName)
        alert.informativeText = NSLocalizedString(
            "Overwriting replaces the file on disk. Reloading discards your draft. Cancel keeps your changes unsaved.",
            comment: "Save conflict explanation")
        alert.addButton(withTitle: NSLocalizedString("Overwrite Disk", comment: "Conflict alert button"))
        alert.addButton(withTitle: NSLocalizedString("Reload from Disk", comment: "Conflict alert button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Alert button"))
        // Neither Return nor a not-yet-loaded comparison may discard a version.
        for button in alert.buttons.prefix(2) {
            button.keyEquivalent = ""
            button.isEnabled = false
            button.hasDestructiveAction = true
        }
        alert.buttons[2].keyEquivalent = "\u{1b}"
        let diff = ConflictDiffWebView(disk: externalMarkdown, draft: localMarkdown)
        diff.finishedLoading = { [weak alert] success in
            guard let alert else { return }
            if success {
                alert.buttons.prefix(2).forEach { $0.isEnabled = true }
            } else {
                alert.informativeText = NSLocalizedString(
                    "The comparison could not be displayed. Cancel to return to your unsaved draft.",
                    comment: "Save conflict comparison failure")
            }
        }
        alert.accessoryView = diff
        return alert
    }
}

private final class ConflictDiffWebView: WKWebView, WKNavigationDelegate {
    var finishedLoading: ((Bool) -> Void)?

    init(disk: String, draft: String) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let size = NSSize(width: 820, height: 420)
        super.init(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        navigationDelegate = self
        let url = Bundle.main.url(forResource: "mdconflict.min", withExtension: "js",
                                  subdirectory: "Vendor/CodeMirror")
            ?? Bundle.main.url(forResource: "mdconflict.min", withExtension: "js")
        let script = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        loadHTMLString(ConflictDiffHTML.render(disk: disk, draft: draft, javaScript: script), baseURL: nil)
    }

    required init?(coder: NSCoder) { nil }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        evaluateJavaScript("window.__conflictReady === true") { [weak self] result, _ in
            self?.finishedLoading?(result as? Bool == true)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishedLoading?(false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishedLoading?(false)
    }
}
