    #!/bin/bash

    # maze_setup.sh - Creates the physical maze directory structure
    # This script creates the actual directories and trap scripts

    MAZE_ROOT="/mnt/c/projects/the-maze-bob/linux_maze"
    SERVER_URL="http://192.168.29.210:5000"

    echo "🎮 Setting up Linux Maze Game..."
    echo "================================"

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
        
        # Create a success script in the correct directory
        cat > "$question_dir/$correct_answer/.maze_check" << 'EOF'
    #!/bin/bash
    TEAM_NAME=${MAZE_TEAM}
    PLAYER_NUM=${MAZE_PLAYER}
    SERVER_URL=${MAZE_SERVER}

    if [ -z "$TEAM_NAME" ]; then
        echo "Error: MAZE_TEAM not set. Run maze_init first!"
        exit 1
    fi

    # Extract the answer from the current directory
    ANSWER=$(basename "$PWD")

    # Submit the answer
    response=$(curl -s -X POST "${SERVER_URL}/api/session/${TEAM_NAME}/answer" \
        -H "Content-Type: application/json" \
        -d "{\"answer\": \"$ANSWER\", \"player\": $PLAYER_NUM}")

    echo "$response"
    EOF
        chmod +x "$question_dir/$correct_answer/.maze_check"
        
        # Create wrong answer directories with trap scripts
        for wrong_ans in "${wrong_answers[@]}"; do
            mkdir -p "$question_dir/$wrong_ans"
            
            cat > "$question_dir/$wrong_ans/.maze_trap" << 'EOF'
    #!/bin/bash
    TEAM_NAME=${MAZE_TEAM}
    PLAYER_NUM=${MAZE_PLAYER}
    SERVER_URL=${MAZE_SERVER}

    if [ -z "$TEAM_NAME" ]; then
        echo "Error: MAZE_TEAM not set. Run maze_init first!"
        exit 1
    fi

    ANSWER=$(basename "$PWD")

    # Submit wrong answer
    response=$(curl -s -X POST "${SERVER_URL}/api/session/${TEAM_NAME}/answer" \
        -H "Content-Type: application/json" \
        -d "{\"answer\": \"$ANSWER\", \"player\": $PLAYER_NUM}")

    echo "$response"
    EOF
            chmod +x "$question_dir/$wrong_ans/.maze_trap"
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
    # Create hook scripts for cd command
    # ============================================
    echo "Creating maze hooks..."

    cat > "$MAZE_ROOT/.maze_cd_hook" << 'EOF'
    #!/bin/bash

    # This hook is triggered when cd is used
    # It checks if we're entering an answer directory

    if [ -f ".maze_check" ]; then
        # Correct answer
        ./.maze_check
    elif [ -f ".maze_trap" ]; then
        # Wrong answer - trigger trap
        ./.maze_trap
    fi
    EOF
    chmod +x "$MAZE_ROOT/.maze_cd_hook"

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
    1. Source the client script: source maze_game_client.sh
    2. Initialize: maze_init
    3. Start game: maze_start
    4. Choose path: cd easy (or medium/hard)
    5. Answer questions: cd <answer>

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
    # Create team directory generator
    # ============================================

    cat > "$MAZE_ROOT/create_team_space.sh" << 'EOF'
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
    EOF
    chmod +x "$MAZE_ROOT/create_team_space.sh"

    # ============================================
    # Summary
    # ============================================

    echo ""
    echo "✅ Maze setup complete!"
    echo "================================"
    echo "Maze location: $MAZE_ROOT"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Start Flask server: python maze_server.py"
    echo "2. Source client: source maze_game_client.sh"
    echo "3. Create team space: $MAZE_ROOT/create_team_space.sh <team_name>"
    echo "4. Begin: cd to team space, run maze_init"
    echo ""
    echo "Admin Dashboard: http://localhost:5000"
    echo "Monitor Teams: $MAZE_ROOT/monitor.sh"
    echo ""