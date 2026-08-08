/**
 * OpenCode plugin — keep the system prompt to a single message.
 *
 * Why: the openai-compatible provider maps every entry of the system array to
 * its own {role:"system"} message. Qwen3.6-35B-A3B (llm/coder -> qwen3.6-hypatia,
 * served by Atlas, which has no --chat-template override) bundles a chat
 * template that raises on any system message that isn't `loop.first`, so a
 * *second* system entry fails even at the front of the array:
 *
 *   Tokenization error: Failed to render Jinja chat template:
 *   invalid operation: System message must be at the beginning. (in chat:85)
 *
 * OpenCode alone sends one system entry. The open-mem plugin appends its
 * "Past Session Memory" block on the same experimental.chat.system.transform
 * hook — which is why this only bit in projects where open-mem had observations
 * to inject, and why it looked intermittent.
 *
 * Plugin hooks fire in load order and this one loads *before* open-mem, so a
 * plain join here would be undone by open-mem's later push. Instead we join
 * what is already present and then override the array's own `push` so any
 * later append folds into the final entry. Order-independent in both
 * directions.
 *
 * Joining is safe across providers: segments keep their order and content, they
 * just arrive as one system message.
 */

const SEPARATOR = "\n\n";

function asText(value) {
  return typeof value === "string" ? value : String(value ?? "");
}

// Collapse to at most one entry, then make future pushes fold into it.
function collapseAndSeal(output) {
  const system = output?.system;
  if (!Array.isArray(system)) return;

  const merged = system
    .map(asText)
    .filter((s) => s.trim().length > 0)
    .join(SEPARATOR);

  system.length = 0;
  if (merged.length > 0) system.push(merged);

  if (system.__mergeSystemSealed) return;

  Object.defineProperty(system, "__mergeSystemSealed", {
    value: true,
    enumerable: false,
  });

  Object.defineProperty(system, "push", {
    value: function (...items) {
      const extra = items
        .map(asText)
        .filter((s) => s.trim().length > 0)
        .join(SEPARATOR);

      if (extra.length === 0) return this.length;

      if (this.length === 0) {
        Array.prototype.push.call(this, extra);
      } else {
        this[this.length - 1] = `${this[this.length - 1]}${SEPARATOR}${extra}`;
      }
      return this.length;
    },
    writable: true,
    configurable: true,
    enumerable: false,
  });
}

// Plugin export
export const MergeSystemPlugin = async () => {
  return {
    "experimental.chat.system.transform": async (_input, output) => {
      collapseAndSeal(output);
    },
  };
};
