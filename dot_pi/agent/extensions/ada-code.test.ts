// Run from the dotfiles tree: bun test dot_pi/agent/extensions
// chezmoi never installs this file (.chezmoiignore), so pi never loads it as an extension.

import { describe, expect, test } from "bun:test";
import type { Message } from "@earendil-works/pi-ai";
import { type AdaRequest, type AdaState, decideTier, nextState, PROVIDER, type Registry, ROLE, routeAdaCode } from "./ada-code.ts";

type Model = AdaRequest["model"];

const model = (id: string): Model => ({ id, provider: PROVIDER, api: "openai-completions", name: id } as unknown as Model);
const coder = model("coder");
const thinker = model("thinker");
const virtual = model("ada-code");

const registry: Registry = {
	find: (provider, id) => (provider === PROVIDER && (id === "coder" || id === "thinker") ? model(id) : undefined),
};

const user = (text: string) => ({ role: "user", content: text, timestamp: 0 }) as unknown as Message;

function request(overrides: Partial<AdaRequest> = {}): AdaRequest {
	return { model: virtual, thinkingLevel: "off", reason: "user", messages: [user("hi")], ...overrides };
}

describe("decideTier", () => {
	test("off selects the front", () => expect(decideTier(request({ thinkingLevel: "off" }))).toBe("off"));
	test("high selects the escalation tier", () => expect(decideTier(request({ thinkingLevel: "high" }))).toBe("high"));
	test("any other level counts as escalation", () => expect(decideTier(request({ thinkingLevel: "medium" }))).toBe("high"));
});

describe("user requests", () => {
	test("off routes to the coder role with thinking off", () => {
		const route = routeAdaCode(request({ thinkingLevel: "off" }), registry);
		expect(route.model.id).toBe(ROLE.off);
		expect(route.thinkingLevel).toBe("off");
		expect(route.state).toEqual({ tier: "off", since: 1 });
	});

	test("high routes to the thinker role with thinking on", () => {
		const route = routeAdaCode(request({ thinkingLevel: "high" }), registry);
		expect(route.model.id).toBe(ROLE.high);
		expect(route.thinkingLevel).toBe("high");
		expect(route.state).toEqual({ tier: "high", since: 1 });
	});

	test("a missing role fails with a clear error", () => {
		const stale: Registry = { find: () => undefined };
		expect(() => routeAdaCode(request(), stale)).toThrow("llm-router/coder is not in the router catalog");
	});
});

describe("stickiness", () => {
	const previous = { model: thinker, thinkingLevel: "high" as const };
	const state: AdaState = { tier: "high", since: 1 };

	test("continuations stay on the model that handled the turn, even after the level is lowered", () => {
		const route = routeAdaCode(request({ reason: "continuation", thinkingLevel: "off", previous, state, messages: [user("a"), user("b")] }), registry);
		expect(route.model).toBe(thinker);
		expect(route.thinkingLevel).toBe("high");
		expect(route.state).toBe(state);
	});

	test("retries stay on the failed model, including a context overflow", () => {
		const failed = { model: coder, thinkingLevel: "off" as const, message: { errorMessage: "context length exceeded" } as never };
		const route = routeAdaCode(request({ reason: "retry", thinkingLevel: "high", previous, failed, state }), registry);
		expect(route.model).toBe(coder);
		expect(route.thinkingLevel).toBe("off");
		expect(route.state).toBe(state);
	});

	test("a continuation with nothing to stick to routes like a user request", () => {
		const route = routeAdaCode(request({ reason: "continuation", thinkingLevel: "high" }), registry);
		expect(route.model.id).toBe("thinker");
	});

	test("direct requests go to the front and carry no state", () => {
		const route = routeAdaCode(request({ reason: "direct", thinkingLevel: "high", previous, state }), registry);
		expect(route.model.id).toBe("coder");
		expect(route.state).toBeUndefined();
	});
});

describe("state transitions", () => {
	test("the same tier keeps the stored state object", () => {
		const state: AdaState = { tier: "off", since: 1 };
		expect(nextState(request({ state, messages: [user("a"), user("b"), user("c")] }), "off")).toBe(state);
	});

	test("a tier change records where it happened", () => {
		const state: AdaState = { tier: "off", since: 1 };
		expect(nextState(request({ state, messages: [user("a"), user("b"), user("c")] }), "high")).toEqual({ tier: "high", since: 3 });
	});

	test("raising then lowering the level produces two transitions", () => {
		const first = routeAdaCode(request({ thinkingLevel: "high" }), registry);
		const second = routeAdaCode(request({ thinkingLevel: "off", state: first.state, previous: { model: thinker, thinkingLevel: "high" }, messages: [user("a"), user("b")] }), registry);
		expect(first.state).toEqual({ tier: "high", since: 1 });
		expect(second.state).toEqual({ tier: "off", since: 2 });
		expect(second.model.id).toBe("coder");
	});
});
