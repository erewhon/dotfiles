/**
 * ada-code: the local coding front as a pi virtual model.
 *
 * Registers `llm-router/ada-code` with two thinking levels that map to two
 * router roles on the same vLLM pair (GLM-5.3-Flash-Spark on archimedes +
 * hypatia):
 *
 *   ada-code • off   ->  llm-router/coder    thinking off   (the front)
 *   ada-code • high  ->  llm-router/thinker  thinking on    (escalation)
 *
 * Roles rather than pinned model ids, so a seat outage degrades the way every
 * other router caller does. Both roles are one backend, so raising the level
 * mid-session keeps vLLM's prefix cache; the only cost is the thinking tokens.
 *
 * Tool follow-ups and retries stay on the physical model that handled the
 * turn, including a retry after a context overflow (pi compacts first; a
 * retry never switches tiers). Requests outside the agent loop, such as
 * compaction summaries, go to the front.
 *
 * v1 has no automatic escalation: the selected thinking level is the only
 * tier input. `decideTier()` is the hook the escalation-heuristic task fills
 * in. The current tier and the message index it started at are kept as
 * router state, so the footer and the session-probe task can see tier changes.
 *
 * The router does not publish reasoning capability, so pi clamps the
 * dispatched level to `off` for both roles; the `thinker` role carries the
 * thinking mode server-side. Mark `thinker` as `reasoning: true` in
 * ~/.pi/agent/models.json `modelOverrides` if the footer should read
 * `thinker • high`.
 */

import type { ExtensionAPI, ExtensionContext, ModelRoute, ModelRouteRequest } from "@earendil-works/pi-coding-agent";

export const PROVIDER = "llm-router";
export const MODEL_ID = "ada-code";

export type Tier = "off" | "high";
/** Router role each tier dispatches to. */
export const ROLE: Record<Tier, string> = { off: "coder", high: "thinker" };

export interface AdaState {
	tier: Tier;
	/** Index into `messages` of the first request on this tier. */
	since: number;
}

export type AdaRequest = ModelRouteRequest<AdaState>;
/** The slice of the model registry the router needs; tests stub it. */
export type Registry = Pick<ExtensionContext["modelRegistry"], "find">;

/**
 * Which tier a user request runs on. v1: the selected thinking level, and
 * nothing else. The escalation heuristic task replaces this body.
 */
export function decideTier(request: AdaRequest): Tier {
	return request.thinkingLevel === "off" ? "off" : "high";
}

export function findRole(registry: Registry, tier: Tier): ModelRoute["model"] {
	const model = registry.find(PROVIDER, ROLE[tier]);
	if (!model) throw new Error(`${PROVIDER}/${ROLE[tier]} is not in the router catalog; open /model to refresh it`);
	return model;
}

/** New state when the tier changes, `request.state` otherwise so pi keeps what it has. */
export function nextState(request: AdaRequest, tier: Tier): AdaState | undefined {
	if (request.state?.tier === tier) return request.state;
	return { tier, since: request.messages.length };
}

export function routeAdaCode(request: AdaRequest, registry: Registry): ModelRoute<AdaState> {
	// Tool follow-ups and retries stay put: keeps the prefix cache and any
	// thinking signatures, and a context-overflow retry must not change tiers.
	const sticky = request.failed ?? request.previous;
	if ((request.reason === "continuation" || request.reason === "retry") && sticky) {
		return { model: sticky.model, thinkingLevel: sticky.thinkingLevel ?? "off", state: request.state };
	}
	// Compaction summaries and extension calls: the front, no state (pi ignores it anyway).
	if (request.reason === "direct") return { model: findRole(registry, "off"), thinkingLevel: "off" };

	const tier = decideTier(request);
	return { model: findRole(registry, tier), thinkingLevel: tier, state: nextState(request, tier) };
}

export const isAdaCode = (model: { provider: string; id: string } | undefined) => model?.provider === PROVIDER && model.id === MODEL_ID;

export default function (pi: ExtensionAPI) {
	pi.registerVirtualModel<AdaState>({
		provider: PROVIDER,
		id: MODEL_ID,
		name: "Ada code",
		thinkingLevels: ["off", "high"],
		// The GLM pair's limits, shown until the first response names a physical model.
		contextWindow: 262_144,
		maxTokens: 65_536,
		input: ["text"],
		route: (request, ctx) => routeAdaCode(request, ctx.modelRegistry),
	});

	// Pi clamps the session's level (`defaultThinkingLevel`, medium) to the
	// nearest offered level, which lands on `high`. The front is the default;
	// escalation is a deliberate act. A resumed or forked session keeps its own
	// level, and so does an explicit `--thinking` on the command line.
	pi.on("model_select", (event) => {
		if (event.source !== "restore" && isAdaCode(event.model) && !isAdaCode(event.previousModel)) pi.setThinkingLevel("off");
	});
	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup" && event.reason !== "new") return;
		if (isAdaCode(ctx.model) && !process.argv.includes("--thinking")) pi.setThinkingLevel("off");
	});
}
