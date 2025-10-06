#!/bin/bash

# maze_game_client.sh - FIXED with proper session creation
# Usage: source maze_game_client.sh

# Configuration - CHANGE THIS TO YOUR SERVER IP
SERVER_URL="http://localhost:5000"
TEAM_NAME=""
PLAYER_NUM=""
CURRENT_PATH=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize game
maze_init() {
    echo -e "${GREEN}Welcome to the Linux Maze Game!${NC}"
    echo -e "${BLUE}Enter your team name:${NC}"
    read TEAM_NAME
    echo -e "${BLUE}Enter your player number (1 or 2):${NC}"
    read PLAYER_NUM
    
    export MAZE_TEAM="$TEAM_NAME"
    export MAZE_PLAYER="$PLAYER_NUM"
    export MAZE_SERVER="$SERVER_URL"
    
    echo -e "${GREEN}Initialized as ${TEAM_NAME} - Player ${PLAYER_NUM}${NC}"
    
    if [ "$PLAYER_NUM" = "1" ]; then
        echo -e "${YELLOW}Next step: Run 'maze_create' to set up the team${NC}"
    else
        echo -e "${YELLOW}Next step: Wait for Player 1 to create session, then run 'maze_sync'${NC}"
    fi
}

# Create session (Player 1 only)
maze_create() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    if [ "$MAZE_PLAYER" != "1" ]; then
        echo -e "${YELLOW}Only Player 1 should create the session${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Enter Player 1 name:${NC}"
    read P1_NAME
    echo -e "${BLUE}Enter Player 2 name:${NC}"
    read P2_NAME
    
    response=$(curl -s -w "\n%{http_code}" -X POST "${MAZE_SERVER}/api/session/create" \
        -H "Content-Type: application/json" \
        -d "{\"team_name\": \"${MAZE_TEAM}\", \"player1\": \"${P1_NAME}\", \"player2\": \"${P2_NAME}\"}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ -z "$body" ]; then
        echo -e "${RED}No response from server! Check if server is running at ${MAZE_SERVER}${NC}"
        return 1
    fi
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q '"success"'; then
        echo -e "${GREEN}Session created successfully!${NC}"
        echo -e "${YELLOW}Next step: Run 'maze_start' to begin${NC}"
    else
        echo -e "${RED}Error creating session${NC}"
        error=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Server error")
        echo -e "${YELLOW}Details: $error${NC}"
        return 1
    fi
}

# Start game (Player 1 only, after maze_create)
maze_start() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/start" -X POST)
    
    if echo "$response" | grep -q '"success"'; then
        echo -e "${GREEN}Game started!${NC}"
        echo -e "${YELLOW}Choose your path:${NC}"
        echo -e "${GREEN}  easy${NC} - 10 questions, 15s penalty per wrong answer (retry same question)"
        echo -e "${BLUE}  medium${NC} - 6 questions, 10s penalty + reset to start on wrong answer"
        echo -e "${RED}  hard${NC} - 4 questions, 20s penalty + full ejection on wrong answer"
        echo ""
        echo -e "Use: ${YELLOW}cd easy${NC}, ${YELLOW}cd medium${NC}, or ${YELLOW}cd hard${NC}"
    else
        error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))" 2>/dev/null || echo "Failed to start")
        echo -e "${RED}Error: $error${NC}"
        if echo "$error" | grep -q "not found"; then
            echo -e "${YELLOW}Did you run 'maze_create' first?${NC}"
        fi
        return 1
    fi
}

# Sync with current game state
maze_sync() {
    if [ -z "$MAZE_TEAM" ]; then
        echo -e "${RED}Error: Run maze_init first!${NC}"
        return 1
    fi
    
    response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/status")
    
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}Session not found. Player 1 should run 'maze_create' and 'maze_start' first.${NC}"
        return 1
    fi
    
    current_path=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_path', ''))" 2>/dev/null)
    current_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_player', 1))" 2>/dev/null)
    current_question=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_question', 0))" 2>/dev/null)
    
    if [ -z "$current_path" ] || [ "$current_path" = "None" ]; then
        echo -e "${YELLOW}Waiting for path selection...${NC}"
        echo -e "${YELLOW}Player 1 should choose: cd easy/medium/hard${NC}"
        return 0
    fi
    
    CURRENT_PATH="$current_path"
    
    question_response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/current_question")
    
    if echo "$question_response" | grep -q '"question"'; then
        question=$(echo "$question_response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
        
        echo -e "${GREEN}Synced with game state${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}Player ${current_player}'s turn${NC}"
        echo -e "${GREEN}Path: ${current_path} | Question $((current_question + 1))${NC}"
        echo "$question"
        echo -e "${BLUE}========================================${NC}"
        
        if [ "$MAZE_PLAYER" = "$current_player" ]; then
            echo -e "${GREEN}It's YOUR turn!${NC} Use: ${YELLOW}cd <answer>${NC}"
        else
            echo -e "${YELLOW}Waiting for Player ${current_player} to answer...${NC}"
        fi
    else
        echo -e "${GREEN}Game completed!${NC}"
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
    
    if [[ "$target" == "easy" || "$target" == "medium" || "$target" == "hard" ]]; then
        current_state=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/status")
        existing_path=$(echo "$current_state" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_path', ''))" 2>/dev/null)
        
        if [ -n "$existing_path" ] && [ "$existing_path" != "None" ]; then
            echo -e "${YELLOW}Path already selected: ${existing_path}${NC}"
            echo -e "${YELLOW}Use 'maze_sync' to see current question${NC}"
            return 1
        fi
        
        response=$(curl -s -X POST "${MAZE_SERVER}/api/session/${MAZE_TEAM}/select_path" \
            -H "Content-Type: application/json" \
            -d "{\"path\": \"$target\"}")
        
        if echo "$response" | grep -q '"error"'; then
            error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))")
            echo -e "${RED}Error: $error${NC}"
            return 1
        fi
        
        CURRENT_PATH="$target"
        
        question=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
        current_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['current_player'])")
        
        echo -e "${GREEN}Path selected: $target${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}Player $current_player's turn${NC}"
        echo "$question"
        echo -e "${BLUE}========================================${NC}"
        
        if [ "$MAZE_PLAYER" = "$current_player" ]; then
            echo -e "${GREEN}It's YOUR turn!${NC} Use: ${YELLOW}cd <answer>${NC}"
        else
            echo -e "${YELLOW}Player $current_player should answer first${NC}"
        fi
        
        return 0
    fi
    
    sync_response=$(curl -s "${MAZE_SERVER}/api/session/${MAZE_TEAM}/status")
    server_current_player=$(echo "$sync_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('current_player', 1))" 2>/dev/null)
    
    if [ "$MAZE_PLAYER" != "$server_current_player" ]; then
        echo -e "${RED}Not your turn! Player $server_current_player should answer.${NC}"
        return 1
    fi
    
    response=$(curl -s -X POST "${MAZE_SERVER}/api/session/${MAZE_TEAM}/answer" \
        -H "Content-Type: application/json" \
        -d "{\"answer\": \"$target\", \"player\": $MAZE_PLAYER}")
    
    if echo "$response" | grep -q '"error"'; then
        error=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', 'Unknown error'))")
        echo -e "${RED}$error${NC}"
        return 1
    fi
    
    correct=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('correct', False))")
    
    if [ "$correct" = "True" ]; then
        game_complete=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('game_complete', False))")
        
        if [ "$game_complete" = "True" ]; then
            total_time=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['total_time'])")
            penalties=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['penalties'])")
            
            echo -e "${GREEN}========================================${NC}"
            echo -e "${GREEN}CONGRATULATIONS! MAZE COMPLETED!${NC}"
            echo -e "${GREEN}========================================${NC}"
            echo -e "${YELLOW}Total Time: ${total_time}s${NC}"
            echo -e "${RED}Penalties: ${penalties}s${NC}"
            
            CURRENT_PATH=""
            return 0
        fi
        
        next_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['next_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
        next_player=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['current_player'])")
        
        echo -e "${GREEN}Correct!${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}Player $next_player's turn${NC}"
        echo "$next_q"
        echo -e "${BLUE}========================================${NC}"
        
        if [ "$MAZE_PLAYER" = "$next_player" ]; then
            echo -e "${GREEN}Your turn!${NC} Use: ${YELLOW}cd <answer>${NC}"
        else
            echo -e "${YELLOW}Waiting for Player ${next_player}...${NC}"
        fi
    else
        penalty=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('penalty', 0))")
        penalty_type=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('penalty_type', ''))")
        message=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message', ''))")
        
        echo -e "${RED}Wrong Answer!${NC}"
        echo -e "${RED}Penalty: +${penalty}s${NC}"
        echo -e "${YELLOW}$message${NC}"
        
        if [ "$penalty_type" = "retry" ]; then
            retry_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['retry_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
            echo -e "${BLUE}========================================${NC}"
            echo -e "${YELLOW}Try again:${NC}"
            echo "$retry_q"
            echo -e "${BLUE}========================================${NC}"
        elif [ "$penalty_type" = "reset_path" ]; then
            reset_q=$(echo "$response" | python3 -c "import sys, json; data=json.load(sys.stdin); q=data['reset_to_question']; print(f\"{q['question']}\nOptions: {', '.join(q['options'].keys())}\")")
            echo -e "${BLUE}========================================${NC}"
            echo -e "${YELLOW}Reset to start - Player 1:${NC}"
            echo "$reset_q"
            echo -e "${BLUE}========================================${NC}"
        elif [ "$penalty_type" = "eject" ]; then
            CURRENT_PATH=""
            echo -e "${RED}Hard path LOCKED. Choose easy or medium.${NC}"
        fi
    fi
    
    return 0
}

alias cd='maze_cd'

maze_help() {
    echo -e "${GREEN}Linux Maze Game - Commands${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${BLUE}maze_init${NC}       - Initialize team and player"
    echo -e "${BLUE}maze_create${NC}     - Create session (Player 1 only)"
    echo -e "${BLUE}maze_start${NC}      - Start game (Player 1 only)"
    echo -e "${BLUE}maze_sync${NC}       - Sync with current state"
    echo -e "${BLUE}maze_status${NC}     - Check detailed status"
    echo -e "${BLUE}cd <path>${NC}       - Select path or submit answer"
    echo -e "${BLUE}maze_help${NC}       - Show this help"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Workflow:${NC}"
    echo -e "1. Player 1: maze_init -> maze_create -> maze_start"
    echo -e "2. Player 2: maze_init -> maze_sync"
    echo -e "3. Both: cd easy/medium/hard (P1 chooses)"
    echo -e "4. Both: Take turns with 'cd <answer>'"
}

maze_ls() {
    if [ -n "$CURRENT_PATH" ]; then
        echo -e "${YELLOW}Use 'maze_sync' to see current question${NC}"
    else
        echo -e "${YELLOW}Available paths:${NC}"
        echo -e "${GREEN}  easy/${NC}    - 10 questions"
        echo -e "${BLUE}  medium/${NC}  - 6 questions"
        echo -e "${RED}  hard/${NC}    - 4 questions"
    fi
}

alias ls='maze_ls'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Linux Maze Game - Client Loaded${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Type 'maze_help' for commands${NC}"
echo -e "${YELLOW}Type 'maze_init' to start${NC}"
echo ""