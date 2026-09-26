# Dotfiles managed using chezmoi

Full documentation: "<https://www.chezmoi.io/docs/>"

## Useful commands

Getting started (pick one):

    sh -c "$(curl -fsLS git.io/chezmoi)"                            # Install chezmoi only
    chezmoi init --apply erewhon                                    # Download and apply
    sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply erewhon    # Install chezmoi, init and apply
    sh -c "$(curl -fsLS git.io/chezmoi)" -- init --one-shot erewhon # Set up transient host

Fresh Linux box (installs prerequisites, Linuxbrew, chezmoi, applies):

    bash <(curl -fsSL https://raw.githubusercontent.com/erewhon/dotfiles/main/bin/executable_bootstrap) --home

## Home vs work hosts

Templates classify each machine (`is_personal`, `has_brew`, `has_apt`, ...) via
`.chezmoitemplates/host-profile`, which merges three layers:

1. `[host_defaults]` in `.chezmoidata.toml` (remote, non-personal, no apt)
2. `[hosts.<hostname>]` in `.chezmoidata.toml` — the catalog of known machines
3. `[data.host_overrides]` in `~/.config/chezmoi/chezmoi.toml` — per-machine answers

Layer 3 is written by `chezmoi init` from `.chezmoi.toml.tmpl` and persists across
`chezmoi update`, so a fresh VM that isn't in the catalog can still be a home node:

    bootstrap --home                                  # fresh machine
    chezmoi init --promptBool home=true erewhon/dotfiles   # same, by hand
    chezmoi init --prompt --promptBool home=false     # flip an existing answer
    chezmoi init --prompt                             # re-ask interactively
    chezmoi data | jq .host_overrides                 # see what's stored

`has_apt` / `has_dnf` are detected at init time rather than asked. When
`.chezmoi.toml.tmpl` changes, chezmoi warns until you re-run `chezmoi init`
(no repo argument needed; existing answers are kept).

Pull latest changes and apply:

    chezmoi update

Refresh and apply externals (for example Oh My Zsh):

    chezmoi --refresh-externals apply

Notes on XDG-compliance: "<https://wiki.archlinux.org/title/XDG_Base_Directory>"

Prerequisites (to be installed eventually automatically):

    fortune zsh

Some more notes will be put in here eventually...
