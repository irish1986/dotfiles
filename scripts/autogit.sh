#!/bin/bash

# Make an array of repository directories,which you want to auto-commit
repo_dirs="/home/irish/git/irish1986/autogit"

touch_file() {
    cd "$repo_dir" || return
    echo "Time: $(date)" >> data
    sleep 5s
}

git_action() {
    git add .
    git commit -m "Automated commit on $(date)"
}

touch_file
git_action
git push origin main
