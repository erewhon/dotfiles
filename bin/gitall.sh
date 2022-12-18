#!/usr/bin/env bash
#
# Pull all Git repos.  Adapted from
#
#   https://stackoverflow.com/questions/19576742/how-to-clone-all-repos-at-once-from-github
#
# Disclaimer: This works on my machine.  YMMV
#

ORGS=${ORGS:-"erewhon"}
BASEDIR=${BASEDIR:-"$HOME/Projects"}
REPO_FILTER="--no-archived" # Add --source to exclude forks

cd $BASEDIR

for org in $ORGS
do
    TARGET="$BASEDIR/$org"
    mkdir -p $TARGET || true

    echo "ORG=$org PWD=$(pwd)"
    gh repo list $org $REPO_FILTER --limit 1000 | while read -r repo _; do
        #if [ -d "$repo/.git" ]; then
        #    echo "$repo already exists"
        #else
        #    echo "$repo not there"
        #fi

        echo "CLONE $repo"
        gh repo clone "$repo" "$repo" -- -q 2>/dev/null || (
            cd "$repo"
            echo "SYNC $repo PWD=$(pwd)"
            gh repo sync
            #        # Handle case where local checkout is on a non-main/master branch
            #        # - ignore checkout errors because some repos may have zero commits,
            #        # so no main or master
            #        git checkout -q main 2>/dev/null || true
            #        git checkout -q master 2>/dev/null || true
            #        git pull -q
        )
    done
done
