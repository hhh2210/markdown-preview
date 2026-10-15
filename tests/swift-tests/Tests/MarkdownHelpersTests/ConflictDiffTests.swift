import WebKit
import XCTest
@testable import MarkdownHelpers

@MainActor
final class ConflictDiffTests: XCTestCase {
    func testComparisonShowsBothSourcesWithoutRenderingDocumentHTML() async throws {
        let disk = "---\ntitle: 磁盘\n---\n\n# Plan\nAgent changed this.\n"
        let draft = "---\ntitle: 草稿\n---\n\n# Plan\nHuman changed this.\n</script><script>window.injected = true</script>\n"
        let page = try await comparison(disk: disk, draft: draft)
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            const view = window.__conflictDiff;
            return {disk: view.a.state.doc.toString(), draft: view.b.state.doc.toString(),
                changes: view.chunks.length,
                changedLines: document.querySelectorAll('.cm-changedLine').length,
                editable: [...document.querySelectorAll('[contenteditable=true]')].length,
                injected: window.injected === true,
                labels: [...document.querySelectorAll('.cm-content')].map(e => e.getAttribute('aria-label'))};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(values["disk"] as? String, disk)
        XCTAssertEqual(values["draft"] as? String, draft)
        XCTAssertGreaterThan(values["changes"] as? Int ?? 0, 0)
        XCTAssertGreaterThan(values["changedLines"] as? Int ?? 0, 0)
        XCTAssertEqual(values["editable"] as? Int, 0)
        XCTAssertEqual(values["injected"] as? Bool, false)
        XCTAssertEqual((values["labels"] as? [String])?.count, 2)
    }

    func testNavigationReachesDistantChangesAndKeepsBothSnapshots() async throws {
        let disk = (0..<200).map { "Unchanged line \($0)" }.joined(separator: "\n")
        let draft = disk.replacingOccurrences(of: "line 3\n", with: "line 3: human\n")
            .replacingOccurrences(of: "line 180\n", with: "line 180: human\n")
        let page = try await comparison(disk: disk, draft: draft)
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            document.getElementById('next').click();
            for (let i = 0; i < 5; i++) window.__layoutTestFrame();
            const view = window.__conflictDiff;
            const target = view.a.coordsAtPos(view.a.state.doc.line(181).from);
            const bounds = view.dom.getBoundingClientRect();
            return {targetVisible: target.top >= bounds.top && target.top < bounds.bottom,
                collapsed: document.querySelectorAll('.cm-collapsedLines').length,
                position: document.getElementById('position').textContent,
                changes: view.chunks.length, disk: view.a.state.doc.toString(), draft: view.b.state.doc.toString()};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(values["changes"] as? Int, 2)
        XCTAssertEqual(values["targetVisible"] as? Bool, true)
        XCTAssertGreaterThan(values["collapsed"] as? Int ?? 0, 0)
        XCTAssertEqual(values["position"] as? String, "2 of 2")
        XCTAssertEqual(values["disk"] as? String, disk)
        XCTAssertEqual(values["draft"] as? String, draft)
    }

    func testLongDeletionNavigationShowsItsStartInsteadOfTheFollowingLine() async throws {
        let disk = "# Title\n" + (0..<100).map { "Removed line \($0)\n" }.joined() + "Unchanged ending\n"
        let page = try await comparison(disk: disk, draft: "# Title\nUnchanged ending\n")
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            const view = window.__conflictDiff;
            const first = view.a.coordsAtPos(view.chunks[0].fromA);
            const bounds = view.dom.getBoundingClientRect();
            return first.top >= bounds.top && first.top < bounds.bottom;
            """, arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(result as? Bool, true)
    }

    func testWholeFileToggleAndKeyboardCopyRetainHiddenSourceAndMixedLineEndings() async throws {
        let disk = (0..<100).map { "Line \($0)" + ($0.isMultiple(of: 2) ? "\r\n" : "\n") }.joined()
        let page = try await comparison(disk: disk, draft: disk.replacingOccurrences(of: "Line 50", with: "Edited line 50"))
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            const view = window.__conflictDiff.a;
            const key = (key, extra = {}) => view.contentDOM.dispatchEvent(
                new KeyboardEvent('keydown', {key, bubbles: true, cancelable: true, ...extra}));
            const initialCollapsed = document.querySelectorAll('.cm-collapsedLines').length;
            key('a', {metaKey: true});
            const selectedAll = view.state.selection.main.from === 0 && view.state.selection.main.to === view.state.doc.length;
            let copied;
            const copy = new Event('copy', {bubbles: true, cancelable: true});
            Object.defineProperty(copy, 'clipboardData', {value: {setData: (type, value) => { if (type === 'text/plain') copied = value; }}});
            view.contentDOM.dispatchEvent(copy);
            key('Backspace'); key('Enter');
            const unchanged = view.state.doc.toString();
            key('ArrowLeft'); key('ArrowRight', {shiftKey: true});
            const selectedCharacter = view.state.sliceDoc(view.state.selection.main.from, view.state.selection.main.to);
            document.getElementById('context').click();
            for (let i = 0; i < 5; i++) window.__layoutTestFrame();
            const expanded = !document.querySelector('.cm-collapsedLines');
            document.getElementById('context').click();
            for (let i = 0; i < 5; i++) window.__layoutTestFrame();
            return {initialCollapsed, selectedAll, copied, unchanged, selectedCharacter, expanded,
                collapsedAgain: !!document.querySelector('.cm-collapsedLines')};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertGreaterThan(values["initialCollapsed"] as? Int ?? 0, 0)
        XCTAssertEqual(values["selectedAll"] as? Bool, true)
        XCTAssertEqual(values["copied"] as? String, disk)
        XCTAssertEqual(values["unchanged"] as? String, disk.replacingOccurrences(of: "\r\n", with: "\n"))
        XCTAssertEqual(values["selectedCharacter"] as? String, "L")
        XCTAssertEqual(values["expanded"] as? Bool, true)
        XCTAssertEqual(values["collapsedAgain"] as? Bool, true)
    }

    func testLineEndingOnlyConflictIsExplained() async throws {
        let page = try await comparison(disk: "a\r\nb\r\n", draft: "a\nb\n")
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            return {changes: window.__conflictDiff.chunks.length,
                notice: document.getElementById('line-endings').textContent,
                visible: !document.getElementById('line-endings').hidden,
                nextDisabled: document.getElementById('next').disabled};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(values["changes"] as? Int, 0)
        XCTAssertEqual(values["visible"] as? Bool, true)
        XCTAssertEqual(values["nextDisabled"] as? Bool, true)
        XCTAssertEqual(values["notice"] as? String, "Line endings differ. On disk: CRLF; draft: LF.")
    }

    func testComparisonPaletteAndNavigationLabels() async throws {
        let page = try await comparison(disk: "Disk value\n", draft: "Draft value\n")
        defer { page.close() }
        let result = try await page.webView.callAsyncJavaScript("""
            const gutter = document.querySelector('.cm-gutters');
            const word = document.querySelector('.cm-changedText');
            return {gutterColor: getComputedStyle(gutter).color, bodyColor: getComputedStyle(document.body).color,
                underline: getComputedStyle(word).backgroundImage,
                nextLabel: document.getElementById('next').getAttribute('aria-label'),
                positionLive: document.getElementById('position').getAttribute('aria-live')};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertNotEqual(values["gutterColor"] as? String, values["bodyColor"] as? String)
        XCTAssertEqual(values["underline"] as? String, "none")
        XCTAssertEqual(values["nextLabel"] as? String, "Next Change")
        XCTAssertEqual(values["positionLive"] as? String, "polite")
    }

    private func comparison(disk: String, draft: String) async throws -> WebViewLayoutHarness {
        let script = try TestVendor.script("md-preview/Vendor/CodeMirror/mdconflict.min.js")
        let page = WebViewLayoutHarness(
            html: ConflictDiffHTML.render(disk: disk, draft: draft, javaScript: script),
            width: 820, isEditor: false, height: 420)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if !page.webView.isLoading,
               (try? await page.webView.evaluateJavaScript("window.__conflictReady === true")) as? Bool == true {
                _ = try await page.webView.evaluateJavaScript("for (let i = 0; i < 5; i++) window.__layoutTestFrame()")
                return page
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        page.close()
        throw NSError(domain: "ConflictDiffTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Conflict comparison did not load"])
    }
}
