# Linux Maze Game

A multiplayer Linux command knowledge game for 2-player teams. Navigate a maze by answering Linux command questions with different difficulty paths offering varying risk-reward tradeoffs.

## Quick Start

### Prerequisites
```bash
# Check dependencies
python3 --version  # Need 3.6+
pip3 --version
curl --version
bash --version     # Need 4.0+

# Install Flask
pip3 install flask
```

### Installation

1. **Download the files:**
   - `maze_client.sh` - Client script
   - `maze_setup.sh` - Directory structure creator
   - `server.py` - Flask server

2. **Configure server URL:**
   
   Edit both scripts and change `SERVER_URL` or `MAZE_ROOT`:
   
   ```bash
   # In maze_client.sh (line 6)
   SERVER_URL="http://localhost:5000"
   
   # In maze_setup.sh (lines 7-8)
   MAZE_ROOT="$HOME/linux_maze"
   SERVER_URL="http://localhost:5000"
   ```

3. **Create the maze:**
   ```bash
   chmod +x maze_setup.sh maze_client.sh
   bash maze_setup.sh
   ```

4. **Start the server:**
   ```bash
   python3 server.py
   ```
   
   Open browser: `http://localhost:5000` to see dashboard

### Playing the Game

**Terminal 1 - Player 1:**
```bash
source maze_client.sh
maze_init          # Enter: TeamAlpha, 1
maze_create        # Enter: Alice, Bob
maze_start         # Starts the game
cd easy            # Choose difficulty
cd ls              # Answer question 1
```

**Terminal 2 - Player 2:**
```bash
source maze_client.sh
maze_init          # Enter: TeamAlpha, 2
maze_sync          # See current state
# Wait for your turn...
cd <answer>        # Answer when it's your turn
```

## Game Rules

### Paths

| Path | Questions | Penalty | Behavior |
|------|-----------|---------|----------|
| **Easy** | 10 | 15s | Retry same question |
| **Medium** | 6 | 10s | Reset to Question 1 |
| **Hard** | 4 | 20s | Ejection + path locked |

### How to Play

1. Players alternate answering questions
2. Use `ls` to see available options (won't work as expected - just shows paths)
3. Use `cd <answer>` to submit your answer
4. Wrong answers incur time penalties
5. First team to complete wins (lowest time)

## Commands

```bash
maze_init       # Initialize team and player number
maze_create     # Create session (Player 1 only)
maze_start      # Start game timer (Player 1 only)
maze_sync       # Sync with current game state
maze_status     # View detailed game status (JSON)
maze_help       # Show all commands
cd <path>       # Select difficulty or submit answer
```

## API Endpoints

```
POST   /api/session/create                  # Create new team
POST   /api/session/<team>/start            # Start game timer
POST   /api/session/<team>/select_path      # Choose difficulty
POST   /api/session/<team>/answer           # Submit answer
GET    /api/session/<team>/current_question # Get current Q (for sync)
GET    /api/session/<team>/status           # Get full status
GET    /api/sessions                        # List all sessions
POST   /api/sessions/clear                  # Delete all sessions
DELETE /api/session/<team>/delete           # Delete one session
GET    /api/leaderboard                     # Rankings
```

## Project Structure

```
the-maze-bob/
├── maze_client.sh    # Bash client (source this)
├── maze_setup.sh     # Creates directory structure
├── server.py         # Flask API server
└── README.md         # This file

# After running maze_setup.sh:
~/linux_maze/
├── easy/
│   ├── q1/ q2/ ... q10/
│   └── README.txt
├── medium/
│   ├── q1/ q2/ ... q6/
│   └── README.txt
├── hard/
│   ├── q1/ q2/ ... q4/
│   └── README.txt
├── monitor.sh
└── README.txt
```

## Troubleshooting

**"Session not found"**
- Player 1 must run `maze_create` and `maze_start` first

**"Not your turn"**
- Run `maze_sync` to see whose turn it is
- Server enforces turn order

**"Connection refused"**
- Check server is running: `python3 server.py`
- Verify URL in scripts matches server location
- Check firewall isn't blocking port 5000

**Empty errors**
- Server might not be reachable
- Try: `curl http://localhost:5000/api/sessions`

**To reset everything:**
- Restart the server (Ctrl+C then restart)
- Or: `curl -X POST http://localhost:5000/api/sessions/clear`

## For 15 Teams (30 PCs)

The current implementation works for 2-4 teams but needs improvements for 15+ teams:

**Critical fixes needed:**
1. Replace Flask dev server with production WSGI server (Gunicorn/Waitress)
2. Add database persistence (SQLite/PostgreSQL)
3. Implement request rate limiting
4. Add proper error handling and timeouts
5. Load test with 30+ concurrent connections

See the improvement suggestions document for details.

## Network Setup

For LAN events:

1. Find server IP: `ip addr show | grep "inet "`
2. Update `SERVER_URL` in both scripts to server IP
3. Ensure all PCs can reach server: `ping <server-ip>`
4. Open port 5000 in firewall if needed

## License

Educational project - free to use and modify.

## Credits

Linux Maze Game - Teaching Linux commands through competitive gameplay.