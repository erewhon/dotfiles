Dotfiles managed using chezmoi.

Full documentation: https://www.chezmoi.io/docs/

## Useful commands

Getting started (pick one):

    chezmoi init --apply erewhon                                    # Download and apply
    sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply erewhon    # Install chezmoi, init and apply
    sh -c "$(curl -fsLS git.io/chezmoi)" -- init --one-shot erewhon # Set up transient host
    
Pull latest changes and apply:

    chezmoi update
    
Refresh and apply externals (for example Oh My Zsh):

    chezmoi --refresh-externals apply

Notes on XDG-compliance: https://wiki.archlinux.org/title/XDG_Base_Directory

