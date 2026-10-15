import Foundation

nonisolated enum ConflictDiffHTML {
    static func render(disk: String, draft: String, javaScript: String) -> String {
        let labels = [
            "disk": NSLocalizedString("Disk Version", comment: "Save conflict comparison heading"),
            "draft": NSLocalizedString("Your Unsaved Draft", comment: "Save conflict comparison heading"),
            "previous": NSLocalizedString("Previous Change", comment: "Save conflict diff navigation"),
            "next": NSLocalizedString("Next Change", comment: "Save conflict diff navigation"),
        ]
        let labelsJSON = labels.sorted { $0.key < $1.key }.map {
            "\(EditorHTML.jsStringLiteral($0.key)):\(EditorHTML.jsStringLiteral($0.value))"
        }.joined(separator: ",")
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        body { margin: 0; height: 100vh; display: flex; flex-direction: column;
            font: 13px -apple-system, sans-serif; color: -apple-system-label;
            background: -apple-system-text-background; }
        header { display: grid; grid-template-columns: 1fr 1fr; font-weight: 600;
            border-bottom: 1px solid -apple-system-separator; }
        header span { padding: 10px 12px; }
        #comparison { flex: 1; min-height: 0; }
        .cm-mergeView { height: 100%; }
        .cm-mergeViewEditor { min-width: 0; }
        .cm-gutters { color: -apple-system-secondary-label; background: transparent; }
        .cm-editor.cm-focused { outline: none; }
        footer { display: flex; justify-content: flex-end; gap: 8px; padding: 8px;
            border-top: 1px solid -apple-system-separator; }
        button { font: inherit; }
        </style></head><body>
        <header><span id="disk-title"></span><span id="draft-title"></span></header>
        <div id="comparison"></div>
        <footer><button id="previous"></button><button id="next"></button></footer>
        <script>\(javaScript)</script>
        <script>MDConflictDiff(\(EditorHTML.jsStringLiteral(disk)),
            \(EditorHTML.jsStringLiteral(draft)), {\(labelsJSON)});</script>
        </body></html>
        """
    }
}
