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
            return {scroll: view.dom.scrollTop,
                changes: view.chunks.length, disk: view.a.state.doc.toString(), draft: view.b.state.doc.toString()};
            """, arguments: [:], in: nil, contentWorld: .page)
        let values = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(values["changes"] as? Int, 2)
        XCTAssertGreaterThan(values["scroll"] as? Double ?? 0, 500)
        XCTAssertEqual(values["disk"] as? String, disk)
        XCTAssertEqual(values["draft"] as? String, draft)
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
