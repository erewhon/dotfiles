# Configuring a Repository for Dev Containers and AI Agents

You are configuring a repository so it works with a container-based development system called `dx`. The system uses `systemd-nspawn` containers with composable overlays to create isolated, project-aware environments. There are two use cases:

1. **Developer shell** — `dx` drops into an interactive shell inside a container with the right toolchain
2. **AI agent** — `dx claude` runs Claude Code inside the container with full project access

Both share the same container but enter it differently. The project directory is bind-mounted at **the same absolute path** inside the container, so tools like Claude Code can resume sessions seamlessly.

---

## How `dx` Works

When you run `dx` in a project directory, it:

1. Finds the project root (via `git rev-parse --show-toplevel` or cwd)
2. Detects the project type from marker files
3. Creates a container named `dev-<project-name>` if one doesn't exist
4. Applies overlays based on detected type (always includes `claude` and `shell-tools`)
5. Binds the project at its real absolute path inside the container
6. Opens a shell or runs the specified command

### Project Type Detection

`dx` looks for these files at the project root:

| File | Detected Type | Overlays Applied |
|------|--------------|-----------------|
| `pyproject.toml`, `setup.py`, `requirements.txt`, `Pipfile` | Python | `python` (Python 3.12+, uv) |
| `package.json` | Node | `node` (Node LTS, pnpm, yarn) |
| `Cargo.toml` | Rust | `rust` (rustup, cargo, clippy) |
| `go.mod` | Go | `go` (Go 1.22, gopls) |
| `src-tauri/Cargo.toml` | Tauri | `rust`, `node`, `tauri` |
| `.devcontainer/devcontainer.json` | DevContainer | Parsed for features, env, lifecycle |

Multiple types can be detected simultaneously (e.g. a Tauri project gets rust + node + tauri).

---

## Minimal Setup (Zero Config)

If the project has standard marker files (`pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`), no additional configuration is needed. `dx` will detect the type and apply the right overlays automatically.

```
my-project/
├── pyproject.toml    # dx detects Python, applies python overlay
├── src/
└── tests/
```

That's it. Run `dx` and you get a Python container with uv, Claude Code, and shell tools.

---

## Advanced Setup with devcontainer.json

For more control, add a `.devcontainer/devcontainer.json`. The system reads it and extracts:

- **Features** → mapped to overlays
- **Environment variables** → injected via `/etc/profile.d/`
- **Lifecycle commands** → run at creation/start time

### Example devcontainer.json

```json
{
  "name": "my-project",
  "features": {
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.12"
    },
    "ghcr.io/devcontainers/features/node:1": {
      "version": "lts"
    },
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "containerEnv": {
    "DATABASE_URL": "postgres://localhost:5432/dev",
    "ENVIRONMENT": "development"
  },
  "postCreateCommand": "uv sync",
  "postStartCommand": "uv run migrate"
}
```

### Feature-to-Overlay Mapping

| DevContainer Feature | Overlay |
|---------------------|---------|
| `devcontainers/python` | `python` |
| `devcontainers/javascript-node`, `devcontainers/node` | `node` |
| `devcontainers/rust` | `rust` |
| `devcontainers/go` | `go` |
| `devcontainers/common-utils` | (built into base) |
| `devcontainers/github-cli` | (gh installed via shell-tools) |

Features not in this table are warned about but won't block container creation.

### Lifecycle Commands

| Hook | When It Runs |
|------|-------------|
| `onCreateCommand` | Once, during container creation |
| `postCreateCommand` | Once, after first start |
| `postStartCommand` | Every boot (saved as startup script) |

Use `postCreateCommand` for dependency installation (`uv sync`, `pnpm install`, `cargo build`). Use `postStartCommand` for services or migrations that need to run each time.

---

## Separating Dev and AI Agent Environments

The dev container is shared between human and AI use. Separation happens at the entry point:

- `dx` — opens an interactive shell for the developer
- `dx claude` — runs Claude Code inside the same container
- `dx <command>` — runs any command (e.g. `dx pytest`, `dx pnpm test`)

If you need **different containers** for dev vs. AI (e.g. the AI should have restricted network access), create a second spec:

```bash
# Human dev (full network)
dx

# AI agent (restricted network, package registries only)
dx --restrict-network claude
```

The `--restrict-network` flag applies iptables rules that whitelist only:
- DNS (port 53)
- Package registries (npm, PyPI, crates.io, etc.)
- GitHub API and CDN
- Established connections

Everything else is blocked.

---

## Repository Configuration Checklist

When setting up a new repo for `dx`:

1. **Ensure standard marker files exist** at project root
   - Python: `pyproject.toml` (preferred over requirements.txt)
   - Node: `package.json`
   - Rust: `Cargo.toml`
   - Go: `go.mod`

2. **Add devcontainer.json** (optional, for env vars or lifecycle hooks)
   - Place at `.devcontainer/devcontainer.json`
   - Use `containerEnv` for environment variables
   - Use `postCreateCommand` for dependency installation
   - Map features to supported overlays

3. **Add a CLAUDE.md** (optional, for AI agent instructions)
   - Project-specific instructions for Claude Code
   - Build/test/lint commands
   - Architecture notes

4. **Verify with `dx --info`** to see what would be detected and created

---

## Available Overlays

These can be applied automatically via detection or manually via `dev.sh create`:

| Overlay | What It Installs |
|---------|-----------------|
| `base` | gcc, git, curl, Wayland libs, build essentials (always applied) |
| `python` | Python 3.12+, uv, native build deps |
| `node` | Node.js LTS, npm, pnpm, yarn, corepack |
| `rust` | rustup, cargo, rustfmt, clippy, rust-analyzer |
| `go` | Go 1.22, gopls, delve |
| `tauri` | WebKit2GTK, Tauri CLI (requires rust + node) |
| `claude` | Claude Code CLI, ripgrep, fd-find (always applied) |
| `shell-tools` | bat, eza, fd, fzf, zoxide, starship, delta, jq, yq, gh (always applied) |
| `ai-tools` | OpenCode, Crush (alternative AI assistants) |
| `devcontainer` | VS Code devcontainer.json lifecycle support |

---

## Commands Reference

```bash
dx                    # Shell into dev container for current project
dx claude             # Run Claude Code in container
dx <command>          # Run a command in the container
dx --info             # Show detected project type and overlays
dx --upgrade          # Upgrade Claude Code in existing container
dx --restart          # Restart container before entering
dx -u                 # Short for --upgrade
```

---

## Example: Full Python Project Setup

```
my-api/
├── .devcontainer/
│   └── devcontainer.json
├── CLAUDE.md
├── pyproject.toml
├── src/
│   └── my_api/
└── tests/
```

`.devcontainer/devcontainer.json`:
```json
{
  "name": "my-api",
  "containerEnv": {
    "DATABASE_URL": "sqlite:///dev.db"
  },
  "postCreateCommand": "uv sync --dev"
}
```

`CLAUDE.md`:
```markdown
## Development
- Run tests: `uv run pytest`
- Lint: `uv run ruff check .`
- Format: `uv run ruff format .`
```

Then:
```bash
dx              # Developer shell with Python, uv, all tools
dx claude       # AI agent with full project context
dx pytest       # Run tests directly
```
