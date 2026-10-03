/**
 * guardrails: a per-turn tool budget and a repo fence for the local coding front.
 *
 * The session probe (meta/docs/pi-coding-front.md, "Session probe 2026-10") found
 * the local front's failure mode is unbounded recon, not slow rounds: 24–83 tool
 * rounds on one question, `find /` over NFS mounts, and searches of the owner's
 * home for a file the model had invented. Two signals caught every bad turn and
 * no good one: twelve rounds without an edit, and a command that leaves the repo.
 *
 * Budget: top-level tool calls are counted per agent run (one user message and
 * everything until the model settles). Past the budget, with no successful
 * edit yet, further calls are refused with a reason that tells the model to
 * answer with what it has or delegate to the `scout` subagent. edit, write and
 * subagent are never refused: an edit is progress and delegation is the escape
 * hatch. Three refusals in a row end the run so a model that keeps calling
 * does not loop on errors.
 *
 * Fence: bash commands, and the path of read/grep/find/ls/edit/write, must stay
 * under the project directory or a short allowlist (/tmp, the system prefixes
 * binaries live in, the uv and pnpm caches). `find /`, `~`, `$HOME`, sibling
 * repos and `..` past the root are refused. Calls a codemode script makes are
 * fenced too; they do not count against the budget (the script does).
 *
 * Scouting mode (`PI_GUARD_SCOUT_OUT=<dir>` or `/scout <dir>`): for sessions that run
 * a faultline-style brief whose only deliverable is a file under <dir>. Five
 * calibration runs (faultline/docs/calibration/2026-10-03) showed the local front
 * ignores every "stop at call N" instruction in a prompt and answers a budget
 * refusal by retrying the same call until three strikes end the run with nothing
 * written. So in this mode: subagent is budgeted like any tool; only a write under
 * <dir> counts as progress, and it lifts the budget by a few calls for the appends
 * rather than removing it; the refusal names the output file and tells the model
 * to write "no viable seed" to it; and refusals keep steering instead of ending the
 * run (a much higher strike count still stops a model that will not write at all).
 *
 * On by default for `llm-router/*` models only. `--no-guardrails`, `/guardrails
 * off|on|status`, `/budget N`, `/fence allow <path>`.
 */

import { readdirSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";
import type { ExtensionAPI, ToolCallEvent, ToolCallEventResult, ToolResultEvent } from "@earendil-works/pi-coding-agent";

export const DEFAULT_BUDGET = 12;
/** Refusals in a row before the run is ended. */
export const MAX_REFUSALS = 3;
export const NEVER_BUDGETED = new Set(["edit", "write", "subagent"]);
/** Scouting mode: extra calls granted once the output file exists, and the strike count. */
export const SCOUT_LIFT = 4;
export const SCOUT_MAX_REFUSALS = 10;
const PATH_TOOLS = new Set(["read", "grep", "find", "ls", "edit", "write"]);

/** Prefixes any command may touch besides the project: scratch, binaries, package caches. */
export const DEFAULT_ALLOW = ["/tmp", "/dev", "/proc", "/usr", "/bin", "/sbin", "/lib", "/lib64", "/opt", "/home/linuxbrew", "/nix"];

const home = () => process.env.HOME || homedir();

export interface Fence {
	cwd: string;
	allow: string[];
	/** Top-level directories of this host; a `/word` token is a path only when `word` is one. Tests inject it. */
	roots?: Set<string>;
}

/** Fallback when "/" cannot be listed (a sandboxed child has no read on the root). */
const COMMON_ROOTS = ["bin", "boot", "dev", "etc", "export", "home", "lib", "lib64", "mnt", "net", "nix", "opt", "proc", "root", "run", "sbin", "srv", "sys", "tmp", "usr", "var", "Users", "Volumes"];
let hostRoots: Set<string> | undefined;
function readRoots(): Set<string> {
	try {
		return new Set([...readdirSync("/"), ...COMMON_ROOTS]);
	} catch {
		return new Set(COMMON_ROOTS);
	}
}
const rootsOf = (fence: Fence) => (fence.roots ??= hostRoots ??= readRoots());

const under = (p: string, root: string) => p === root || p.startsWith(root.endsWith("/") ? root : `${root}/`);

function allowed(p: string, fence: Fence): boolean {
	const cache = `${home()}/.cache`;
	return under(p, fence.cwd) || under(p, cache) || fence.allow.some((root) => under(p, root));
}

function expand(p: string): string {
	if (p === "~" || p.startsWith("~/")) return home() + p.slice(1);
	if (p === "$HOME" || p.startsWith("$HOME/")) return home() + p.slice(5);
	return p;
}

/** Why a path is outside the fence, or undefined when it is inside. */
export function fencePath(raw: string, fence: Fence): string | undefined {
	const p = expand(raw);
	const abs = isAbsolute(p) ? resolve(p) : resolve(fence.cwd, p);
	if (abs === "/") return "the filesystem root";
	if (allowed(abs, fence)) return undefined;
	return abs.startsWith(home()) ? "the home directory" : "another tree";
}

// Absolute paths, ~ and $HOME, and relative paths that climb. URLs (://) and
// option values without a slash never match; a `/word/...` token only counts
// when `word` is a top-level directory here, so sed and grep patterns pass.
const PATH_RE = /(?<![\w@:.=-])(~(?:\/[^\s"'`;|&)]*)?|\$HOME(?:\/[^\s"'`;|&)]*)?|\/[^\s"'`;|&)]*|\.\.(?:\/[^\s"'`;|&)]*)?)/g;
const CD_RE = /(?:^|[;&|(]\s*)cd\s+([^\s;|&)]+)/g;
const ROOT_WALK_RE = /(^|[\s;&|(])(find|ls|grep|rg|fd|tree|du|locate)\s+(-\S+\s+)*\/(\s|$)/;

/** Why a bash command leaves the fence, or undefined when it stays inside. */
export function fenceBash(command: string, fence: Fence): string | undefined {
	for (const m of command.matchAll(CD_RE)) {
		const why = fencePath(m[1], fence);
		if (why) return `cd to ${why}`;
	}
	if (ROOT_WALK_RE.test(command)) return "a walk of the filesystem root";
	const roots = rootsOf(fence);
	for (const m of command.matchAll(PATH_RE)) {
		const token = m[1].replace(/[.,:]+$/, "");
		if (token.startsWith("/")) {
			const first = token.split("/")[1];
			if (!first || !roots.has(first)) continue; // "/", "/pattern/", a URL path
		}
		const why = fencePath(token, fence);
		if (why) return `${token} is in ${why}`;
	}
	return undefined;
}

export interface GuardState {
	enabled: boolean;
	budget: number;
	calls: number;
	edited: boolean;
	refusals: number;
	fence: Fence;
	/** Scouting mode: the directory the brief's deliverable must land in. */
	scoutOut?: string;
}

export function newState(cwd: string, enabled = true, budget = DEFAULT_BUDGET, scoutOut?: string): GuardState {
	return {
		enabled,
		budget,
		calls: 0,
		edited: false,
		refusals: 0,
		fence: { cwd: resolve(cwd), allow: [...DEFAULT_ALLOW] },
		scoutOut: scoutOut ? resolve(expand(scoutOut)) : undefined,
	};
}

/** In scouting mode, is this write aimed at the deliverable? */
const scoutWrite = (s: GuardState, toolName: string, input: Record<string, unknown>) =>
	s.scoutOut !== undefined && toolName === "write" && typeof input.path === "string" && under(resolve(s.fence.cwd, expand(input.path)), s.scoutOut);

/** The budget in force: scouting mode grants SCOUT_LIFT more once the deliverable exists. */
const budgetOf = (s: GuardState) => s.budget + (s.scoutOut !== undefined && s.edited ? SCOUT_LIFT : 0);

export function onAgentStart(s: GuardState): void {
	s.refusals = 0;
	// Scouting mode budgets the session, not the run: pi starts a new agent run after an
	// API error or a context compaction, and a per-run reset handed the T1 calibration
	// session a second budget mid-task (faultline docs/calibration/2026-10-03, T1 run 7).
	if (s.scoutOut !== undefined) return;
	s.calls = 0;
	s.edited = false;
}

function refuse(s: GuardState, reason: string): ToolCallEventResult {
	s.refusals += 1;
	return { block: true, reason, terminate: s.refusals >= (s.scoutOut !== undefined ? SCOUT_MAX_REFUSALS : MAX_REFUSALS) };
}

/** The guard's answer to one tool call: undefined lets it through. */
export function onToolCall(s: GuardState, event: Pick<ToolCallEvent, "toolName" | "input" | "parentToolCallId">): ToolCallEventResult | undefined {
	if (!s.enabled) return undefined;
	const input = event.input as Record<string, unknown>;

	let why: string | undefined;
	if (event.toolName === "bash" && typeof input.command === "string") why = fenceBash(input.command, s.fence);
	else if (PATH_TOOLS.has(event.toolName) && typeof input.path === "string") why = fencePath(input.path, s.fence);
	if (why) {
		return refuse(s, `Outside the project: ${why}. Stay inside ${s.fence.cwd}; if you need another repo or the home directory, stop and ask the owner.`);
	}

	if (event.parentToolCallId) return undefined; // a script's inner call; the script was counted

	if (s.scoutOut !== undefined) {
		if (scoutWrite(s, event.toolName, input)) return undefined; // the deliverable is always allowed and never counted
		s.calls += 1;
		if (s.calls > budgetOf(s)) {
			const out = `${s.scoutOut}/seed.md`;
			return refuse(
				s,
				s.edited
					? `Budget spent again (${budgetOf(s)} calls). Finish now: one \`write\` to ${out} with everything you have. Every other tool, including ${event.toolName}, is refused.`
					: `Tool budget spent (${s.budget} calls) and nothing written yet. Call \`write\` on ${out} now: a heading \`## <slug>: no viable seed\` plus what you checked and what you saw — or your seed, if you already have a repro that exits 0. Every other tool, including ${event.toolName}, is refused until that file exists.`,
			);
		}
		s.refusals = 0;
		return undefined;
	}

	s.calls += 1;
	if (s.calls > s.budget && !s.edited && !NEVER_BUDGETED.has(event.toolName)) {
		return refuse(
			s,
			`Tool budget for this turn is spent (${s.budget} calls, no edit yet). Answer now with what you have, naming what you did not get to check — or delegate the rest to the \`scout\` subagent with one precise question. Do not call ${event.toolName} again this turn.`,
		);
	}
	s.refusals = 0;
	return undefined;
}

export function onToolResult(s: GuardState, event: Pick<ToolResultEvent, "toolName" | "isError"> & { input?: Record<string, unknown> }): void {
	if (event.isError) return;
	if (s.scoutOut !== undefined) {
		if (scoutWrite(s, event.toolName, event.input ?? {})) s.edited = true;
		return;
	}
	if (event.toolName === "edit" || event.toolName === "write") s.edited = true;
}

export const summary = (s: GuardState) =>
	s.enabled ? `guard ${s.calls}/${budgetOf(s)}${s.edited ? " edited" : ""}${s.scoutOut !== undefined ? " scout" : ""}` : "guard off";

export default function (pi: ExtensionAPI) {
	pi.registerFlag("no-guardrails", { description: "Disable the tool budget and repo fence for this session", type: "boolean", default: false });
	let state: GuardState | undefined;
	const stateFor = (cwd: string) => (state ??= newState(cwd, !pi.getFlag("no-guardrails"), DEFAULT_BUDGET, process.env.PI_GUARD_SCOUT_OUT));

	pi.on("agent_start", (_event, ctx) => {
		onAgentStart(stateFor(ctx.cwd));
		ctx.ui.setStatus("guardrails", summary(stateFor(ctx.cwd)));
	});
	pi.on("tool_call", (event, ctx) => {
		const s = stateFor(ctx.cwd);
		// The fence and budget are for the local front; a frontier model on another provider is left alone.
		if (ctx.model?.provider !== "llm-router") return undefined;
		const result = onToolCall(s, event);
		ctx.ui.setStatus("guardrails", summary(s) + (result ? " refused" : ""));
		return result;
	});
	pi.on("tool_result", (event, ctx) => {
		onToolResult(stateFor(ctx.cwd), event);
	});

	pi.registerCommand("guardrails", {
		description: "guardrails on|off|status — tool budget and repo fence",
		handler: async (args, ctx) => {
			const s = stateFor(ctx.cwd);
			const arg = args.trim();
			if (arg === "on") s.enabled = true;
			else if (arg === "off") s.enabled = false;
			ctx.ui.notify(`${summary(s)} · fence ${s.fence.cwd} + ${s.fence.allow.length} allowed prefixes`, "info");
			ctx.ui.setStatus("guardrails", summary(s));
		},
	});
	pi.registerCommand("budget", {
		description: "budget N — tool calls allowed per turn before an edit (default 12)",
		handler: async (args, ctx) => {
			const s = stateFor(ctx.cwd);
			const n = Number.parseInt(args.trim(), 10);
			if (Number.isFinite(n) && n > 0) s.budget = n;
			ctx.ui.notify(summary(s), Number.isFinite(n) && n > 0 ? "info" : "warning");
			ctx.ui.setStatus("guardrails", summary(s));
		},
	});
	pi.registerCommand("scout", {
		description: "scout <dir>|off — scouting mode: the deliverable under <dir> is the only thing that lifts the budget",
		handler: async (args, ctx) => {
			const s = stateFor(ctx.cwd);
			const arg = args.trim();
			if (arg === "off" || arg === "") s.scoutOut = undefined;
			else s.scoutOut = resolve(expand(arg));
			ctx.ui.notify(s.scoutOut ? `scouting mode: deliverable under ${s.scoutOut}` : "scouting mode off", "info");
			ctx.ui.setStatus("guardrails", summary(s));
		},
	});
	pi.registerCommand("fence", {
		description: "fence allow <path> — let this session touch another tree",
		handler: async (args, ctx) => {
			const s = stateFor(ctx.cwd);
			const [verb, ...rest] = args.trim().split(/\s+/);
			if (verb === "allow" && rest[0]) s.fence.allow.push(resolve(expand(rest[0])));
			ctx.ui.notify(`fence: ${s.fence.cwd}, allowed: ${s.fence.allow.join(" ")}`, "info");
		},
	});
}
