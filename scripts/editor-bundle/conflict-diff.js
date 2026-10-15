import { Compartment, EditorState } from "@codemirror/state"
import { EditorView, lineNumbers } from "@codemirror/view"
import { MergeView } from "@codemirror/merge"

// This view never edits either snapshot. The native sheet owns resolution.
window.MDConflictDiff = (disk, draft, labels) => {
  const host = document.getElementById("comparison")
  host.replaceChildren()
  const appearance = new Compartment()
  const media = matchMedia("(prefers-color-scheme: dark)")
  const theme = () => EditorView.theme({
    "&": { fontSize: "12px", backgroundColor: "transparent", color: "inherit" },
    ".cm-scroller": { fontFamily: "ui-monospace, Menlo, monospace" },
    ".cm-content": { padding: "8px 0" },
    ".cm-gutters": { backgroundColor: "transparent", color: "inherit" },
  }, { dark: media.matches })
  const extensions = [
    EditorState.readOnly.of(true), EditorView.editable.of(false),
    EditorView.lineWrapping, lineNumbers(),
    appearance.of(theme()),
  ]
  const merge = new MergeView({
    parent: host,
    a: { doc: disk, extensions: [...extensions,
      EditorView.contentAttributes.of({ "aria-label": labels.disk, tabindex: "0" })] },
    b: { doc: draft, extensions: [...extensions,
      EditorView.contentAttributes.of({ "aria-label": labels.draft, tabindex: "0" })] },
    highlightChanges: true,
    gutter: true,
  })
  document.getElementById("disk-title").textContent = labels.disk
  document.getElementById("draft-title").textContent = labels.draft
  let current = -1
  const navigate = direction => {
    if (!merge.chunks.length) return
    current = (current + direction + merge.chunks.length) % merge.chunks.length
    const chunk = merge.chunks[current]
    for (const [view, from] of [[merge.a, chunk.fromA], [merge.b, chunk.fromB]]) {
      view.dispatch({ effects: EditorView.scrollIntoView(Math.min(from, view.state.doc.length), { y: "center" }) })
    }
  }
  for (const [id, label, direction] of [["previous", labels.previous, -1], ["next", labels.next, 1]]) {
    const button = document.getElementById(id)
    button.textContent = label
    button.disabled = !merge.chunks.length
    button.onclick = () => navigate(direction)
  }
  media.addEventListener("change", () => {
    for (const view of [merge.a, merge.b]) view.dispatch({ effects: appearance.reconfigure(theme()) })
  })
  // Expose the rendered snapshots for WebKit regression tests, not a save bridge.
  window.__conflictDiff = merge
  window.__conflictReady = true
  requestAnimationFrame(() => navigate(1))
}
