## Development Workflow

- Use "uv" for Python code and "pnpm" for Javascript
- Use typing for Python
- Use Pydantic for Python
- Use Zod for Typescript
- Use ruff for linting and code formatting
- Use pytest for testing
- Use prettier for code formatting with Typescript
- Do not restore, revert, or remove files without asking first

## Licensing

- Default to AGPL-3.0 for my web-based projects. Reason: AGPL's network-use clause stops third parties from running a hosted version without contributing modifications back, which GPL and permissive licenses don't prevent. If a project needs a different license (e.g. a library meant for wide adoption), ask before deviating.

## Tailscale

- I use **Tailscale Services** (capital-S), the tailnet-level service registry feature — NOT plain `tailscale serve` (single-node HTTP proxy). The confusing part: both are configured through the `tailscale serve` CLI, but Tailscale Services requires the `--service=svc:NAME` flag. When inspecting or modifying my setup, always work with `tailscale serve ... --service=svc:NAME` commands (or `get-config` / `set-config` for the JSON form), never plain `tailscale serve` commands that target a single node. Docs: https://tailscale.com/docs/features/tailscale-services
- Renaming a Tailscale Service has no single "rename" op: drain the old, clear it, create the new one, then redefine/approve via the admin console in the browser. Always flag the admin-console step to the user before running the CLI sequence.
- **Tailscale Services have no hairpin routing** — you cannot reach a service from the same host that advertises it. `curl https://foo.peacock-bramble.ts.net/` from the host running svc:foo will time out even when the service is perfectly healthy. To verify a service is up, either test from a different tailnet device, or test the backend directly on `127.0.0.1:<port>`.

## Content Creation

I create YouTube videos, live streams, and blog posts about coding and technology.

### Voice & Style
- Conversational and direct - like explaining to a curious friend
- Practical and actionable - focus on what people can use
- Authentic - share genuine opinions and experiences
- Curious - show enthusiasm for learning and exploring

### Avoid
- Clickbait that doesn't deliver
- Jargon without explanation
- Filler phrases ("basically", "you know", "like I said")
- Corporate buzzwords ("leverage", "synergy", "paradigm shift")
- Over-promising or sensationalizing

### Content Workflow
1. Research topic thoroughly before scripting
2. Create hook/intro that establishes value upfront
3. Structure with clear sections and timestamps
4. Include practical examples and demonstrations
5. End with clear next steps or call-to-action

### Available Skills
- `content-creation` - Workflows for YouTube, blog posts, and live streams
- `research` - Multi-source investigation and fact-checking
- `story-explanation` - Narrative framing of technical concepts

### Available Agents
- `content-researcher` - Deep topic and competitor research
- `script-writer` - Full scripts for videos and blog posts
- `thumbnail-ideas` - Visual concepts for YouTube thumbnails

### Slash Commands
- `/video-outline` - Quick video structure and script outline
- `/blog-draft` - Draft a blog post on a topic
- `/stream-prep` - Prepare for a live stream session
- `/research-topic` - Research a topic for content creation
