#!/usr/bin/env bun
/**
 * DevVoice - Development Voice notification server using ElevenLabs TTS
 * Adapted from PAIVoice by Daniel Miessler
 *
 * Provides voice notifications for development workflows including:
 * - Requirement review results
 * - Code review feedback
 * - Build status notifications
 * - Test result summaries
 * - Task completion announcements
 */

import { serve } from "bun";
import { spawn } from "child_process";
import { homedir } from "os";
import { join } from "path";
import { existsSync } from "fs";

// Load .env from user home directory
const envPath = join(homedir(), '.env');
if (existsSync(envPath)) {
  const envContent = await Bun.file(envPath).text();
  envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value && !key.startsWith('#')) {
      process.env[key.trim()] = value.trim();
    }
  });
}

const PORT = parseInt(process.env.DEVVOICE_PORT || process.env.PORT || "28888");
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;

if (!ELEVENLABS_API_KEY) {
  console.error('⚠️  ELEVENLABS_API_KEY not found in ~/.env');
  console.error('Add: ELEVENLABS_API_KEY=your_key_here');
  console.error('Voice will be disabled until configured.');
}

// Default voice ID - can be overridden per request or via env
const DEFAULT_VOICE_ID = process.env.ELEVENLABS_VOICE_ID || "s3TPKV1kjDlVtZbl4Ksh";

// Default model - eleven_multilingual_v2 is the current recommended model
const DEFAULT_MODEL = process.env.ELEVENLABS_MODEL || "eleven_multilingual_v2";

// Sanitize input for shell commands
function sanitizeForShell(input: string): string {
  return input.replace(/[^a-zA-Z0-9\s.,!?\-'":;()]/g, '').trim().substring(0, 1000);
}

// Validate and sanitize user input
function validateInput(input: any, maxLength = 1000): { valid: boolean; error?: string } {
  if (!input || typeof input !== 'string') {
    return { valid: false, error: 'Invalid input type' };
  }

  if (input.length > maxLength) {
    return { valid: false, error: `Message too long (max ${maxLength} characters)` };
  }

  const dangerousPatterns = [
    /[;&|><`\$\{\}\[\]\\]/,
    /\.\.\//,
    /<script/i,
  ];

  for (const pattern of dangerousPatterns) {
    if (pattern.test(input)) {
      return { valid: false, error: 'Invalid characters in input' };
    }
  }

  return { valid: true };
}

// Generate speech using ElevenLabs API
async function generateSpeech(text: string, voiceId: string): Promise<ArrayBuffer> {
  if (!ELEVENLABS_API_KEY) {
    throw new Error('ElevenLabs API key not configured');
  }

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
      'xi-api-key': ELEVENLABS_API_KEY,
    },
    body: JSON.stringify({
      text: text,
      model_id: DEFAULT_MODEL,
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.5,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    if (errorText.includes('model') || response.status === 422) {
      throw new Error(`ElevenLabs API error: Invalid model "${DEFAULT_MODEL}". Update ELEVENLABS_MODEL in ~/.env`);
    }
    throw new Error(`ElevenLabs API error: ${response.status} - ${errorText}`);
  }

  return await response.arrayBuffer();
}

// Play audio - platform adaptive
async function playAudio(audioBuffer: ArrayBuffer): Promise<void> {
  const tempFile = `/tmp/devvoice-${Date.now()}.mp3`;

  // Write audio to temp file
  await Bun.write(tempFile, audioBuffer);

  return new Promise((resolve, reject) => {
    // Detect platform and use appropriate audio player
    const platform = process.platform;
    let command: string;
    let args: string[];

    if (platform === 'darwin') {
      command = '/usr/bin/afplay';
      args = [tempFile];
    } else if (platform === 'linux') {
      // Try common Linux audio players
      command = 'mpv';
      args = ['--no-video', '--really-quiet', tempFile];
    } else {
      // Windows fallback
      command = 'powershell';
      args = ['-c', `(New-Object Media.SoundPlayer "${tempFile}").PlaySync()`];
    }

    const proc = spawn(command, args);

    proc.on('error', (error) => {
      console.error('Error playing audio:', error);
      // Clean up temp file
      spawn('rm', ['-f', tempFile]);
      reject(error);
    });

    proc.on('exit', (code) => {
      // Clean up temp file
      spawn('rm', ['-f', tempFile]);

      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Audio player exited with code ${code}`));
      }
    });
  });
}

// Send desktop notification - platform adaptive
async function sendDesktopNotification(title: string, message: string): Promise<void> {
  const platform = process.platform;

  return new Promise((resolve, reject) => {
    let proc;

    if (platform === 'darwin') {
      const script = `display notification "${message}" with title "${title}" sound name ""`;
      proc = spawn('/usr/bin/osascript', ['-e', script]);
    } else if (platform === 'linux') {
      proc = spawn('notify-send', [title, message]);
    } else {
      // Skip notification on unsupported platforms
      resolve();
      return;
    }

    proc.on('error', (error) => {
      console.error('Notification error:', error);
      resolve(); // Don't fail on notification errors
    });

    proc.on('exit', () => {
      resolve();
    });
  });
}

// Send notification with voice
async function sendNotification(
  title: string,
  message: string,
  voiceEnabled = true,
  voiceId: string | null = null
) {
  // Validate inputs
  const titleValidation = validateInput(title, 200);
  const messageValidation = validateInput(message, 1000);

  if (!titleValidation.valid) {
    throw new Error(`Invalid title: ${titleValidation.error}`);
  }

  if (!messageValidation.valid) {
    throw new Error(`Invalid message: ${messageValidation.error}`);
  }

  // Sanitize inputs
  const safeTitle = sanitizeForShell(title);
  const safeMessage = sanitizeForShell(message);

  // Generate and play voice using ElevenLabs
  if (voiceEnabled && ELEVENLABS_API_KEY) {
    try {
      const voice = voiceId || DEFAULT_VOICE_ID;
      console.log(`🎙️  Generating speech with ElevenLabs (voice: ${voice})`);

      const audioBuffer = await generateSpeech(safeMessage, voice);
      await playAudio(audioBuffer);
    } catch (error) {
      console.error("Failed to generate/play speech:", error);
    }
  }

  // Display desktop notification
  try {
    await sendDesktopNotification(safeTitle, safeMessage);
  } catch (error) {
    console.error("Notification display error:", error);
  }
}

// Development skill: Format requirement review results
function formatRequirementReview(data: any): string {
  const { requirements = [], changes = [], verdict = 'unknown', summary = '' } = data;

  let message = '';

  if (verdict === 'pass' || verdict === 'fulfilled') {
    message = `Requirements fulfilled. ${summary || 'All requirements have been met.'}`;
  } else if (verdict === 'partial') {
    const met = requirements.filter((r: any) => r.met).length;
    const total = requirements.length;
    message = `Partial fulfillment. ${met} of ${total} requirements met. ${summary}`;
  } else if (verdict === 'fail' || verdict === 'unfulfilled') {
    const unmet = requirements.filter((r: any) => !r.met).map((r: any) => r.name || r.description).join(', ');
    message = `Requirements not met. Missing: ${unmet}. ${summary}`;
  } else {
    message = summary || 'Requirement review complete.';
  }

  return message;
}

// Development skill: Format code review results
function formatCodeReview(data: any): string {
  const { issues = [], severity = 'info', summary = '', approval = null } = data;

  if (approval === true || approval === 'approved') {
    return `Code review approved. ${summary || 'No issues found.'}`;
  } else if (approval === false || approval === 'rejected') {
    const criticalCount = issues.filter((i: any) => i.severity === 'critical' || i.severity === 'error').length;
    return `Code review has concerns. ${criticalCount} critical issues found. ${summary}`;
  }

  if (issues.length === 0) {
    return summary || 'Code review complete. No issues found.';
  }

  const issueCount = issues.length;
  const criticalCount = issues.filter((i: any) => i.severity === 'critical' || i.severity === 'error').length;

  if (criticalCount > 0) {
    return `Code review found ${issueCount} issues, ${criticalCount} critical. ${summary}`;
  }

  return `Code review found ${issueCount} issues. ${summary}`;
}

// Development skill: Format build status
function formatBuildStatus(data: any): string {
  const { status, project = '', duration = '', errors = [], warnings = [] } = data;

  const projectName = project ? `${project} ` : '';

  if (status === 'success' || status === 'passed') {
    const durationText = duration ? ` in ${duration}` : '';
    const warningText = warnings.length > 0 ? ` with ${warnings.length} warnings` : '';
    return `${projectName}Build succeeded${durationText}${warningText}.`;
  } else if (status === 'failed' || status === 'failure') {
    const errorCount = errors.length || 'unknown';
    return `${projectName}Build failed with ${errorCount} errors.`;
  } else if (status === 'running' || status === 'in_progress') {
    return `${projectName}Build is running.`;
  }

  return `${projectName}Build status: ${status}.`;
}

// Development skill: Format test results
function formatTestResults(data: any): string {
  const { passed = 0, failed = 0, skipped = 0, total = 0, duration = '', suite = '' } = data;

  const suiteName = suite ? `${suite}: ` : '';
  const durationText = duration ? ` in ${duration}` : '';

  if (failed === 0 && passed > 0) {
    return `${suiteName}All ${passed} tests passed${durationText}.`;
  } else if (failed > 0) {
    return `${suiteName}${failed} of ${total} tests failed. ${passed} passed, ${skipped} skipped${durationText}.`;
  } else if (total === 0) {
    return `${suiteName}No tests found.`;
  }

  return `${suiteName}Tests complete: ${passed} passed, ${failed} failed, ${skipped} skipped${durationText}.`;
}

// Rate limiting
const requestCounts = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT = 30;
const RATE_WINDOW = 60000;

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const record = requestCounts.get(ip);

  if (!record || now > record.resetTime) {
    requestCounts.set(ip, { count: 1, resetTime: now + RATE_WINDOW });
    return true;
  }

  if (record.count >= RATE_LIMIT) {
    return false;
  }

  record.count++;
  return true;
}

// Start HTTP server
const server = serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    const clientIp = req.headers.get('x-forwarded-for') || 'localhost';

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };

    if (req.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders, status: 204 });
    }

    if (!checkRateLimit(clientIp)) {
      return new Response(
        JSON.stringify({ status: "error", message: "Rate limit exceeded" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 429
        }
      );
    }

    // Generic notification endpoint
    if (url.pathname === "/notify" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "DevVoice Notification";
        const message = data.message || "Task completed";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || data.voice_name || null;

        if (voiceId && typeof voiceId !== 'string') {
          throw new Error('Invalid voice_id');
        }

        console.log(`📨 Notification: "${title}" - "${message}" (voice: ${voiceEnabled})`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Notification sent" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Notification error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: error.message?.includes('Invalid') ? 400 : 500
          }
        );
      }
    }

    // Development skill: Requirement Review
    if (url.pathname === "/dev/requirement-review" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "Requirement Review";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || null;

        const message = formatRequirementReview(data);
        console.log(`📋 Requirement Review: "${message}"`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Requirement review notification sent", formatted_message: message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Requirement review error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500
          }
        );
      }
    }

    // Development skill: Code Review
    if (url.pathname === "/dev/code-review" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "Code Review";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || null;

        const message = formatCodeReview(data);
        console.log(`🔍 Code Review: "${message}"`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Code review notification sent", formatted_message: message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Code review error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500
          }
        );
      }
    }

    // Development skill: Build Status
    if (url.pathname === "/dev/build-status" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "Build Status";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || null;

        const message = formatBuildStatus(data);
        console.log(`🔨 Build Status: "${message}"`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Build status notification sent", formatted_message: message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Build status error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500
          }
        );
      }
    }

    // Development skill: Test Results
    if (url.pathname === "/dev/test-results" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "Test Results";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || null;

        const message = formatTestResults(data);
        console.log(`🧪 Test Results: "${message}"`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Test results notification sent", formatted_message: message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Test results error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500
          }
        );
      }
    }

    // Development skill: Task Completion
    if (url.pathname === "/dev/task-complete" && req.method === "POST") {
      try {
        const data = await req.json();
        const task = data.task || data.name || "Task";
        const status = data.status || "completed";
        const details = data.details || "";
        const title = data.title || "Task Update";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || null;

        let message = `${task} ${status}`;
        if (details) {
          message += `. ${details}`;
        }

        console.log(`✅ Task Complete: "${message}"`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Task completion notification sent", formatted_message: message }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Task completion error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500
          }
        );
      }
    }

    // Health check endpoint
    if (url.pathname === "/health" || url.pathname === "/") {
      const endpoints = [
        { path: "/notify", method: "POST", description: "Generic notification" },
        { path: "/dev/requirement-review", method: "POST", description: "Requirement review results" },
        { path: "/dev/code-review", method: "POST", description: "Code review feedback" },
        { path: "/dev/build-status", method: "POST", description: "Build status notifications" },
        { path: "/dev/test-results", method: "POST", description: "Test result summaries" },
        { path: "/dev/task-complete", method: "POST", description: "Task completion announcements" },
        { path: "/health", method: "GET", description: "Server health check" },
      ];

      return new Response(
        JSON.stringify({
          status: "healthy",
          name: "DevVoice Server",
          version: "1.0.0",
          port: PORT,
          voice_system: "ElevenLabs",
          model: DEFAULT_MODEL,
          default_voice_id: DEFAULT_VOICE_ID,
          api_key_configured: !!ELEVENLABS_API_KEY,
          endpoints: endpoints,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200
        }
      );
    }

    return new Response(
      JSON.stringify({
        error: "Not found",
        available_endpoints: ["/notify", "/dev/requirement-review", "/dev/code-review", "/dev/build-status", "/dev/test-results", "/dev/task-complete", "/health"]
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      }
    );
  },
});

console.log(`🚀 DevVoice Server running on port ${PORT}`);
console.log(`🎙️  Using ElevenLabs TTS (model: ${DEFAULT_MODEL}, voice: ${DEFAULT_VOICE_ID})`);
console.log(`📡 Endpoints:`);
console.log(`   POST http://localhost:${PORT}/notify - Generic notification`);
console.log(`   POST http://localhost:${PORT}/dev/requirement-review - Requirement review`);
console.log(`   POST http://localhost:${PORT}/dev/code-review - Code review`);
console.log(`   POST http://localhost:${PORT}/dev/build-status - Build status`);
console.log(`   POST http://localhost:${PORT}/dev/test-results - Test results`);
console.log(`   POST http://localhost:${PORT}/dev/task-complete - Task completion`);
console.log(`   GET  http://localhost:${PORT}/health - Health check`);
console.log(`🔒 Security: Rate limiting enabled (${RATE_LIMIT} req/${RATE_WINDOW/1000}s)`);
console.log(`🔑 API Key: ${ELEVENLABS_API_KEY ? '✅ Configured' : '❌ Missing (voice disabled)'}`);
