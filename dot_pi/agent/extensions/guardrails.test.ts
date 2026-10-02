// Run from the dotfiles tree: bun test dot_pi/agent/extensions

import { describe, expect, test } from "bun:test";
import { DEFAULT_BUDGET, type Fence, fenceBash, fencePath, MAX_REFUSALS, newState, onAgentStart, onToolCall, onToolResult } from "./guardrails.ts";

const CWD = "/export/home/erewhon/code/smithy/forge";
const HOME = "/export/home/erewhon";
process.env.HOME = HOME;
const roots = new Set(["export", "home", "tmp", "usr", "bin", "etc", "dev", "proc", "opt", "var"]);
const fence = (): Fence => ({ cwd: CWD, allow: ["/tmp", "/usr", "/bin", "/dev", "/proc", "/opt", "/home/linuxbrew"], roots });

describe("fencePath", () => {
	test("inside the project, relative or absolute", () => {
		expect(fencePath("forge/cli.py", fence())).toBeUndefined();
		expect(fencePath(`${CWD}/forge/cli.py`, fence())).toBeUndefined();
		expect(fencePath(".", fence())).toBeUndefined();
	});
	test("the allowlist and the package caches", () => {
		expect(fencePath("/tmp/out.txt", fence())).toBeUndefined();
		expect(fencePath(`${HOME}/.cache/uv/x`, fence())).toBeUndefined();
	});
	test("home, siblings, root and climbing out", () => {
		expect(fencePath("~/.ssh/config", fence())).toBe("the home directory");
		expect(fencePath("$HOME/.claude", fence())).toBe("the home directory");
		expect(fencePath("/export/home/erewhon/code/smithy/nous/x.py", fence())).toBe("the home directory");
		expect(fencePath("/etc/passwd", fence())).toBe("another tree");
		expect(fencePath("/", fence())).toBe("the filesystem root");
		expect(fencePath("../nous/nous-py", fence())).toBe("the home directory");
		expect(fencePath("../../forge-probe", fence())).toBe("the home directory");
	});
	test("a prefix that merely shares a name is outside", () => {
		expect(fencePath(`${CWD}-probe/x`, fence())).toBe("the home directory");
	});
});

describe("fenceBash", () => {
	test("ordinary repo work passes", () => {
		for (const c of [
			"grep -rn \"resolveRole\" forge/ --include='*.py' | head",
			"uv run pytest forge/task_worker -q",
			"sed -n '/^def update_task_status/,/^def /p' forge/task_worker/nous_client.py",
			"git log --oneline -5 && git diff --stat",
			"ls -la && wc -l forge/*.py",
			"curl -s https://llm.bcc.sh/v1/models | head -c 200",
			"python3 -c 'import sys; print(sys.version)'",
			"echo $((3/2)) > /tmp/x.txt",
			"uv run ruff check forge --output-format=concise",
		]) expect(fenceBash(c, fence()), c).toBeUndefined();
	});
	test("root walks are refused", () => {
		expect(fenceBash("find / -path /proc -prune -o -name workflow.py -print 2>/dev/null | head -3", fence())).toBe("a walk of the filesystem root");
		expect(fenceBash("cd forge && find / -name '*.md' -path '*snip*'", fence())).toBe("a walk of the filesystem root");
		expect(fenceBash("ls /", fence())).toBe("a walk of the filesystem root");
	});
	test("home and sibling repos are refused", () => {
		expect(fenceBash("grep -rn prefs/snip ~/.codex 2>/dev/null", fence())).toMatch(/~\/.codex is in the home directory/);
		expect(fenceBash("cat $HOME/.ssh/config", fence())).toMatch(/home directory/);
		expect(fenceBash("sed -n '553,600p' /export/home/erewhon/code/smithy/nous/nous-py/nous_mcp/workflow.py", fence())).toMatch(/home directory/);
		expect(fenceBash("ls /export/home/erewhon/.local/share", fence())).toMatch(/home directory/);
		expect(fenceBash("cat /etc/passwd", fence())).toMatch(/\/etc\/passwd is in another tree/);
	});
	test("cd out of the tree is refused, cd inside is not", () => {
		expect(fenceBash("cd /export/home/erewhon/code/smithy/nous && git log", fence())).toMatch(/^cd to/);
		expect(fenceBash("cd ../nous && ls", fence())).toMatch(/^cd to/);
		expect(fenceBash("cd forge/tests && uv run pytest -q", fence())).toBeUndefined();
		expect(fenceBash(`cd ${CWD} && grep -rn x forge`, fence())).toBeUndefined();
	});
	test("the allowlist can be extended for a session", () => {
		const f = fence();
		f.allow.push("/export/home/erewhon/code/smithy/nous");
		expect(fenceBash("grep -rn update_task_status /export/home/erewhon/code/smithy/nous/nous-py", f)).toBeUndefined();
	});
});

describe("budget", () => {
	const call = (s: ReturnType<typeof newState>, toolName: string, input: Record<string, unknown> = {}, parent?: string) =>
		onToolCall(s, { toolName, input, parentToolCallId: parent });
	const state = () => {
		const s = newState(CWD);
		s.fence.roots = roots;
		return s;
	};

	test("twelve reads pass, the thirteenth is refused with the delegation hint", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET; i++) expect(call(s, "read", { path: "forge/cli.py" })).toBeUndefined();
		const r = call(s, "bash", { command: "grep -rn x forge" });
		expect(r?.block).toBe(true);
		expect(r?.reason).toMatch(/scout/);
		expect(r?.terminate).toBe(false);
	});
	test("an edit lifts the budget", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET; i++) call(s, "read", { path: "forge/cli.py" });
		expect(call(s, "edit", { path: "forge/cli.py" })).toBeUndefined();
		onToolResult(s, { toolName: "edit", isError: false });
		expect(call(s, "bash", { command: "uv run pytest -q" })).toBeUndefined();
	});
	test("a failed edit does not", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET; i++) call(s, "read", { path: "forge/cli.py" });
		onToolResult(s, { toolName: "edit", isError: true });
		expect(call(s, "bash", { command: "ls" })?.block).toBe(true);
	});
	test("write and subagent are never budgeted", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET + 3; i++) call(s, "read", { path: "forge/cli.py" });
		expect(call(s, "write", { path: "forge/new.py" })).toBeUndefined();
		expect(call(s, "subagent", { agent: "scout", task: "find x" })).toBeUndefined();
	});
	test("a new run resets the count", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET + 1; i++) call(s, "read", { path: "forge/cli.py" });
		onAgentStart(s);
		expect(call(s, "read", { path: "forge/cli.py" })).toBeUndefined();
	});
	test("three refusals in a row end the run", () => {
		const s = state();
		for (let i = 0; i < DEFAULT_BUDGET; i++) call(s, "read", { path: "forge/cli.py" });
		const results = [];
		for (let i = 0; i < MAX_REFUSALS; i++) results.push(call(s, "read", { path: "forge/cli.py" }));
		expect(results.map((r) => r?.terminate)).toEqual([false, false, true]);
	});
	test("a script's inner calls are fenced but not counted", () => {
		const s = state();
		expect(call(s, "codemode", { code: "..." })).toBeUndefined();
		for (let i = 0; i < 30; i++) expect(call(s, "bash", { command: "grep -rn x forge" }, "call-1")).toBeUndefined();
		expect(call(s, "bash", { command: "cat ~/.ssh/config" }, "call-1")?.block).toBe(true);
		expect(s.calls).toBe(1);
	});
	test("the fence is checked before the budget and off means off", () => {
		const s = state();
		expect(call(s, "read", { path: "/export/home/erewhon/.pi/agent/settings.json" })?.reason).toMatch(/Outside the project/);
		s.enabled = false;
		expect(call(s, "read", { path: "/export/home/erewhon/.pi/agent/settings.json" })).toBeUndefined();
	});
});
