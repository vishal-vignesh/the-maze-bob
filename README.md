# Linux Maze Game - Complete Workflow Guide

## Overview

A competitive two-player Linux trivia game where players navigate through a maze by answering Linux command questions. Players alternate turns and must synchronize their terminals to work as a team.

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Player 1   │         │   Flask     │         │  Player 2   │
│  Terminal   │◄───────►│   Server    │◄───────►│  Terminal   │
│             │  HTTP   │             │  HTTP   │             │
└─────────────┘         └─────────────┘         └─────────────┘
      │                       │                       │
      └───────── Shared Team Session ─────────────────┘
```

## Setup Instructions

### 1. Server Setup (Admin/Host)

```bash
# Install Flask
pip install flask

# Start the server
python server.py

# Output:
# 🎮 Linux Maze Game Server Starting...
# ==================================================
# Admin Dashboard: http://localhost:5000
# API Endpoint: http://localhost:5000/api
# ==================================================
```

**Admin Dashboard Access:** Open `http://localhost:5000` in a browser to:
- Create team sessions
- Monitor live progress
- View penalties and timing
- Check leaderboard

### 2. Create Team Session

**Option A: Via Web Dashboard**
1. Open `http://localhost:5000`
2. Enter team name (e.g., "somesh")
3. Enter Player 1 name (e.g., "Alice")
4. Enter Player 2 name (e.g., "Bob")
5. Click "Create Session"

**Option B: Via API**
```bash
curl -X POST http://localhost:5000/api/session/create \
  -H "Content-Type: application/json" \
  -d '{"team_name":"somesh","player1":"Alice","player2":"Bob"}'
```

### 3. Player Setup

Both players need the client script on their machines.

**Update Server URL in `maze_client.sh`:**
```bash
SERVER_URL="http://192.168.29.210:5000"  # Change to your server IP
```

**Source the client:**
```bash
source maze_client.sh
```

## Game Workflow

### Phase 1: Initialization

**Player 1 Terminal:**
```bash
$ source maze_client.sh
╔════════════════════════════════════════════════════════╗
║        🎮 Linux Maze Game - Client Loaded! 🎮          ║
╚════════════════════════════════════════════════════════╝

$ maze_init
🎮 Welcome to the Linux Maze Game!
Enter your team name:
somesh
Enter your player number (1 or 2):
1
✅ Initialized as somesh - Player 1
Use 'maze_start' to begin the game
Use 'maze_sync' to sync with your partner
```

**Player 2 Terminal:**
```bash
$ source maze_client.sh
$ maze_init
Enter your team name:
somesh
Enter your player number (1 or 2):
2
✅ Initialized as somesh - Player 2
```

### Phase 2: Game Start (Player 1 Only)

**Player 1:**
```bash
$ maze_start
🚀 Game started!
Choose your path:
  🍃 easy - 10 questions, 15s penalty per wrong answer (retry same question)
  ⚖️  medium - 6 questions, 10s penalty + reset to start on wrong answer
  🔥 hard - 4 questions, 20s penalty + full ejection on wrong answer

Use: cd easy, cd medium, or cd hard
```

### Phase 3: Path Selection (Player 1 Only)

**Player 1:**
```bash
$ cd easy
✅ Path selected: easy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1's turn
Question:
Which command lists files and directories in the current location?
Options: cat, cd, ls, pwd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ It's YOUR turn! Use: cd <answer>
```

**Player 2 (syncs to see the same state):**
```bash
$ maze_sync
✅ Synced with game state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1's turn
Path: easy | Question 1
Which command lists files and directories in the current location?
Options: cat, cd, ls, pwd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Waiting for Player 1 to answer...
Run 'maze_sync' to check if they answered
```

### Phase 4: Alternating Answers

**Player 1 (answers Q1):**
```bash
$ cd ls
✅ Correct!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 2's turn
Next Question:
Which command changes the current working directory?
Options: cd, cp, ls, mv
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Waiting for Player 2...
```

**Player 2 (syncs to see Q2):**
```bash
$ maze_sync
✅ Synced with game state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 2's turn
Path: easy | Question 2
Which command changes the current working directory?
Options: cd, cp, ls, mv
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ It's YOUR turn! Use: cd <answer>

$ cd cd
✅ Correct!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1's turn
Next Question:
Which command searches for patterns in text files?
Options: awk, find, grep, sed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Waiting for Player 1...
```

**Player 1 (syncs to see Q3):**
```bash
$ maze_sync
✅ Synced with game state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1's turn
Path: easy | Question 3
Which command searches for patterns in text files?
Options: awk, find, grep, sed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ It's YOUR turn! Use: cd <answer>

$ cd grep
✅ Correct!
```

### Phase 5: Wrong Answer Scenarios

#### Easy Path (Retry Same Question)
```bash
$ cd chmod
❌ Wrong Answer!
⏱️  Penalty: +15s
Wrong answer! 15s penalty. Try again.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1 - Try again:
Which command changes file permissions using symbolic notation?
Options: chgrp, chmod, chown, umask
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Medium Path (Reset to Start)
```bash
$ cd wrong_answer
❌ Wrong Answer!
⏱️  Penalty: +10s
Wrong answer! 10s penalty. Resetting to question 1.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1 - Starting over:
[Shows Question 1 again]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Hard Path (Ejection)
```bash
$ cd wrong_answer
❌ Wrong Answer!
⏱️  Penalty: +20s
Wrong answer! 20s penalty. Ejected from Hard path. Choose Easy or Medium.
🚫 Hard path now LOCKED. Choose easy or medium.
```

### Phase 6: Completion

```bash
$ cd tar  # Final question answer
✅ Correct!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 CONGRATULATIONS! MAZE COMPLETED! 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Time: 247.3s
Penalties: 15s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Command Reference

| Command | Who Uses It | When | Purpose |
|---------|-------------|------|---------|
| `maze_init` | Both players | Start | Set team name and player number |
| `maze_start` | Player 1 only | After init | Start game timer |
| `maze_sync` | Both players | Anytime | Sync with current game state |
| `cd <path>` | Player 1 only | After start | Select easy/medium/hard |
| `cd <answer>` | Current player | When it's your turn | Submit answer |
| `maze_status` | Both players | Anytime | View detailed JSON status |
| `maze_help` | Both players | Anytime | Show command list |

## Path Comparison

| Path | Questions | Penalty | On Wrong Answer |
|------|-----------|---------|-----------------|
| Easy | 10 | 15s | Retry same question |
| Medium | 6 | 10s | Reset to Question 1 |
| Hard | 4 | 20s | Eject + lock hard path forever |

## Critical Synchronization Rules

1. **Player 1 controls game start and path selection**
   - Only Player 1 runs `maze_start` and `cd easy/medium/hard`
   - Player 2 joins by using `maze_sync`

2. **Both players must sync before answering**
   - Use `maze_sync` to see current question
   - Check "It's YOUR turn!" message before answering

3. **Only the current player can answer**
   - Attempting to answer on wrong turn shows error
   - Must wait for partner to answer first

4. **Server is the source of truth**
   - Both players fetch state from server
   - No local state management
   - Always sync when uncertain

## Common Scenarios

### Scenario 1: Player 2 Joins Late

**Player 1** is already on Question 5.

**Player 2:**
```bash
$ source maze_client.sh
$ maze_init  # team: somesh, player: 2
$ maze_sync  # Shows Question 5 and whose turn it is
```

### Scenario 2: Wrong Player Tries to Answer

```bash
$ cd answer
❌ Not your turn! Player 1 should answer.
Use 'maze_sync' to refresh the view
```

### Scenario 3: Check Partner's Progress

```bash
$ maze_sync
✅ Synced with game state
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 Player 1's turn
Path: easy | Question 7
[Question details...]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Waiting for Player 1 to answer...
```

### Scenario 4: Lost Connection/Refresh

Both players can safely re-run:
```bash
$ maze_sync
```
This fetches the current state without disrupting the game.

## Troubleshooting

### "Session not found"
- Ensure session was created via web dashboard or API
- Check team name spelling (case-sensitive)
- Verify server is running

### "Not your turn"
- Run `maze_sync` to see whose turn it is
- Wait for partner to answer first
- Check you initialized with correct player number

### "Path already selected"
- Only Player 1 selects path once
- Player 2 uses `maze_sync` to join
- Don't run `cd easy/medium/hard` twice

### Questions out of sync
- Both players run `maze_sync`
- Server state is authoritative
- Restart terminals if needed (state is on server)

### Wrong player number
- Exit terminal
- Re-source script: `source maze_client.sh`
- Run `maze_init` with correct player number

## API Testing

### Check session status
```bash
curl http://localhost:5000/api/session/somesh/status | python3 -m json.tool
```

### View all sessions
```bash
curl http://localhost:5000/api/sessions | python3 -m json.tool
```

### Check leaderboard
```bash
curl http://localhost:5000/api/leaderboard | python3 -m json.tool
```

## Scoring

**Final Score = Base Time + Penalties**

Example:
- Started: 10:00:00
- Finished: 10:04:07 (247 seconds)
- Wrong answers: 1 (15s penalty)
- **Total: 262 seconds**

Lower score = better!

## Tips for Success

1. **Communication is key** - Use voice/chat to coordinate
2. **Sync frequently** - Run `maze_sync` liberally
3. **Choose path wisely** - Easy is safer but longer
4. **Know your Linux** - Study commands before playing
5. **Don't rush** - Wrong answers add time penalties
6. **Plan who answers what** - Divide questions by expertise

## File Structure

```
project/
├── server.py              # Flask server with all endpoints
├── maze_client.sh         # Fixed client with sync support
├── maze_setup.sh          # Directory structure creator (optional)
└── README.md              # This file
```

## Quick Start Example

```bash
# Terminal 1 (Server)
python server.py

# Browser
# Open http://localhost:5000
# Create session: team=alpha, player1=Alice, player2=Bob

# Terminal 2 (Player 1)
source maze_client.sh
maze_init     # team=alpha, player=1
maze_start
cd easy
cd ls         # Answer Q1

# Terminal 3 (Player 2)
source maze_client.sh
maze_init     # team=alpha, player=2
maze_sync     # See Q2
cd cd         # Answer Q2

# Continue alternating...
```

## Support

For issues or questions:
1. Check server logs in Terminal 1
2. Verify network connectivity between players and server
3. Ensure Python 3 and Flask are installed
4. Check firewall allows port 5000
5. Review this README's troubleshooting section
