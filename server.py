from flask import Flask, request, jsonify, render_template_string
from datetime import datetime
import json
import os
from pathlib import Path

app = Flask(__name__)

game_sessions = {}

GAME_CONFIG = {
    'easy': {
        'questions': 10,
        'penalty_time': 15,
        'penalty_type': 'time_and_retry',
        'avg_time_per_question': 30
    },
    'medium': {
        'questions': 6,
        'penalty_time': 10,
        'penalty_type': 'reset_to_start',
        'avg_time_per_question': 45
    },
    'hard': {
        'questions': 4,
        'penalty_time': 20,
        'penalty_type': 'eject_to_maze_start',
        'avg_time_per_question': 90
    }
}

QUESTIONS = {
    'easy': [
        {'id': 1, 'question': 'Which command lists files and directories in the current location?',
         'options': {'ls': True, 'cd': False, 'pwd': False, 'cat': False}},
        {'id': 2, 'question': 'Which command changes the current working directory?',
         'options': {'cd': True, 'ls': False, 'mv': False, 'cp': False}},
        {'id': 3, 'question': 'Which command searches for patterns in text files?',
         'options': {'grep': True, 'find': False, 'sed': False, 'awk': False}},
        {'id': 4, 'question': 'Which command changes file permissions using symbolic notation?',
         'options': {'chmod': True, 'chown': False, 'chgrp': False, 'umask': False}},
        {'id': 5, 'question': 'Which command displays currently running processes?',
         'options': {'ps': True, 'top': False, 'kill': False, 'jobs': False}},
        {'id': 6, 'question': 'Which command displays the manual pages for other commands?',
         'options': {'man': True, 'info': False, 'help': False, 'whatis': False}},
        {'id': 7, 'question': 'Which command outputs text to the terminal?',
         'options': {'echo': True, 'printf': False, 'cat': False, 'tee': False}},
        {'id': 8, 'question': 'Which command copies files and directories?',
         'options': {'cp': True, 'mv': False, 'rm': False, 'ln': False}},
        {'id': 9, 'question': 'Which command displays the first 10 lines of a file by default?',
         'options': {'head': True, 'tail': False, 'more': False, 'less': False}},
        {'id': 10, 'question': 'Which command creates compressed archive files (.tar)?',
         'options': {'tar': True, 'gzip': False, 'zip': False, 'bzip2': False}}
    ],
    'medium': [
        {'id': 1, 'question': 'Which command searches for files recursively using various criteria?',
         'options': {'find': True, 'locate': False, 'which': False, 'whereis': False}},
        {'id': 2, 'question': 'Which command is a pattern scanning and processing language?',
         'options': {'awk': True, 'sed': False, 'grep': False, 'cut': False}},
        {'id': 3, 'question': 'Which command builds and executes commands from standard input?',
         'options': {'xargs': True, 'parallel': False, 'find': False, 'exec': False}},
        {'id': 4, 'question': 'Which modern command displays network socket statistics (replaces netstat)?',
         'options': {'ss': True, 'netstat': False, 'lsof': False, 'nmap': False}},
        {'id': 5, 'question': 'Which command manages systemd services on modern Linux?',
         'options': {'systemctl': True, 'service': False, 'init': False, 'upstart': False}},
        {'id': 6, 'question': 'Which command efficiently syncs files and directories locally or remotely?',
         'options': {'rsync': True, 'scp': False, 'sftp': False, 'ftp': False}}
    ],
    'hard': [
        {'id': 1, 'question': 'Which command traces system calls and signals made by a process?',
         'options': {'strace': True, 'ltrace': False, 'gdb': False, 'valgrind': False}},
        {'id': 2, 'question': 'Which is the legacy netfilter firewall administration tool for Linux?',
         'options': {'iptables': True, 'nftables': False, 'ufw': False, 'firewalld': False}},
        {'id': 3, 'question': 'Which command provides performance analysis tools for Linux?',
         'options': {'perf': True, 'dtrace': False, 'ftrace': False, 'bpftrace': False}},
        {'id': 4, 'question': 'Which command prints shared library dependencies of an executable?',
         'options': {'ldd': True, 'objdump': False, 'readelf': False, 'nm': False}}
    ]
}

class GameSession:
    def __init__(self, team_name, player1, player2):
        self.team_name = team_name
        self.player1 = player1
        self.player2 = player2
        self.start_time = None
        self.end_time = None
        self.current_path = None
        self.current_question = 0
        self.current_player = 1
        self.total_penalties = 0
        self.wrong_answers = []
        self.hard_path_locked = False
        self.events = []
        self.path_start_time = None
        self.state_version = 0  # For tracking state changes
        
    def to_dict(self):
        return {
            'team_name': self.team_name,
            'player1': self.player1,
            'player2': self.player2,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'current_path': self.current_path,
            'current_question': self.current_question,
            'current_player': self.current_player,
            'total_penalties': self.total_penalties,
            'wrong_answers': self.wrong_answers,
            'hard_path_locked': self.hard_path_locked,
            'total_time': self.get_total_time(),
            'events': self.events,
            'state_version': self.state_version
        }
    
    def get_total_time(self):
        if not self.start_time:
            return 0
        end = self.end_time or datetime.now()
        return (end - self.start_time).total_seconds() + self.total_penalties

@app.route('/')
def index():
    return render_template_string('''<!DOCTYPE html><html><head><title>Linux Maze Game</title>
    <style>body{font-family:'Courier New',monospace;background:#1a1a1a;color:#0f0;padding:20px}
    .container{max-width:1200px;margin:0 auto}h1{color:#0f0;border-bottom:2px solid #0f0;padding-bottom:10px}
    .session{background:#2a2a2a;padding:15px;margin:10px 0;border-left:4px solid #0f0}
    .stats{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:20px 0}
    .stat-box{background:#2a2a2a;padding:15px;text-align:center;border:1px solid #0f0}
    button{background:#0f0;color:#000;border:none;padding:10px 20px;cursor:pointer;font-family:inherit;margin:5px}
    button:hover{background:#0a0}.penalty{color:#f00}.success{color:#0f0}
    input{background:#2a2a2a;color:#0f0;border:1px solid #0f0;padding:8px;font-family:inherit}</style></head>
    <body><div class="container"><h1>🎮 Linux Maze Game - Control Center</h1>
    <div class="stats"><div class="stat-box"><h3>Active Sessions</h3><p id="active-count">0</p></div>
    <div class="stat-box"><h3>Completed</h3><p id="completed-count">0</p></div>
    <div class="stat-box"><h3>Total Penalties</h3><p id="total-penalties">0s</p></div></div>
    <h2>Active Sessions</h2><div id="sessions"></div></div>
    <script>async function loadSessions(){const res=await fetch('/api/sessions');const data=await res.json();
    document.getElementById('active-count').textContent=data.sessions.filter(s=>!s.end_time).length;
    document.getElementById('completed-count').textContent=data.sessions.filter(s=>s.end_time).length;
    document.getElementById('total-penalties').textContent=data.sessions.reduce((sum,s)=>sum+s.total_penalties,0)+'s';
    document.getElementById('sessions').innerHTML=data.sessions.map(s=>`<div class="session">
    <h3>🎯 ${s.team_name}</h3><p>👥 ${s.player1} & ${s.player2}</p>
    <p>📍 ${s.current_path||'Not started'} | Q${s.current_question+1} | Player ${s.current_player}</p>
    <p>⏱️ ${s.total_time.toFixed(1)}s | <span class="penalty">Penalties: ${s.total_penalties}s</span></p>
    ${s.end_time?'<p class="success">✅ COMPLETED</p>':'<p>🏃 IN PROGRESS</p>'}</div>`).join('')}
    setInterval(loadSessions,2000);loadSessions()</script>
    </body></html>''')

@app.route('/api/session/create', methods=['POST'])
def create_session():
    """ENHANCED: Auto-creates session from client init"""
    data = request.json
    team_name = data.get('team_name')
    player1 = data.get('player1')
    player2 = data.get('player2')
    
    if not all([team_name, player1, player2]):
        return jsonify({'error': 'Missing required fields'}), 400
    
    # Check if session already exists
    if team_name in game_sessions:
        session = game_sessions[team_name]
        return jsonify({
            'success': True, 
            'team_name': team_name, 
            'message': 'Session already exists',
            'already_exists': True,
            'player1': session.player1,
            'player2': session.player2,
            'started': session.start_time is not None
        })
    
    session = GameSession(team_name, player1, player2)
    game_sessions[team_name] = session
    
    return jsonify({
        'success': True, 
        'team_name': team_name, 
        'message': 'Session created successfully',
        'already_exists': False
    })

@app.route('/api/session/<team_name>/start', methods=['POST'])
def start_game(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    
    if session.start_time:
        return jsonify({
            'success': True, 
            'message': 'Game already started',
            'start_time': session.start_time.isoformat()
        })
    
    session.start_time = datetime.now()
    session.state_version += 1
    session.events.append({'type': 'game_start', 'timestamp': session.start_time.isoformat()})
    return jsonify({'success': True, 'start_time': session.start_time.isoformat()})

@app.route('/api/session/<team_name>/poll', methods=['GET'])
def poll_updates(team_name):
    """NEW: Efficient polling endpoint for real-time updates"""
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    
    last_version = request.args.get('version', 0, type=int)
    player_num = request.args.get('player', 1, type=int)
    
    # Return current state with change indicator
    current_state = {
        'state_version': session.state_version,
        'has_changes': session.state_version > last_version,
        'current_player': session.current_player,
        'is_your_turn': session.current_player == player_num,
        'current_path': session.current_path,
        'current_question': session.current_question,
        'game_started': session.start_time is not None,
        'game_complete': session.end_time is not None,
        'total_penalties': session.total_penalties,
        'hard_path_locked': session.hard_path_locked
    }
    
    # Include current question if in progress
    if session.current_path and not session.end_time:
        if session.current_question < len(QUESTIONS[session.current_path]):
            question = QUESTIONS[session.current_path][session.current_question]
            current_state['question'] = {
                'id': question['id'],
                'text': question['question'],
                'options': list(question['options'].keys()),
                'number': session.current_question + 1,
                'total': len(QUESTIONS[session.current_path])
            }
    
    if session.end_time:
        current_state['total_time'] = session.get_total_time()
    
    return jsonify(current_state)

@app.route('/api/session/<team_name>/current_question', methods=['GET'])
def get_current_question(team_name):
    """CRITICAL: This endpoint enables player synchronization"""
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    if not session.current_path:
        return jsonify({'error': 'No path selected yet'}), 400
    if session.end_time:
        return jsonify({'game_complete': True})
    path = session.current_path
    question_idx = session.current_question
    if question_idx >= len(QUESTIONS[path]):
        return jsonify({'game_complete': True})
    question = QUESTIONS[path][question_idx]
    return jsonify({
        'success': True,
        'question': question,
        'current_player': session.current_player,
        'question_number': question_idx + 1,
        'total_questions': len(QUESTIONS[path])
    })

@app.route('/api/session/<team_name>/select_path', methods=['POST'])
def select_path(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    data = request.json
    path = data.get('path', '').lower()
    if path not in ['easy', 'medium', 'hard']:
        return jsonify({'error': 'Invalid path'}), 400
    if path == 'hard' and session.hard_path_locked:
        return jsonify({'error': 'Hard path is locked for this session'}), 403
    session.current_path = path
    session.current_question = 0
    session.path_start_time = datetime.now()
    session.state_version += 1
    session.events.append({'type': 'path_selected', 'path': path, 'timestamp': datetime.now().isoformat()})
    question = QUESTIONS[path][0]
    return jsonify({'success': True, 'path': path, 'question': question, 'current_player': session.current_player})

@app.route('/api/session/<team_name>/answer', methods=['POST'])
def submit_answer(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    data = request.json
    answer = data.get('answer')
    player = data.get('player', session.current_player)
    if player != session.current_player:
        return jsonify({'error': f'Wrong player! Player {session.current_player} should answer.',
                       'current_player': session.current_player}), 403
    path = session.current_path
    question_idx = session.current_question
    question = QUESTIONS[path][question_idx]
    is_correct = question['options'].get(answer, False)
    timestamp = datetime.now()
    session.state_version += 1
    session.events.append({'type': 'answer_submitted', 'player': player, 'question_id': question['id'],
                          'answer': answer, 'correct': is_correct, 'timestamp': timestamp.isoformat()})
    if is_correct:
        session.current_question += 1
        session.current_player = 2 if session.current_player == 1 else 1
        if session.current_question >= len(QUESTIONS[path]):
            session.end_time = datetime.now()
            session.events.append({'type': 'game_completed', 'timestamp': session.end_time.isoformat()})
            return jsonify({'success': True, 'correct': True, 'game_complete': True,
                          'total_time': session.get_total_time(), 'penalties': session.total_penalties})
        next_question = QUESTIONS[path][session.current_question]
        return jsonify({'success': True, 'correct': True, 'next_question': next_question,
                       'current_player': session.current_player})
    else:
        session.wrong_answers.append({'question_id': question['id'], 'answer': answer,
                                     'timestamp': timestamp.isoformat()})
        penalty_config = GAME_CONFIG[path]
        if path == 'easy':
            session.total_penalties += penalty_config['penalty_time']
            return jsonify({'success': False, 'correct': False, 'penalty': penalty_config['penalty_time'],
                          'penalty_type': 'retry', 'message': f"Wrong! {penalty_config['penalty_time']}s penalty.",
                          'retry_question': question, 'current_player': session.current_player})
        elif path == 'medium':
            session.total_penalties += penalty_config['penalty_time']
            session.current_question = 0
            session.current_player = 1
            return jsonify({'success': False, 'correct': False, 'penalty': penalty_config['penalty_time'],
                          'penalty_type': 'reset_path', 'message': f"Wrong! {penalty_config['penalty_time']}s penalty. Reset!",
                          'reset_to_question': QUESTIONS[path][0], 'current_player': 1})
        elif path == 'hard':
            session.total_penalties += penalty_config['penalty_time']
            session.current_path = None
            session.current_question = 0
            session.hard_path_locked = True
            session.current_player = 1
            return jsonify({'success': False, 'correct': False, 'penalty': penalty_config['penalty_time'],
                          'penalty_type': 'eject', 'message': f"Wrong! {penalty_config['penalty_time']}s penalty. Ejected!",
                          'hard_path_locked': True, 'current_player': 1})

@app.route('/api/session/<team_name>/status', methods=['GET'])
def get_status(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    return jsonify(session.to_dict())

@app.route('/api/sessions', methods=['GET'])
def get_all_sessions():
    return jsonify({'sessions': [session.to_dict() for session in game_sessions.values()]})

@app.route('/api/session/<team_name>/end', methods=['POST'])
def end_game(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    session.end_time = datetime.now()
    session.state_version += 1
    return jsonify({'success': True, 'total_time': session.get_total_time()})

@app.route('/api/leaderboard', methods=['GET'])
def get_leaderboard():
    completed = [s for s in game_sessions.values() if s.end_time]
    leaderboard = sorted(completed, key=lambda s: s.get_total_time())
    return jsonify({'leaderboard': [{'rank': idx + 1, 'team_name': s.team_name,
                   'total_time': s.get_total_time(), 'path': s.current_path,
                   'penalties': s.total_penalties, 'players': f"{s.player1} & {s.player2}"}
                   for idx, s in enumerate(leaderboard)]})

if __name__ == '__main__':
    print("🎮 Linux Maze Game Server Starting...")
    print("=" * 50)
    print("Admin Dashboard: http://localhost:5000")
    print("API Endpoint: http://localhost:5000/api")
    print("=" * 50)
    app.run(debug=True, host='0.0.0.0', port=5000)