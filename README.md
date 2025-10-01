start server.py
run maze_setup.sh beforehand

Create a session (via web dashboard at http://localhost:5000):

Team name: "somesh"
Player 1: "Alice"
Player 2: "Bob"



Player 1 Workflow
bash# Terminal 1 (Player 1)
source maze_client.sh
maze_init
# Enter: somesh
# Enter: 1

maze_start              # Starts the timer
cd easy                 # Selects path, shows Q1
cd ls                   # Answers Q1 (correct!)
# Now it shows Q2 is Player 2's turn
Player 2 Workflow
bash# Terminal 2 (Player 2) - can join anytime!
source maze_client.sh
maze_init
# Enter: somesh
# Enter: 2

maze_sync               # SYNCS with current state
# Shows: "Player 2's turn, Question 2: ..."

cd cd                   # Answers Q2
Key Commands
CommandPurposemaze_initSet your team name and player numbermaze_startStart game timer (Player 1 only, once)maze_syncSync with current game state (use liberally!)cd <path>Select path OR submit answermaze_statusSee detailed JSON status
Workflow Summary

Player 1: maze_init → maze_start → cd easy → answers Q1
Player 2: maze_init → maze_sync → answers Q2 when their turn
Both: Keep using maze_sync to see latest state
Both: Only answer when "It's YOUR turn!" appears
