/**
 * OpenCode hooks plugin — port of Claude Code's Python hooks.
 *
 * Provides:
 *   - Session idle (stop): logs event, generates TTS completion message
 *   - Session compacting (pre-compact): backs up transcript
 *   - Message updated (notification): TTS "agent needs input" for questions
 *
 * TTS and LLM calls shell out to the existing Python scripts in ~/.claude/hooks/
 * so both tools share the same TTS infrastructure.
 */

import { execFile, execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const HOOKS_DIR = join(homedir(), ".claude", "hooks");
const TTS_DIR = join(HOOKS_DIR, "utils", "tts");
const LLM_DIR = join(HOOKS_DIR, "utils", "llm");
const OPENCODE_STORAGE = join(homedir(), ".local", "share", "opencode", "storage");
const CHATS_ROOT = join(homedir(), "code", "chats");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function ensureDir(dir) {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

// Why: full cwd path (with `/` -> `_`) keeps worktrees and same-named
// repos in different parents from colliding.
function chatsDirFor(cwd) {
  const sanitized = cwd.replace(/^\/+/, "").replace(/\//g, "_") || "root";
  const target = join(CHATS_ROOT, sanitized);
  ensureDir(target);
  return target;
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_${pad(d.getHours())}-${pad(d.getMinutes())}-${pad(d.getSeconds())}`;
}

// Read all message files for a session from OpenCode's on-disk storage,
// sorted by filename (monotonic msg id).
function readSessionMessages(sessionId) {
  const dir = join(OPENCODE_STORAGE, "message", sessionId);
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir).filter((f) => f.endsWith(".json")).sort();
  const messages = [];
  for (const f of files) {
    try {
      messages.push(JSON.parse(readFileSync(join(dir, f), "utf-8")));
    } catch {
      // skip malformed
    }
  }
  return messages;
}

// ---------------------------------------------------------------------------
// TTS — reuse the existing Python scripts
// ---------------------------------------------------------------------------

function getTtsScript() {
  if (process.env.ELEVENLABS_API_KEY) {
    const p = join(TTS_DIR, "elevenlabs_tts.py");
    if (existsSync(p)) return p;
  }
  if (process.env.OPENAI_API_KEY) {
    const p = join(TTS_DIR, "openai_tts.py");
    if (existsSync(p)) return p;
  }
  const p = join(TTS_DIR, "pyttsx3_tts.py");
  if (existsSync(p)) return p;
  return null;
}

function speak(text) {
  const script = getTtsScript();
  if (!script) return;
  try {
    execFile("uv", ["run", script, text], { timeout: 10_000 }, () => {});
  } catch {
    // fail silently
  }
}

// ---------------------------------------------------------------------------
// LLM completion message — reuse existing Python scripts
// ---------------------------------------------------------------------------

function getCompletionMessage() {
  const fallbacks = [
    "Work complete!",
    "All done!",
    "Task finished!",
    "Job complete!",
    "Ready for next task!",
  ];

  // Try OpenAI script
  if (process.env.OPENAI_API_KEY) {
    const script = join(LLM_DIR, "oai.py");
    if (existsSync(script)) {
      try {
        const result = execFileSync("uv", ["run", script, "--completion"], {
          timeout: 10_000,
          encoding: "utf-8",
        }).trim();
        if (result) return result;
      } catch {
        // fall through
      }
    }
  }

  // Try Anthropic script
  if (process.env.ANTHROPIC_API_KEY) {
    const script = join(LLM_DIR, "anth.py");
    if (existsSync(script)) {
      try {
        const result = execFileSync("uv", ["run", script, "--completion"], {
          timeout: 10_000,
          encoding: "utf-8",
        }).trim();
        if (result) return result;
      } catch {
        // fall through
      }
    }
  }

  return fallbacks[Math.floor(Math.random() * fallbacks.length)];
}

// ---------------------------------------------------------------------------
// Plugin export
// ---------------------------------------------------------------------------

export const HooksPlugin = async ({ directory }) => {
  return {
    // ----- Stop / session idle: dump full transcript + TTS completion -----
    "session.idle": async ({ session }) => {
      try {
        const sessionId = session?.id ?? "unknown";
        const messages = readSessionMessages(sessionId);
        if (messages.length > 0) {
          const targetDir = chatsDirFor(directory);
          const out = join(targetDir, `opencode_${timestamp()}_${sessionId}.json`);
          writeFileSync(out, JSON.stringify(messages, null, 2));
        }

        speak(getCompletionMessage());
      } catch {
        // fail silently
      }
    },

    // ----- Pre-compact: snapshot transcript before it's compacted -----
    "experimental.session.compacting": async ({ session }) => {
      try {
        const sessionId = session?.id ?? "unknown";
        const messages = readSessionMessages(sessionId);
        if (messages.length === 0) return;

        const targetDir = chatsDirFor(directory);
        const out = join(targetDir, `opencode_${timestamp()}_${sessionId}_pre-compact.json`);
        writeFileSync(out, JSON.stringify(messages, null, 2));
      } catch {
        // fail silently
      }
    },

    // ----- Notification: TTS when agent asks a question -----
    "message.updated": async ({ message }) => {
      try {
        if (message?.role !== "assistant") return;

        const text = typeof message.content === "string"
          ? message.content
          : JSON.stringify(message.content ?? "");

        if (text.trim().slice(-1) !== "?") return;

        const engineerName = (process.env.ENGINEER_NAME ?? "").trim();
        let notification;
        if (engineerName && Math.random() < 0.3) {
          notification = `${engineerName}, your agent needs your input`;
        } else {
          notification = "Your agent needs your input";
        }
        speak(notification);
      } catch {
        // fail silently
      }
    },
  };
};
