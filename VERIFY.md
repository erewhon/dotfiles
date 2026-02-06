# Verification Steps

After syncing these changes to your chezmoi source dir (`~/.local/share/chezmoi`), run through these steps.

## 1. Verify host data loads

```sh
chezmoi data | jq '.hosts'
chezmoi data | jq '.host_defaults'
```

## 2. Confirm your host is recognized

```sh
chezmoi execute-template '{{ .chezmoi.hostname }}'
# should print "delphi"
```

## 3. Check what chezmoi would do (dry run)

```sh
chezmoi diff
chezmoi apply --dry-run --verbose
```

Look for: Brewfile rendered with proper `brew "pkg"` syntax, the 6 `run_onchange_` scripts listed, old `run_once_` gone.

## 4. Check ignore rules are working

```sh
chezmoi managed | grep -i iterm
# should be empty on Linux (iterm skipped)

chezmoi managed | grep Brewfile
# should show .config/Brewfile (since delphi has_brew=true)
```

## 5. Apply

```sh
chezmoi apply
```

Watch the script output — you should see `[00-ensure-dirs]`, `[10-apt-packages]`, `[30-uv-tools]`, etc. The apt script will need sudo.

## 6. Test the login shell update check

```sh
rm -f ~/.cache/.last_chezmoi_check
zsh --login
# should run silently (no upstream changes = no output)
```

## 7. Test brew-drift (if brew is available)

```sh
~/bin/brew-drift
~/bin/brew-drift --dump
```

## 8. Trigger a re-run by editing a package list

Add a package to `dot_config/packages/uv-tools.txt` in the source, then `chezmoi apply` — only the uv-tools script should re-run (the hash changed). The others should be skipped (hashes unchanged).
