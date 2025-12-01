## Claude Code Configuration

This directory contains Claude Code skills, agents, hooks, and commands for development and content creation workflows.

### Structure

```
dot_claude/
├── agents/           # Sub-agent configurations
│   ├── content-researcher.md    # Topic research for content creation
│   ├── meta-agent.md            # Creates new agent configurations
│   ├── script-writer.md         # Video scripts and blog posts
│   ├── thumbnail-ideas.md       # YouTube thumbnail concepts
│   └── work-completion-summary.md  # TTS work summaries
├── commands/         # Slash commands
│   ├── blog-draft.md            # /blog-draft - Draft a blog post
│   ├── research-topic.md        # /research-topic - Research a topic
│   ├── stream-prep.md           # /stream-prep - Prepare for streaming
│   └── video-outline.md         # /video-outline - Create video outline
├── hooks/            # Event hooks (Stop, Notification, PreCompact)
├── skills/           # Skill definitions
│   ├── content-creation/        # YouTube, blog, streaming workflows
│   ├── research/                # Multi-source research
│   └── story-explanation/       # Narrative framing
├── CLAUDE.md         # Global instructions and preferences
└── settings.json     # Claude Code settings and hooks config
```

### Credits

- Hooks and base agents adapted from https://github.com/disler/claude-code-hooks-mastery
- Skills and content creation workflow inspired by https://github.com/danielmiessler/Personal_AI_Infrastructure
