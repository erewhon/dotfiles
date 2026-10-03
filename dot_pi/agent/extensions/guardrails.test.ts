// Run from the dotfiles tree: bun test dot_pi/agent/extensions

import { describe, expect, test } from "bun:test";
import { DEFAULT_BUDGET, type Fence, fenceBash, fencePath, MAX_REFUSALS, newState, onAgentStart, onToolCall, onToolResult, SCOUT_LIFT, SCOUT_MAX_REFUSALS } from "./guardrails.ts";

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

describe("scouting mode", () => {
	const OUT = "/tmp/fl-cal/run6/H01";
	const call = (s: ReturnType<typeof newState>, toolName: string, input: Record<string, unknown> = {}) => onToolCall(s, { toolName, input, parentToolCallId: undefined });
	const state = () => {
		const s = newState(CWD, true, DEFAULT_BUDGET, OUT);
		s.fence.roots = roots;
		return s;
	};
	const spend = (s: ReturnType<typeof newState>) => {
		for (let i = 0; i < DEFAULT_BUDGET; i++) expect(call(s, "bash", { command: "rg -n x forge" })).toBeUndefined();
	};

	test("subagent is budgeted like any other tool", () => {
		const s = state();
		spend(s);
		expect(call(s, "subagent", { agent: "scout", task: "run this" })?.block).toBe(true);
	});
	test("the refusal names the deliverable and says to write no viable seed", () => {
		const s = state();
		spend(s);
		const r = call(s, "read", { path: "forge/cli.py" });
		expect(r?.reason).toContain(`${OUT}/seed.md`);
		expect(r?.reason).toMatch(/no viable seed/);
		expect(r?.terminate).toBe(false);
	});
	test("a write to the deliverable is never refused or counted, and lifts the budget by SCOUT_LIFT", () => {
		const s = state();
		spend(s);
		expect(call(s, "bash", { command: "ls" })?.block).toBe(true);
		expect(call(s, "write", { path: `${OUT}/seed.md`, content: "# x" })).toBeUndefined();
		expect(s.calls).toBe(DEFAULT_BUDGET + 1);
		onToolResult(s, { toolName: "write", isError: false, input: { path: `${OUT}/seed.md` } });
		for (let i = 0; i < SCOUT_LIFT - 1; i++) expect(call(s, "bash", { command: `cat >> ${OUT}/seed.md <<'EOF'\nx\nEOF` })).toBeUndefined();
		const r = call(s, "bash", { command: "git status --short" });
		expect(r?.block).toBe(true);
		expect(r?.reason).toMatch(/Finish now/);
		expect(call(s, "write", { path: `${OUT}/repro.py`, content: "assert 1" })).toBeUndefined();
	});
	test("a write elsewhere counts and does not lift", () => {
		const s = state();
		spend(s);
		expect(call(s, "write", { path: "/tmp/scratch/refcas.py", content: "x" })?.block).toBe(true);
		onToolResult(s, { toolName: "write", isError: false, input: { path: "/tmp/scratch/refcas.py" } });
		expect(s.edited).toBe(false);
	});
	test("three refusals do not end the run; SCOUT_MAX_REFUSALS do", () => {
		const s = state();
		spend(s);
		const results = [];
		for (let i = 0; i < SCOUT_MAX_REFUSALS; i++) results.push(call(s, "read", { path: "forge/cli.py" })?.terminate);
		expect(results.slice(0, MAX_REFUSALS)).toEqual([false, false, false]);
		expect(results.at(-1)).toBe(true);
	});
	test("the fence still applies to the deliverable path", () => {
		const s = newState(CWD, true, DEFAULT_BUDGET, "~/evil");
		s.fence.roots = roots;
		expect(call(s, "write", { path: "~/evil/seed.md", content: "x" })?.reason).toMatch(/Outside the project/);
	});
	test("a new agent run does not reset the budget", () => {
		const s = state();
		spend(s);
		onAgentStart(s);
		expect(call(s, "bash", { command: "ls" })?.block).toBe(true);
	});
	test("off by default", () => {
		const s = newState(CWD);
		expect(s.scoutOut).toBeUndefined();
	});
});
