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
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const HOOKS_DIR = join(homedir(), ".claude", "hooks");
const TTS_DIR = join(HOOKS_DIR, "utils", "tts");
const LLM_DIR = join(HOOKS_DIR, "utils", "llm");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function ensureDir(dir) {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

function appendJsonLog(logPath, entry) {
  let data = [];
  if (existsSync(logPath)) {
    try {
      data = JSON.parse(readFileSync(logPath, "utf-8"));
    } catch {
      data = [];
    }
  }
  data.push(entry);
  writeFileSync(logPath, JSON.stringify(data, null, 2));
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
  const logDir = join(directory, "logs");

  return {
    // ----- Stop / session idle: log + TTS completion -----
    "session.idle": async ({ session }) => {
      try {
        ensureDir(logDir);
        const entry = {
          event: "session.idle",
          session_id: session?.id ?? "unknown",
          timestamp: new Date().toISOString(),
        };
        appendJsonLog(join(logDir, "stop.json"), entry);

        const message = getCompletionMessage();
        speak(message);
      } catch {
        // fail silently
      }
    },

    // ----- Pre-compact: back up transcript -----
    "experimental.session.compacting": async ({ session }) => {
      try {
        ensureDir(logDir);
        const entry = {
          event: "session.compacting",
          session_id: session?.id ?? "unknown",
          timestamp: new Date().toISOString(),
        };
        appendJsonLog(join(logDir, "pre_compact.json"), entry);

        // Back up session data if available
        const backupDir = join(logDir, "transcript_backups");
        ensureDir(backupDir);

        // OpenCode stores session data differently than Claude Code.
        // We log the compaction event; full transcript backup depends on
        // session export which may not be available in the hook context.
        // The log entry serves as a marker for when compaction occurred.
      } catch {
        // fail silently
      }
    },

    // ----- Notification: TTS when agent asks a question -----
    "message.updated": async ({ message }) => {
      try {
        // Only fire TTS for assistant messages that contain questions
        if (message?.role !== "assistant") return;

        // Check if the message contains a question to the user
        const text = typeof message.content === "string"
          ? message.content
          : JSON.stringify(message.content ?? "");

        // Simple heuristic: if the last sentence ends with "?" it's a question
        const lastChars = text.trim().slice(-1);
        if (lastChars !== "?") return;

        ensureDir(logDir);
        const entry = {
          event: "notification",
          timestamp: new Date().toISOString(),
          preview: text.slice(0, 200),
        };
        appendJsonLog(join(logDir, "notification.json"), entry);

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
