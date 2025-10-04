#!/bin/bash

# maze_game_client.sh - Enhanced Client with Auto-Sync
# Usage: source maze_game_client.sh

# Configuration
SERVER_URL="http://192.168.29.210:5000"
TEAM_NAME=""
PLAYER_NUM=""
CURRENT_PATH=""
STATE_VERSION=0
SYNC_PID=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Notification sound (optional - comment out if no audio)
notify_sound() {
    # Uncomment one of these if you want audio notifications:
    # echo -e '\a'  # Terminal bell
    # paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
    :
}

# Clear previous notifications
clear_notification() {
    # Clear the last 2 lines if they were notifications
    :
}

#!/bin/bash

# Fixed auto-sync background process
# Fixed auto-sync background process - CORRECT VERSION
auto_sync_daemon() {
    local team=$1
    local player=$2
    local server=$3
    local parent_pid=$4
    local last_version=0
    local last_notified_turn=""  # Track when we last notified THIS player
    
    while true; do
        sleep 2
        
        # Check if parent shell still exists
        if ! kill -0 $parent_pid 2>/dev/null; then
            exit 0
        fi
        
        # Poll for updates
        response=$(curl -s "${server}/api/session/${team}/poll?version=${last_version}&player=${player}" 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$response" ]; then
            continue
        fi
        
        # Parse response
        has_changes=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('has_changes', False))" 2>/dev/null)
        is_your_turn=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('is_your_turn', False))" 2>/dev/null)
        current_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_player', 0))" 2>/dev/null)
        state_ver=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('state_version', 0))" 2>/dev/null)
        game_complete=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('game_complete', False))" 2>/dev/null)
        current_question=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_question', 0))" 2>/dev/null)
        
        # Update version
        if [ -n "$state_ver" ] && [ "$state_ver" != "None" ]; then
            last_version=$state_ver
        fi
        
        # Create unique turn identifier: player_question
        current_turn_id="${current_player}_${current_question}"
        
        # Notify on YOUR turn (only if this is a new turn for you)
        if [ "$is_your_turn" = "True" ] && [ "$current_turn_id" != "$last_notified_turn" ]; then
            notify_sound
            echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}🔔 IT'S YOUR TURN! 🔔${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            # Show current question
            question_data=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(q.get('text', '')) if q else print('')" 2>/dev/null)
            options=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(', '.join(q.get('options', []))) if q else print('')" 2>/dev/null)
            
            if [ -n "$question_data" ]; then
                echo -e "${YELLOW}Question:${NC} $question_data"
                echo -e "${YELLOW}Options:${NC} $options"
                echo -e "${GREEN}Use: ${YELLOW}cd <answer>${NC}"
            fi
            
            # Mark this turn as notified
            last_notified_turn="$current_turn_id"
        fi
        
        # Notify on game completion
        if [ "$game_complete" = "True" ]; then
            echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}🎉 GAME COMPLETED! 🎉${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 0
        fi
    done
}

# Stop auto-sync
stop_auto_sync() {
    if [ -n "$SYNC_PID" ] && kill -0 $SYNC_PID 2>/dev/null; then
        kill $SYNC_PID 2>/dev/null
        wait $SYNC_PID 2>/dev/null
        SYNC_PID=""
    fi
}

# Start auto-sync
start_auto_sync() {
    stop_auto_sync
    auto_sync_daemon "$MAZE_TEAM" "$MAZE_PLAYER" "$MAZE_SERVER" $BASHPID &
    SYNC_PID=$!
    disown $SYNC_PID 2>/dev/null || true
    echo -e "${CYAN}🔄 Auto-sync enabled (updates every 2s)${NC}"
}

# Initialize game - NOW WITH AUTO SERVER REGISTRATION
maze_init() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║        🎮 Welcome to the Linux Maze Game! 🎮           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Enter your team name:${NC}"
    read TEAM_NAME
    
    echo -e "${BLUE}Enter your player number (1 or 2):${NC}"
    read PLAYER_NUM
    
    # Validate player number
    if [[ "$PLAYER_NUM" != "1" && "$PLAYER_NUM" != "2" ]]; then
        echo -e "${RED}❌ Invalid player number! Must be 1 or 2${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Enter Player 1's name:${NC}"
    read PLAYER1_NAME
    
    echo -e "${BLUE}Enter Player 2's name:${NC}"
    read PLAYER2_NAME
    
    # Create session on server
    echo -e "${YELLOW}📡 Registering with server...${NC}"
    
    response=$(curl -s -X POST "${SERVER_URL}/api/session/create" \
        -H "Content-Type: application/json" \
        -d "{\"team_name\": \"${TEAM_NAME}\", \"player1\": \"${PLAYER1_NAME}\", \"player2\": \"${PLAYER2_NAME}\"}")
    
    if echo "$response" | grep -q '"success": true'; then
        already_exists=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('already_exists', False))" 2>/dev/null)
        
        export MAZE_TEAM="$TEAM_NAME"
        export MAZE_PLAYER="$PLAYER_NUM"
        export MAZE_SERVER="$SERVER_URL"
        export MAZE_PLAYER1="$PLAYER1_NAME"
        export MAZE_PLAYER2="$PLAYER2_NAME"
        
        echo -e "${GREEN}✅ Session registered successfully!${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Team: ${TEAM_NAME}${NC}"
        echo -e "${CYAN}Player 1: ${PLAYER1_NAME}${NC}"
        echo -e "${CYAN}Player 2: ${PLAYER2_NAME}${NC}"
        echo -e "${CYAN}You are: Player ${PLAYER_NUM}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ "$already_exists" = "True" ]; then
            echo -e "${YELLOW}ℹ️  Session already exists - joining existing game${NC}"
        fi
        
        # Start auto-sync
        start_auto_sync
        
        echo ""
        if [ "$PLAYER_NUM" = "1" ]; then
            echo -e "${YELLOW}▶️  You are Player 1 - Use 'maze_start' to begin the game${NC}"
        else
            echo -e "${YELLOW}⏳ You are Player 2 - Wait for Player 1 to start with 'maze_start'${NC}"
        fi
        
        echo -e "${YELLOW}💡 Auto-sync is enabled - you'll be notified when it's your turn${NC}"
    else
        error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null)
        echo -e "${RED}❌ Registration failed: $error${NC}"
        return 1
    fi
}

# Start game (only needed once per team)
maze_start() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    response=$(curl -s -X POST "${MAZE_SERVER}/api/session/${MAZE_TEAM}/start")
    
    if echo "$response" | grep -q '"error"'; then
        error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))")
        echo -e "${RED}❌ Error: $error${NC}"
        return 1
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🚀 Game started!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Choose your path:${NC}"
    echo ""
    echo -e "${GREEN}  🍃 easy${NC}     - 10 questions, 15s penalty (retry same question)"
    echo -e "${BLUE}  ⚖️  medium${NC}   - 6 questions, 10s penalty + reset to start"
    echo -e "${RED}  🔥 hard${NC}     - 4 questions, 20s penalty + full ejection"
    echo ""
    echo -e "Use: ${YELLOW}cd easy${NC}, ${YELLOW}cd medium${NC}, or ${YELLOW}cd hard${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Manual sync (still available)
maze_sync() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/poll?version=${STATE_VERSION}&player=${MAZE_PLAYER}")
    
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}❌ Session not found or error occurred${NC}"
        return 1
    fi
    
    # Parse state
    game_started=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('game_started', False))" 2>/dev/null)
    current_path=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_path', ''))" 2>/dev/null)
    current_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_player', 1))" 2>/dev/null)
    is_your_turn=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('is_your_turn', False))" 2>/dev/null)
    game_complete=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('game_complete', False))" 2>/dev/null)
    state_ver=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('state_version', 0))" 2>/dev/null)
    
    STATE_VERSION=$state_ver
    
    if [ "$game_complete" = "True" ]; then
        total_time=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total_time', 0))" 2>/dev/null)
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🎉 GAME COMPLETED! 🎉${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Total Time: ${total_time}s${NC}"
        return 0
    fi
    
    if [ "$game_started" = "False" ]; then
        echo -e "${YELLOW}⏳ Game not started yet${NC}"
        if [ "$MAZE_PLAYER" = "1" ]; then
            echo -e "${YELLOW}Use 'maze_start' to begin${NC}"
        else
            echo -e "${YELLOW}Waiting for Player 1 to start...${NC}"
        fi
        return 0
    fi
    
    if [ -z "$current_path" ] || [ "$current_path" = "None" ]; then
        echo -e "${YELLOW}⏳ Waiting for path selection...${NC}"
        if [ "$current_player" = "1" ]; then
            echo -e "${YELLOW}Player 1 should choose: cd easy/medium/hard${NC}"
        fi
        return 0
    fi
    
    CURRENT_PATH="$current_path"
    
    # Get question details
    question_data=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(q.get('text', '')) if q else print('')" 2>/dev/null)
    options=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(', '.join(q.get('options', []))) if q else print('')" 2>/dev/null)
    question_num=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(q.get('number', 0)) if q else print(0)" 2>/dev/null)
    total_q=$(echo "$response" | python3 -c "import sys, json; q=json.load(sys.stdin).get('question', {}); print(q.get('total', 0)) if q else print(0)" 2>/dev/null)
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Game Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Path:${NC} $current_path"
    echo -e "${YELLOW}Progress:${NC} Question $question_num/$total_q"
    echo -e "${YELLOW}Current Turn:${NC} Player $current_player"
    
    if [ -n "$question_data" ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Question:${NC} $question_data"
        echo -e "${YELLOW}Options:${NC} $options"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    if [ "$is_your_turn" = "True" ]; then
        echo -e "${GREEN}✅ It's YOUR turn!${NC} Use: ${YELLOW}cd <answer>${NC}"
    else
        echo -e "${YELLOW}⏳ Waiting for Player ${current_player}...${NC}"
    fi
}

# Get current status
maze_status() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/status")
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
}

# Custom cd function
maze_cd() {
    local target="$1"
    
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    # Check if selecting a path
    if [[ "$target" == "easy" || "$target" == "medium" || "$target" == "hard" ]]; then
        # Sync first to check current state
        current_state=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/status")
        existing_path=$(echo "$current_state" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_path', ''))" 2>/dev/null)
        
        if [ -n "$existing_path" ] && [ "$existing_path" != "None" ]; then
            echo -e "${YELLOW}⚠️  Path already selected: ${existing_path}${NC}"
            echo -e "${YELLOW}Use 'maze_sync' to see current question${NC}"
            return 1
        fi
        
        response=$(curl -s -X POST "${MAZE_SERVER}/api/session/${MAZE_TEAM}/select_path" \
            -H "Content-Type: application/json" \
            -d "{\"path\": \"$target\"}")
        
        if echo "$response" | grep -q '"error"'; then
            error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))")
            echo -e "${RED}❌ Error: $error${NC}"
            return 1
        fi
        
        CURRENT_PATH="$target"
        
        question=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
        current_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['current_player'])")
        
        echo -e "${GREEN}✅ Path selected: $target${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}👤 Player $current_player's turn${NC}"
        echo "$question"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ "$MAZE_PLAYER" = "$current_player" ]; then
            echo -e "${GREEN}✅ It's YOUR turn!${NC} Use: ${YELLOW}cd <answer>${NC}"
        else
            echo -e "${YELLOW}⏳ Player $current_player should answer first${NC}"
        fi
        
        return 0
    fi
    
    # This is an answer submission
    response=$(curl -s -X POST "${MAZE_SERVER}/api/session/${MAZE_TEAM}/answer" \
        -H "Content-Type: application/json" \
        -d "{\"answer\": \"$target\", \"player\": $MAZE_PLAYER}")
    
    if echo "$response" | grep -q '"error"'; then
        error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))")
        echo -e "${RED}❌ $error${NC}"
        echo -e "${YELLOW}💡 Use 'maze_sync' to check current state${NC}"
        return 1
    fi
    
    correct=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('correct', False))")
    
    if [ "$correct" = "True" ]; then
        game_complete=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('game_complete', False))")
        
        if [ "$game_complete" = "True" ]; then
            total_time=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['total_time'])")
            penalties=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['penalties'])")
            
            stop_auto_sync
            
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}🎉 CONGRATULATIONS! MAZE COMPLETED! 🎉${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}Total Time: ${total_time}s${NC}"
            echo -e "${RED}Penalties: ${penalties}s${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            CURRENT_PATH=""
            return 0
        fi
        
        next_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['next_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
        next_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['current_player'])")
        
        echo -e "${GREEN}✅ Correct!${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}👤 Player $next_player's turn${NC}"
        echo "$next_q"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        if [ "$MAZE_PLAYER" != "$next_player" ]; then
            echo -e "${YELLOW}⏳ Waiting for Player ${next_player}... (auto-sync active)${NC}"
        fi
    else
        penalty=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('penalty', 0))")
        penalty_type=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('penalty_type', ''))")
        message=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', ''))")
        
        echo -e "${RED}❌ Wrong Answer!${NC}"
        echo -e "${RED}⏱️  Penalty: +${penalty}s${NC}"
        echo -e "${YELLOW}$message${NC}"
        
        if [ "$penalty_type" = "retry" ]; then
            retry_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['retry_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}👤 Player $MAZE_PLAYER - Try again:${NC}"
            echo "$retry_q"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        elif [ "$penalty_type" = "reset_path" ]; then
            reset_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['reset_to_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}👤 Player 1 - Starting over:${NC}"
            echo "$reset_q"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        elif [ "$penalty_type" = "eject" ]; then
            CURRENT_PATH=""
            echo -e "${RED}🚫 Hard path now LOCKED. Choose easy or medium.${NC}"
        fi
    fi
    
    return 0
}

# Toggle auto-sync on/off
maze_autosync() {
    local action="$1"
    
    if [ "$action" = "off" ] || [ "$action" = "stop" ]; then
        stop_auto_sync
        echo -e "${YELLOW}🔕 Auto-sync disabled${NC}"
    elif [ "$action" = "on" ] || [ "$action" = "start" ]; then
        if [ -z "$MAZE_TEAM" ]; then
            echo -e "${RED}Error: Run maze_init first!${NC}"
            return 1
        fi
        start_auto_sync
    else
        echo -e "${YELLOW}Usage: maze_autosync [on|off]${NC}"
    fi
}

# Cleanup on exit
maze_cleanup() {
    stop_auto_sync
}

trap maze_cleanup EXIT

alias cd='maze_cd'

maze_help() {
    echo -e "${GREEN}🎮 Linux Maze Game - Commands${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}maze_init${NC}         - Initialize team (auto-registers with server)"
    echo -e "${BLUE}maze_start${NC}        - Start the game (Player 1 only)"
    echo -e "${BLUE}maze_sync${NC}         - Manually sync with current state"
    echo -e "${BLUE}maze_autosync${NC}     - Toggle auto-sync [on|off]"
    echo -e "${BLUE}maze_status${NC}       - Check detailed game status (JSON)"
    echo -e "${BLUE}cd <path>${NC}         - Select path or submit answer"
    echo -e "${BLUE}maze_help${NC}         - Show this help"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💡 Auto-sync runs in background and notifies on turn${NC}"
}

maze_ls() {
    if [ -n "$CURRENT_PATH" ]; then
        echo -e "${YELLOW}Current path: $CURRENT_PATH${NC}"
        echo -e "${YELLOW}Use 'maze_sync' to see current question${NC}"
    else
        echo -e "${YELLOW}Available paths:${NC}"
        echo -e "${GREEN}  easy/    ${NC}- 10 questions, 15s penalty"
        echo -e "${BLUE}  medium/  ${NC}- 6 questions, 10s penalty + reset"
        echo -e "${RED}  hard/    ${NC}- 4 questions, 20s penalty + eject"
    fi
}

alias ls='maze_ls'

echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     🎮 Linux Maze Game -Client Loaded! 🎮             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}✨ NEW FEATURES:${NC}"
echo -e "${YELLOW}  • Auto team registration (no admin needed!)${NC}"
echo -e "${YELLOW}  • Real-time notifications when it's your turn${NC}"
echo -e "${YELLOW}  • Background auto-sync (every 2 seconds)${NC}"
echo ""
echo -e "${YELLOW}Type 'maze_help' to see all commands${NC}"
echo -e "${YELLOW}Type 'maze_init' to start playing${NC}"
echo ""