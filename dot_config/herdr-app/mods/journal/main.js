// Today's work journal (`journal path`) for the focused pane's project, newest entry first.
// Runs on the pane's machine, like Files and Changes. Toggle: layout.toggle:journal (ctrl-shift-j).
import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextView } from "gpui-base";
import { spaces, panes, focused, exec, readTextFile, watchFolder, theme } from "herdr";

function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}
const key = () => JSON.stringify(location());

// Same path `journal path -C <cwd>` prints. Computed inline because the script may be
// missing on a machine, or off PATH for herdr-core's exec.
const PATH_SCRIPT = 'cd "$1" || exit 1; r=$(jj root 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || pwd -P); ' +
  'printf "%s/%s/%s.md\\n" "${JOURNAL_HOME:-$HOME/code/journals}" "$(printf %s "$r" | sed -e "s#^/##" -e "s#/#_#g")" "$(date +%F)"';

// Entries start with "## HH:MM  title"; show the newest first.
function newestFirst(text) {
  // "**Label:**" lines are separate fields; markdown would fold them into one paragraph.
  const parts = text.split(/^(?=## )/m).map((s) => s.trim().replace(/\n(?=\*\*[^*\n]+:\*\*)/g, "\n\n")).filter(Boolean);
  return parts.reverse().join("\n\n---\n\n");
}

export default class Journal extends View {
  init(_props, cx) {
    this.path = null; this.text = null; this.error = null; this.on = null;
    this.refresh(cx);
    cx.timer.every(10000, (cx) => this.refresh(cx));
  }

  watch(dir, cx) {
    if (this.on || this.watched === dir) return;
    this.watched = dir;
    cx.spawn(async (cx) => {
      try {
        while (this.watched === dir) {
          await watchFolder(dir);
          if (this.watched === dir) this.refresh(cx);
        }
      } catch { if (this.watched === dir) this.watched = null; }
    });
  }

  refresh(cx) {
    if (this.loading) return;
    const { cwd, on } = location(), context = key();
    if (!cwd) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("sh", ["-c", PATH_SCRIPT, "journal", cwd], { cwd, on, timeout: 5000 });
        if (key() !== context) return;
        if (r.code !== 0) { this.error = (r.stderr || "journal path failed").trim(); this.text = null; return; }
        const path = r.stdout.trim();
        const text = await readTextFile(path, { on });
        if (key() !== context) return;
        if (path !== this.path || on !== this.on) this.watched = null;
        this.path = path; this.on = on; this.error = null;
        this.text = text === null ? null : newestFirst(text);
        if (!on) this.watch(path.slice(0, path.lastIndexOf("/")), cx);
      } catch (e) {
        this.error = String(e?.message ?? e);
      } finally {
        this.loading = false;
        cx.notify();
      }
    });
  }

  render(cx) {
    const t = theme();
    if (key() !== this.seen) { this.seen = key(); this.refresh(cx); }
    const parts = this.path ? this.path.split("/") : [];
    const project = parts.length >= 2 ? parts[parts.length - 2] : "";
    const date = parts.length ? parts[parts.length - 1].replace(/\.md$/, "") : "";
    const header = h_flex().id("journal-header").h(30).px(10).gap(8).flex_none().items_center()
      .border_b(1).border_color(t.border).text_size(12)
      .child(div().font_semibold().text_color(t.foreground).child("Journal"))
      .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(project))
      .child(div().text_color(t.muted).child(this.on ? `${date} · ${this.on}` : date));
    let body;
    if (this.error) body = div().p(12).text_size(12).text_color(t.blocked).child(this.error);
    else if (this.text === null) body = div().p(12).text_size(12).text_color(t.dim).child(this.path ? "No entries today." : "Loading…");
    else body = TextView.markdown("journal-text", this.text).selectable(true).scrollable(true);
    return v_flex().size_full().bg(t.surface).text_color(t.foreground)
      .child(header)
      .child(div().id("journal-body").flex_1().min_h(0).px(12).py(8).text_size(13).child(body));
  }
}
