#!/bin/bash
# Installing Emacs is such a pain on Mac, I put all the steps
# here so I don't forget.

brew uninstall emacs-mac@29
brew uninstall --ignore-dependencies gcc libgccjit
brew install gcc libgccjit

# brew install --cc=gcc-15 emacs-plus@30

brew install emacs-plus@30
osascript -e 'tell application "Finder" to make alias file to posix file "/opt/homebrew/opt/emacs-plus@30/Emacs.app" at posix file "/Applications" with properties {name:"Emacs.app "}'
