/**
 * turn-stats: per-turn timing and token stats.
 *
 * After every assistant response, appends a one-line entry to the
 * transcript: end time, wall-clock duration, tokens in/out (+cache),
 * output tokens/sec, and cost. When an agent run finishes (prompt -> final
 * answer, including all tool calls), appends a summary line for the run.
 *
 * Each field has its own colour, taken from the active theme so light and
 * dark themes both stay readable. Output speed is coloured by value: red
 * when slow, yellow in between, green when fast; replies too short to judge
 * stay neutral.
 *
 * Entries are session-persisted but never sent to the LLM. In print mode
 * (`pi -p`) the same lines go to stderr instead, uncoloured.
 *
 * `/turnstats` toggles it on/off for the session.
 */

import type { AssistantMessage, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
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

/** Output speed below SLOW is red, below OK is yellow, otherwise green. */
const SLOW_TPS = 10;
const OK_TPS = 30;
/**
 * Speed is output tokens over wall-clock time, so a short reply is dominated
 * by time-to-first-token and reads as slow. Below this many output tokens the
 * figure is shown but not judged.
 */
const MIN_JUDGED_TOKENS = 50;

type Segment = { text: string; color: ThemeColor; bold?: boolean };

/** One group per " · " separated field; a group is one or more coloured segments. */
function segments(s: TurnStats): Segment[][] {
	const groups: Segment[][] = [];
	const label = s.kind === "turn" ? `turn ${s.turnIndex}` : `run (${s.turns} turn${s.turns === 1 ? "" : "s"})`;
	groups.push([{ text: `⏱ ${label}`, color: "accent", bold: s.kind === "run" }]);
	groups.push([{ text: `ended ${fmtTime(s.endedAt)}`, color: "muted" }]);
	groups.push([{ text: fmtDur(s.elapsedMs), color: "mdLink" }]);

	const tokens: Segment[] = [{ text: `↑${fmtTok(s.input)}`, color: "syntaxKeyword" }];
	if (s.cacheRead || s.cacheWrite) tokens.push({ text: ` (cache r${fmtTok(s.cacheRead)} w${fmtTok(s.cacheWrite)})`, color: "dim" });
	tokens.push({ text: ` ↓${fmtTok(s.output)}`, color: "success" });
	if (s.reasoning) tokens.push({ text: ` think ${fmtTok(s.reasoning)}`, color: "thinkingText" });
	groups.push(tokens);

	if (s.elapsedMs > 0 && s.output > 0) {
		const tps = s.output / (s.elapsedMs / 1000);
		const color: ThemeColor = s.output < MIN_JUDGED_TOKENS ? "muted" : tps < SLOW_TPS ? "error" : tps < OK_TPS ? "warning" : "success";
		groups.push([{ text: `${tps.toFixed(0)} tok/s`, color }]);
	}
	if (s.cost > 0) groups.push([{ text: `$${s.cost.toFixed(4)}`, color: "warning" }]);
	groups.push([{ text: s.model, color: "muted" }]);
	return groups;
}

function formatLine(s: TurnStats): string {
	return segments(s)
		.map((group) => group.map((seg) => seg.text).join(""))
		.join(" · ");
}

function formatStyled(s: TurnStats, theme: Theme): string {
	const paint = (seg: Segment) => (seg.bold ? theme.bold(theme.fg(seg.color, seg.text)) : theme.fg(seg.color, seg.text));
	return segments(s)
		.map((group) => group.map(paint).join(""))
		.join(theme.fg("dim", " · "));
}

export default function (pi: ExtensionAPI) {
	let enabled = true;
	let turnStart = 0;
	let runStart = 0;
	let runTurns = 0;
	let runUsage = emptyUsage();

	pi.registerEntryRenderer(ENTRY, (entry, _opts, theme) => {
		return new Text(formatStyled(entry.data as TurnStats, theme), 0, 0);
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
