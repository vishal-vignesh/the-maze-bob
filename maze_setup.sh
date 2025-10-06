#!/bin/bash

# maze_setup.sh - Creates the physical maze directory structure
# This script creates the actual directories and trap scripts

# CHANGE THESE TO YOUR CONFIGURATION
MAZE_ROOT="$HOME/linux_maze"
SERVER_URL="http://localhost:5000"

echo "🎮 Setting up Linux Maze Game..."
echo "================================"
echo "Maze location: $MAZE_ROOT"
echo "Server URL: $SERVER_URL"
echo ""

# Clean previous setup
if [ -d "$MAZE_ROOT" ]; then
    echo "Cleaning previous maze setup..."
    rm -rf "$MAZE_ROOT"
fi

mkdir -p "$MAZE_ROOT"
cd "$MAZE_ROOT"

# Function to create a question directory
create_question() {
    local path=$1
    local question_num=$2
    local correct_answer=$3
    shift 3
    local wrong_answers=("$@")
    
    local question_dir="${path}/q${question_num}"
    mkdir -p "$question_dir"
    
    # Create correct answer directory
    mkdir -p "$question_dir/$correct_answer"
    echo "" > "$question_dir/$correct_answer/.maze_check"
    
    # Create wrong answer directories
    for wrong_ans in "${wrong_answers[@]}"; do
        mkdir -p "$question_dir/$wrong_ans"
        echo "" > "$question_dir/$wrong_ans/.maze_trap"
    done
}

# Create path selection directories
mkdir -p easy medium hard

# ============================================
# EASY PATH - 10 Questions
# ============================================
echo "Creating Easy Path..."

create_question "easy" 1 "ls" "cd" "pwd" "cat"
create_question "easy" 2 "cd" "ls" "mv" "cp"
create_question "easy" 3 "grep" "find" "sed" "awk"
create_question "easy" 4 "chmod" "chown" "chgrp" "umask"
create_question "easy" 5 "ps" "top" "kill" "jobs"
create_question "easy" 6 "man" "info" "help" "whatis"
create_question "easy" 7 "echo" "printf" "cat" "tee"
create_question "easy" 8 "cp" "mv" "rm" "ln"
create_question "easy" 9 "head" "tail" "more" "less"
create_question "easy" 10 "tar" "gzip" "zip" "bzip2"

# ============================================
# MEDIUM PATH - 6 Questions
# ============================================
echo "Creating Medium Path..."

create_question "medium" 1 "find" "locate" "which" "whereis"
create_question "medium" 2 "awk" "sed" "grep" "cut"
create_question "medium" 3 "xargs" "parallel" "find" "exec"
create_question "medium" 4 "netstat" "ss" "lsof" "nmap"
create_question "medium" 5 "systemctl" "service" "init" "upstart"
create_question "medium" 6 "rsync" "scp" "sftp" "ftp"

# ============================================
# HARD PATH - 4 Questions
# ============================================
echo "Creating Hard Path..."

create_question "hard" 1 "strace" "ltrace" "gdb" "valgrind"
create_question "hard" 2 "iptables" "nftables" "ufw" "firewalld"
create_question "hard" 3 "perf" "dtrace" "ftrace" "bpftrace"
create_question "hard" 4 "ldd" "objdump" "readelf" "nm"

# ============================================
# Create README files
# ============================================

cat > "$MAZE_ROOT/README.txt" << 'EOF'
╔══════════════════════════════════════════════════════════╗
║           🎮 WELCOME TO THE LINUX MAZE! 🎮              ║
╚══════════════════════════════════════════════════════════╝

RULES:
------
1. Use 'ls' to see available options (directories)
2. Use 'cd <directory>' to select your answer
3. Players must alternate answering questions
4. Choose your path wisely!

PATHS:
------
🍃 easy/    - 10 questions, 15s penalty, retry same question
⚖️  medium/  - 6 questions, 10s penalty, reset to start
🔥 hard/    - 4 questions, 20s penalty, full ejection

SETUP:
------
1. Source the client script: source maze_client.sh
2. Initialize: maze_init
3. Create session: maze_create (Player 1)
4. Start game: maze_start (Player 1)
5. Choose path: cd easy (or medium/hard)
6. Answer questions: cd <answer>

Good luck! 🍀
EOF

cat > "$MAZE_ROOT/easy/README.txt" << 'EOF'
🍃 EASY PATH - The Path of Persistence
====================================

Questions: 10
Penalty: 15 seconds + retry same question
Strategy: Safe but slow if you make mistakes

Navigate using 'ls' to see options and 'cd' to choose.
Player 1 starts. Players alternate each question.
EOF

cat > "$MAZE_ROOT/medium/README.txt" << 'EOF'
⚖️ MEDIUM PATH - The Path of Perfection
=====================================

Questions: 6
Penalty: 10 seconds + reset to Question 1
Strategy: High risk, high reward - no room for error

ONE mistake sends you back to the start!
Player 1 starts. Players alternate each question.
EOF

cat > "$MAZE_ROOT/hard/README.txt" << 'EOF'
🔥 HARD PATH - The Ultimate Gamble
================================

Questions: 4 (expert level)
Penalty: 20 seconds + EJECTION (choose easy/medium instead)
Strategy: Only for the elite - one mistake = game over

ONE mistake locks this path FOREVER for your team!
Player 1 starts. Players alternate each question.
EOF

# ============================================
# Create monitoring script
# ============================================

cat > "$MAZE_ROOT/monitor.sh" << EOF
#!/bin/bash

# Monitor script to watch all teams in real-time

SERVER_URL="$SERVER_URL"

watch -n 1 "curl -s \${SERVER_URL}/api/sessions | python3 -m json.tool"
EOF
chmod +x "$MAZE_ROOT/monitor.sh"

# ============================================
# Summary
# ============================================

echo ""
echo "✅ Maze setup complete!"
echo "================================"
echo "Maze location: $MAZE_ROOT"
echo ""
echo "NEXT STEPS:"
echo "1. Start Flask server: python3 server.py"
echo "2. Source client: source maze_client.sh"
echo "3. Begin: maze_init"
echo ""
echo "Admin Dashboard: $SERVER_URL"
echo "Monitor Teams: $MAZE_ROOT/monitor.sh"
echo ""