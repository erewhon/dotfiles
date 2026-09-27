/**
 * llm-router: register the LLM router as a provider and discover its models
 * from the router itself, instead of a hand-maintained list in models.json.
 *
 * The catalog comes from the router's public `/.well-known/opencode` document
 * (the same one OpenCode bootstraps from): every routable chat model, alias
 * and role, with context/output limits and per-million-token prices. The
 * router renders it from each upstream's live listing, so a model that is
 * powered down drops out and comes back on its own.
 *
 * Startup uses the network when it answers quickly and the last good catalog
 * (~/.cache/pi/llm-router-models.json) when it does not, so Pi still starts
 * with a model list offline. `/model` refreshes the list.
 *
 * Environment:
 *   LLM_ROUTER_BASE_URL     OpenAI-compatible base (default https://llm.bcc.sh/v1)
 *   LLM_ROUTER_CATALOG_URL  catalog document (default <base origin>/.well-known/opencode)
 *   LLM_ROUTER_API_KEY      personal access token; when unset the key comes
 *                           from `ho secret get llm-router/pi-api-key`
 *
 * The router does not publish capabilities yet, so every model is registered
 * as text-only and non-reasoning unless the catalog says otherwise. Correct a
 * specific model with `modelOverrides` in ~/.pi/agent/models.json.
 */

import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";

const PROVIDER = "llm-router";
const BASE_URL = (process.env.LLM_ROUTER_BASE_URL || "https://llm.bcc.sh/v1").replace(/\/+$/, "");
const CATALOG_URL = process.env.LLM_ROUTER_CATALOG_URL || new URL("/.well-known/opencode", BASE_URL).toString();
const CACHE_FILE = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "pi", "llm-router-models.json");

const STARTUP_TIMEOUT_MS = 3_000;
const REFRESH_TIMEOUT_MS = 10_000;
/** Startup and the first `/model` land within seconds of each other; fetch once. */
const FRESH_MS = 30_000;

const DEFAULT_CONTEXT = 131_072;
const DEFAULT_OUTPUT = 32_768;

/** Verified against the router: it rejects the developer role and ignores reasoning_effort. */
const COMPAT = { supportsDeveloperRole: false, supportsReasoningEffort: false };

interface CatalogModel {
	name?: string;
	limit?: { context?: number; output?: number };
	cost?: { input?: number; output?: number; cache_read?: number; cache_write?: number };
	// OpenCode schema fields the router may start publishing.
	reasoning?: boolean;
	attachment?: boolean;
	modalities?: { input?: string[] };
}

const posInt = (v: unknown, fallback: number) => (typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : fallback);
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : 0);

/** Pull the model map out of the well-known document, whatever the provider id is. */
function parseCatalog(doc: unknown): ProviderModelConfig[] {
	const providers = (doc as { config?: { provider?: Record<string, { models?: Record<string, CatalogModel> }> } })?.config?.provider;
	if (!providers || typeof providers !== "object") throw new Error("catalog has no config.provider block");

	const models = new Map<string, ProviderModelConfig>();
	for (const provider of Object.values(providers)) {
		for (const [id, m] of Object.entries(provider?.models ?? {})) {
			if (!id || typeof m !== "object" || m === null) continue;
			const image = m.attachment === true || (m.modalities?.input ?? []).includes("image");
			models.set(id, {
				id,
				name: typeof m.name === "string" && m.name ? m.name : id,
				reasoning: m.reasoning === true,
				input: image ? ["text", "image"] : ["text"],
				cost: { input: num(m.cost?.input), output: num(m.cost?.output), cacheRead: num(m.cost?.cache_read), cacheWrite: num(m.cost?.cache_write) },
				contextWindow: posInt(m.limit?.context, DEFAULT_CONTEXT),
				maxTokens: posInt(m.limit?.output, DEFAULT_OUTPUT),
				compat: COMPAT,
			});
		}
	}
	if (models.size === 0) throw new Error("catalog lists no models");
	return [...models.values()].sort((a, b) => a.id.localeCompare(b.id));
}

async function fetchCatalog(timeoutMs: number, signal?: AbortSignal): Promise<ProviderModelConfig[]> {
	const timeout = AbortSignal.timeout(timeoutMs);
	const response = await fetch(CATALOG_URL, {
		headers: { accept: "application/json" },
		signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
	});
	if (!response.ok) throw new Error(`${CATALOG_URL} answered ${response.status}`);
	return parseCatalog(await response.json());
}

async function readCache(): Promise<ProviderModelConfig[]> {
	try {
		const cached = JSON.parse(await readFile(CACHE_FILE, "utf8")) as { catalogUrl?: string; models?: ProviderModelConfig[] };
		// A cache written for another router (home vs work) is not this router's catalog.
		if (cached.catalogUrl !== CATALOG_URL || !Array.isArray(cached.models)) return [];
		return cached.models.map((m) => ({ ...m, compat: COMPAT }));
	} catch {
		return [];
	}
}

async function writeCache(models: ProviderModelConfig[]): Promise<void> {
	try {
		await mkdir(dirname(CACHE_FILE), { recursive: true });
		const tmp = `${CACHE_FILE}.${process.pid}.tmp`;
		await writeFile(tmp, JSON.stringify({ catalogUrl: CATALOG_URL, fetchedAt: new Date().toISOString(), models }));
		await rename(tmp, CACHE_FILE);
	} catch {
		// The cache is an optimisation; a read-only home must not break the provider.
	}
}

export default async function (pi: ExtensionAPI) {
	let models: ProviderModelConfig[] = [];
	let fetchedAt = 0;

	const offline = !!process.env.PI_OFFLINE && process.env.PI_OFFLINE !== "0";
	if (!offline) {
		try {
			models = await fetchCatalog(STARTUP_TIMEOUT_MS);
			fetchedAt = Date.now();
			void writeCache(models);
		} catch {
			// Fall through to the cache: router unreachable, slow, or off the mesh.
		}
	}
	if (models.length === 0) models = await readCache();

	pi.registerProvider(PROVIDER, {
		name: "LLM Router",
		baseUrl: BASE_URL,
		api: "openai-completions",
		// Resolved by Pi at request time, never stored. The env var wins so a
		// host without `ho` (work) only needs LLM_ROUTER_API_KEY exported.
		apiKey: process.env.LLM_ROUTER_API_KEY ? "$LLM_ROUTER_API_KEY" : "!ho secret get llm-router/pi-api-key",
		models,
		refreshModels: async (context) => {
			if (!context.allowNetwork) return models;
			if (!context.force && Date.now() - fetchedAt < FRESH_MS) return models;
			try {
				models = await fetchCatalog(REFRESH_TIMEOUT_MS, context.signal);
				fetchedAt = Date.now();
				void writeCache(models);
			} catch (error) {
				// Keep the list we have; an empty picker is worse than a stale one.
				if (models.length === 0) throw error;
			}
			return models;
		},
	});
}
