import Foundation

nonisolated enum ConflictDiffHTML {
    static func render(disk: String, draft: String, javaScript: String) -> String {
        let labels = [
            "disk": NSLocalizedString("On Disk", comment: "Save conflict comparison heading"),
            "draft": NSLocalizedString("Your Draft", comment: "Save conflict comparison heading"),
            "saved": NSLocalizedString("Saved file", comment: "Save conflict disk status"),
            "unsaved": NSLocalizedString("Unsaved", comment: "Save conflict draft status"),
            "differences": NSLocalizedString("Differences", comment: "Save conflict difference count label"),
            "position": NSLocalizedString("%1$d of %2$d", comment: "Current difference and total; substituted in JavaScript"),
            "noChanges": NSLocalizedString("No text changes", comment: "No normalized line differences"),
            "previous": NSLocalizedString("Previous Change", comment: "Save conflict diff navigation"),
            "next": NSLocalizedString("Next Change", comment: "Save conflict diff navigation"),
            "showAll": NSLocalizedString("Show Whole File", comment: "Expand unchanged source in a comparison"),
            "hideUnchanged": NSLocalizedString("Hide Unchanged", comment: "Collapse unchanged source in a comparison"),
            "unchanged": NSLocalizedString("$ unchanged lines", comment: "$ is replaced by CodeMirror with the number of collapsed lines"),
            "none": NSLocalizedString("None", comment: "No line ending characters"),
            "lineEndings": NSLocalizedString("Line endings differ. On disk: %1$@; draft: %2$@.", comment: "Line ending names; substituted in JavaScript"),
        ]
        let labelsJSON = labels.sorted { $0.key < $1.key }.map {
            "\(EditorHTML.jsStringLiteral($0.key)):\(EditorHTML.jsStringLiteral($0.value))"
        }.joined(separator: ",")
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; --secondary: -apple-system-secondary-label;
            --rule: -apple-system-separator; --chrome: -apple-system-control-background;
            --focus: -apple-system-control-accent; --line: #fbf4e8; --word: #f5deb0; --edge: #ad7520; }
        #comparison .cm-merge-a { --line: #fbefef; --word: #f3c5c5; --edge: #c75353; }
        #comparison .cm-merge-b { --line: #eef7f1; --word: #bfe4c9; --edge: #33834f; }
        @media (prefers-color-scheme: dark) {
            :root { --line: #363023; --word: #765b30; --edge: #d9ac61; }
            #comparison .cm-merge-a { --line: #342727; --word: #63383c; --edge: #dc858c; }
            #comparison .cm-merge-b { --line: #22362b; --word: #315840; --edge: #72bf8c; }
        }
        @media (prefers-contrast: more) {
            :root { --secondary: -apple-system-label; --rule: -apple-system-label; }
            #comparison .cm-changedText { outline: 1px solid var(--edge); }
        }
        * { box-sizing: border-box; }
        body { margin: 0; height: 100vh; display: flex; flex-direction: column;
            font: 12px -apple-system, sans-serif; color: -apple-system-label;
            background: -apple-system-text-background; border: 1px solid var(--rule);
            border-radius: 8px; overflow: hidden; }
        .toolbar { display: flex; align-items: center; gap: 8px; min-height: 38px;
            padding: 6px 12px; background: var(--chrome); border-bottom: 1px solid var(--rule); }
        #summary { margin-right: auto; font-weight: 600; }
        #position { color: var(--secondary); font-size: 11px; font-variant-numeric: tabular-nums; }
        header { display: grid; grid-template-columns: 1fr 1fr; border-bottom: 1px solid var(--rule); }
        header > div { display: flex; justify-content: space-between; align-items: center;
            gap: 12px; padding: 8px 12px; }
        header > div + div { border-left: 1px solid var(--rule); }
        header small { color: var(--secondary); font-size: 10px; }
        #comparison { flex: 1; min-height: 0; }
        .cm-mergeView { height: 100%; }
        .cm-mergeViewEditor { min-width: 0; }
        .cm-mergeViewEditor + .cm-mergeViewEditor { border-left: 1px solid var(--rule); }
        #comparison .cm-gutters { border: 0; }
        #comparison .cm-lineNumbers .cm-gutterElement { min-width: 26px; padding-right: 8px; }
        #comparison .cm-line { padding: 0 10px 0 5px; }
        #comparison .cm-changedLine { background: var(--line); }
        #comparison .cm-changedText { background: var(--word); border-radius: 2px;
            box-decoration-break: clone; -webkit-box-decoration-break: clone; }
        #comparison .cm-changedLineGutter { background: var(--edge); }
        #comparison .cm-collapsedLines { background: var(--chrome); color: var(--secondary); font: 11px/27px -apple-system, sans-serif; }
        #comparison .cm-editor.cm-focused { outline: 2px solid var(--focus); outline-offset: -2px; }
        #comparison .cm-selectionBackground { background: color-mix(in srgb, Highlight 30%, transparent); }
        button { font: 11px -apple-system, sans-serif; color: inherit; background: -apple-system-text-background;
            border: 1px solid var(--rule); border-radius: 5px; min-height: 24px; padding: 2px 7px; }
        button:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }
        button:active { background: var(--chrome); }
        button:disabled { opacity: .45; }
        .arrow { font-size: 16px; line-height: 18px; }
        #line-endings { margin: 0; padding: 8px 12px; background: var(--line); border-bottom: 1px solid var(--rule); }
        </style></head><body>
        <div class="toolbar">
            <strong id="summary"></strong><button id="context" aria-pressed="false"></button>
            <output id="position" aria-live="polite" aria-atomic="true"></output>
            <button id="previous" class="arrow">↑</button><button id="next" class="arrow">↓</button>
        </div>
        <p id="line-endings" role="status" hidden></p>
        <header>
            <div><strong id="disk-title"></strong><small id="disk-status"></small></div>
            <div><strong id="draft-title"></strong><small id="draft-status"></small></div>
        </header>
        <div id="comparison"></div>
        <script>\(javaScript)</script>
        <script>MDConflictDiff(\(EditorHTML.jsStringLiteral(disk)),
            \(EditorHTML.jsStringLiteral(draft)), {\(labelsJSON)});</script>
        </body></html>
        """
    }
}
