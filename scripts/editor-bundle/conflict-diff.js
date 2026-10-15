import { Compartment, EditorState } from "@codemirror/state"
import { drawSelection, EditorView, keymap, lineNumbers } from "@codemirror/view"
import { standardKeymap } from "@codemirror/commands"
import { MergeView } from "@codemirror/merge"

// CodeMirror compares normalized lines. Copy from the original snapshot so
// selections retain CRLF and mixed line endings, including collapsed text.
function copySnapshot(source) {
  const starts = [0]
  for (const match of source.matchAll(/\r\n|\r|\n/g)) starts.push(match.index + match[0].length)
  return EditorView.domEventHandlers({ copy(event, view) {
    if (!event.clipboardData || view.state.selection.empty) return false
    const offset = pos => {
      const line = view.state.doc.lineAt(pos)
      return starts[line.number - 1] + pos - line.from
    }
    const text = view.state.selection.ranges.map(({ from, to }) =>
      source.slice(offset(from), offset(to))).join("\n")
    event.clipboardData.setData("text/plain", text)
    event.preventDefault()
    return true
  } })
}

// This view never edits either snapshot. The native sheet owns resolution.
window.MDConflictDiff = (disk, draft, labels) => {
  const host = document.getElementById("comparison")
  host.replaceChildren()
  const appearance = new Compartment()
  const media = matchMedia("(prefers-color-scheme: dark)")
  const theme = () => EditorView.theme({
    "&": { fontSize: "12px", lineHeight: "19px", backgroundColor: "transparent", color: "inherit" },
    ".cm-scroller": { fontFamily: "ui-monospace, Menlo, monospace" },
    ".cm-content": { padding: "8px 0" },
    ".cm-gutters": { backgroundColor: "transparent", color: "var(--secondary)", fontSize: "10px" },
  }, { dark: media.matches })
  const extensions = [
    EditorState.readOnly.of(true), EditorView.editable.of(false),
    EditorView.lineWrapping, lineNumbers(), drawSelection(), keymap.of(standardKeymap),
    EditorState.phrases.of({ "$ unchanged lines": labels.unchanged }),
    appearance.of(theme()),
  ]
  const merge = new MergeView({
    parent: host,
    a: { doc: disk, extensions: [...extensions, copySnapshot(disk),
      EditorView.contentAttributes.of({ "aria-label": labels.disk, tabindex: "0" })] },
    b: { doc: draft, extensions: [...extensions, copySnapshot(draft),
      EditorView.contentAttributes.of({ "aria-label": labels.draft, tabindex: "0" })] },
    highlightChanges: true,
    gutter: true,
    collapseUnchanged: { margin: 3, minSize: 8 },
  })
  document.getElementById("disk-title").textContent = labels.disk
  document.getElementById("draft-title").textContent = labels.draft
  document.getElementById("disk-status").textContent = labels.saved
  document.getElementById("draft-status").textContent = labels.unsaved
  document.getElementById("summary").textContent = `${labels.differences} · ${merge.chunks.length}`
  const position = document.getElementById("position")
  position.textContent = labels.noChanges
  let current = -1
  const navigate = direction => {
    if (!merge.chunks.length) return
    current = (current + direction + merge.chunks.length) % merge.chunks.length
    position.textContent = labels.position.replace("%1$d", current + 1).replace("%2$d", merge.chunks.length)
    const chunk = merge.chunks[current]
    // There is one shared scroller. A second request on the empty side of a
    // deletion would scroll past the block the user came to inspect.
    const [view, from] = chunk.fromA < chunk.toA ? [merge.a, chunk.fromA] : [merge.b, chunk.fromB]
    view.dispatch({ effects: EditorView.scrollIntoView(Math.min(from, view.state.doc.length), { y: "start", yMargin: 12 }) })
  }
  for (const [id, label, direction] of [["previous", labels.previous, -1], ["next", labels.next, 1]]) {
    const button = document.getElementById(id)
    button.setAttribute("aria-label", label)
    button.title = label
    button.disabled = !merge.chunks.length
    button.onclick = () => navigate(direction)
  }
  const context = document.getElementById("context")
  context.hidden = Math.max(merge.a.state.doc.lines, merge.b.state.doc.lines) < 20
  context.textContent = labels.showAll
  context.onclick = () => {
    const wholeFile = context.getAttribute("aria-pressed") !== "true"
    context.setAttribute("aria-pressed", String(wholeFile))
    context.textContent = wholeFile ? labels.hideUnchanged : labels.showAll
    merge.reconfigure({ collapseUnchanged: wholeFile ? undefined : { margin: 3, minSize: 8 } })
  }
  const endings = source => [...new Set(source.match(/\r\n|\r|\n/g) ?? [])]
    .map(value => ({ "\r\n": "CRLF", "\r": "CR", "\n": "LF" })[value]).sort().join(" / ") || labels.none
  if (endings(disk) !== endings(draft) || (!merge.chunks.length && disk !== draft)) {
    const notice = document.getElementById("line-endings")
    notice.hidden = false
    notice.textContent = labels.lineEndings.replace("%1$@", endings(disk)).replace("%2$@", endings(draft))
  }
  media.addEventListener("change", () => {
    for (const view of [merge.a, merge.b]) view.dispatch({ effects: appearance.reconfigure(theme()) })
  })
  // Expose the rendered snapshots for WebKit regression tests, not a save bridge.
  window.__conflictDiff = merge
  navigate(1)
  window.__conflictReady = true
}
