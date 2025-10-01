#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./create_team_space.sh <team_name>"
    exit 1
fi

TEAM_NAME=$1
TEAM_DIR="/tmp/maze_teams/$TEAM_NAME"

mkdir -p "$TEAM_DIR"
cd "$TEAM_DIR"

# Create symbolic links to the maze
ln -s /tmp/linux_maze/easy easy
ln -s /tmp/linux_maze/medium medium
ln -s /tmp/linux_maze/hard hard

echo "✅ Team space created at: $TEAM_DIR"
echo "📁 cd $TEAM_DIR to enter your team space"
