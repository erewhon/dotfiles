/**
 * turn-stats: per-turn timing and token stats.
 *
 * After every assistant response, appends a dim one-line entry to the
 * transcript: end time, wall-clock duration, tokens in/out (+cache),
 * output tokens/sec, and cost. When an agent run finishes (prompt -> final
 * answer, including all tool calls), appends a summary line for the run.
 *
 * Entries are session-persisted but never sent to the LLM. In print mode
 * (`pi -p`) the same lines go to stderr instead.
 *
 * `/turnstats` toggles it on/off for the session.
 */

import type { AssistantMessage, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

const ENTRY = "turn-stats";

interface TurnStats {
	kind: "turn" | "run";
	turnIndex?: number;
	turns?: number;
	endedAt: number;
	elapsedMs: number;
	model: string;
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	reasoning?: number;
	cost: number;
}

const fmtTok = (n: number) => (n < 1000 ? `${n}` : `${(n / 1000).toFixed(1)}k`);
const fmtDur = (ms: number) => (ms < 1000 ? `${ms}ms` : ms < 60_000 ? `${(ms / 1000).toFixed(1)}s` : `${Math.floor(ms / 60_000)}m${Math.round((ms % 60_000) / 1000)}s`);
const fmtTime = (t: number) => new Date(t).toLocaleTimeString([], { hour12: false });

function emptyUsage(): Usage {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
}

function addUsage(a: Usage, b: Usage): Usage {
	return {
		input: a.input + b.input,
		output: a.output + b.output,
		cacheRead: a.cacheRead + b.cacheRead,
		cacheWrite: a.cacheWrite + b.cacheWrite,
		reasoning: a.reasoning === undefined && b.reasoning === undefined ? undefined : (a.reasoning ?? 0) + (b.reasoning ?? 0),
		totalTokens: a.totalTokens + b.totalTokens,
		cost: {
			input: a.cost.input + b.cost.input,
			output: a.cost.output + b.cost.output,
			cacheRead: a.cost.cacheRead + b.cost.cacheRead,
			cacheWrite: a.cost.cacheWrite + b.cost.cacheWrite,
			total: a.cost.total + b.cost.total,
		},
	};
}

function formatLine(s: TurnStats): string {
	const label = s.kind === "turn" ? `turn ${s.turnIndex}` : `run (${s.turns} turn${s.turns === 1 ? "" : "s"})`;
	const cache = s.cacheRead || s.cacheWrite ? ` (cache r${fmtTok(s.cacheRead)} w${fmtTok(s.cacheWrite)})` : "";
	const reasoning = s.reasoning ? ` think ${fmtTok(s.reasoning)}` : "";
	const tps = s.elapsedMs > 0 && s.output > 0 ? ` · ${(s.output / (s.elapsedMs / 1000)).toFixed(0)} tok/s` : "";
	const cost = s.cost > 0 ? ` · $${s.cost.toFixed(4)}` : "";
	return `⏱ ${label} · ended ${fmtTime(s.endedAt)} · ${fmtDur(s.elapsedMs)} · ↑${fmtTok(s.input)}${cache} ↓${fmtTok(s.output)}${reasoning}${tps}${cost} · ${s.model}`;
}

export default function (pi: ExtensionAPI) {
	let enabled = true;
	let turnStart = 0;
	let runStart = 0;
	let runTurns = 0;
	let runUsage = emptyUsage();

	pi.registerEntryRenderer(ENTRY, (entry, _opts, theme) => {
		return new Text(theme.fg("dim", formatLine(entry.data as TurnStats)), 0, 0);
	});

	const emit = (ctx: { hasUI: boolean }, s: TurnStats) => {
		if (ctx.hasUI) pi.appendEntry(ENTRY, s);
		else process.stderr.write(`${formatLine(s)}\n`);
	};

	pi.on("agent_start", async () => {
		runStart = Date.now();
		runTurns = 0;
		runUsage = emptyUsage();
	});

	pi.on("turn_start", async (event) => {
		turnStart = event.timestamp || Date.now();
	});

	pi.on("turn_end", async (event, ctx) => {
		if (!enabled || event.message.role !== "assistant") return;
		const m = event.message as AssistantMessage;
		const now = Date.now();
		runTurns++;
		runUsage = addUsage(runUsage, m.usage);
		emit(ctx, {
			kind: "turn",
			turnIndex: event.turnIndex,
			endedAt: now,
			elapsedMs: now - turnStart,
			model: m.responseModel || m.model,
			input: m.usage.input,
			output: m.usage.output,
			cacheRead: m.usage.cacheRead,
			cacheWrite: m.usage.cacheWrite,
			reasoning: m.usage.reasoning,
			cost: m.usage.cost.total,
		});
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!enabled || runTurns < 2) return; // single-turn runs already have their line
		const now = Date.now();
		emit(ctx, {
			kind: "run",
			turns: runTurns,
			endedAt: now,
			elapsedMs: now - runStart,
			model: ctx.model?.id ?? "?",
			input: runUsage.input,
			output: runUsage.output,
			cacheRead: runUsage.cacheRead,
			cacheWrite: runUsage.cacheWrite,
			reasoning: runUsage.reasoning,
			cost: runUsage.cost.total,
		});
	});

	pi.registerCommand("turnstats", {
		description: "Toggle per-turn timing and token stats",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			if (ctx.hasUI) ctx.ui.notify(`turn-stats ${enabled ? "on" : "off"}`, "info");
		},
	});
}
