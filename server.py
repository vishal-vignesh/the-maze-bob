from flask import Flask, request, jsonify, render_template_string
from datetime import datetime
import json

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
        self.state_version = 0  # For polling/auto-sync
        
    def increment_version(self):
        """Increment state version for change tracking"""
        self.state_version += 1
        
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
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LINUX MAZE GAME // CONTROL TERMINAL</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Share Tech Mono', monospace;
            background: #0a0e27;
            color: #00ff41;
            min-height: 100vh;
            padding: 20px;
            position: relative;
            overflow-x: hidden;
        }

        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: 
                repeating-linear-gradient(0deg, rgba(0, 255, 65, 0.03) 0px, transparent 1px, transparent 2px, rgba(0, 255, 65, 0.03) 3px),
                repeating-linear-gradient(90deg, rgba(0, 255, 65, 0.03) 0px, transparent 1px, transparent 2px, rgba(0, 255, 65, 0.03) 3px);
            pointer-events: none;
            z-index: 1;
        }

        .scanline {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(to bottom, transparent 50%, rgba(0, 255, 65, 0.02) 51%);
            background-size: 100% 4px;
            pointer-events: none;
            animation: scanline 8s linear infinite;
            z-index: 2;
        }

        @keyframes scanline {
            0% { transform: translateY(0); }
            100% { transform: translateY(100%); }
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            position: relative;
            z-index: 3;
        }

        header {
            background: rgba(10, 14, 39, 0.8);
            border: 2px solid #00ff41;
            padding: 30px;
            margin-bottom: 30px;
            position: relative;
            box-shadow: 0 0 20px rgba(0, 255, 65, 0.3), inset 0 0 20px rgba(0, 255, 65, 0.1);
            clip-path: polygon(0 0, calc(100% - 20px) 0, 100% 20px, 100% 100%, 0 100%);
        }

        header::before {
            content: '█';
            position: absolute;
            top: 10px;
            right: 10px;
            color: #00ff41;
            animation: blink 1s infinite;
        }

        @keyframes blink {
            0%, 49% { opacity: 1; }
            50%, 100% { opacity: 0; }
        }

        h1 {
            font-size: 2.5em;
            color: #00ff41;
            text-shadow: 0 0 10px #00ff41, 0 0 20px #00ff41;
            letter-spacing: 3px;
            margin-bottom: 10px;
            text-transform: uppercase;
        }

        .subtitle {
            color: #00ff41;
            opacity: 0.7;
            font-size: 0.9em;
            letter-spacing: 2px;
        }

        .subtitle::before {
            content: '> ';
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-card {
            background: rgba(10, 14, 39, 0.8);
            border: 2px solid #00ff41;
            padding: 25px;
            position: relative;
            box-shadow: 0 0 15px rgba(0, 255, 65, 0.2), inset 0 0 15px rgba(0, 255, 65, 0.05);
            transition: all 0.3s ease;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: -2px;
            left: -2px;
            right: -2px;
            bottom: -2px;
            background: linear-gradient(45deg, #00ff41, transparent, #00ff41);
            z-index: -1;
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .stat-card:hover::before {
            opacity: 0.3;
        }

        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 25px rgba(0, 255, 65, 0.4), inset 0 0 25px rgba(0, 255, 65, 0.1);
        }

        .stat-value {
            font-size: 3em;
            font-weight: bold;
            color: #00ff41;
            text-shadow: 0 0 10px #00ff41;
            margin-bottom: 10px;
            font-family: 'Share Tech Mono', monospace;
        }

        .stat-label {
            color: #00ff41;
            font-size: 0.8em;
            text-transform: uppercase;
            letter-spacing: 2px;
            opacity: 0.7;
        }

        .stat-label::before {
            content: '[ ';
        }

        .stat-label::after {
            content: ' ]';
        }

        .create-section, .sessions-section {
            background: rgba(10, 14, 39, 0.8);
            border: 2px solid #00ff41;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 0 20px rgba(0, 255, 65, 0.2), inset 0 0 20px rgba(0, 255, 65, 0.05);
            clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 0 100%);
        }

        h2 {
            color: #00ff41;
            margin-bottom: 20px;
            font-size: 1.5em;
            text-transform: uppercase;
            letter-spacing: 2px;
            text-shadow: 0 0 10px #00ff41;
        }

        h2::before {
            content: '>> ';
        }

        .form-group {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }

        input {
            padding: 15px;
            background: rgba(0, 0, 0, 0.5);
            border: 2px solid #00ff41;
            color: #00ff41;
            font-size: 1em;
            font-family: 'Share Tech Mono', monospace;
            transition: all 0.3s ease;
        }

        input:focus {
            outline: none;
            box-shadow: 0 0 15px rgba(0, 255, 65, 0.5), inset 0 0 10px rgba(0, 255, 65, 0.1);
            background: rgba(0, 0, 0, 0.7);
        }

        input::placeholder {
            color: #00ff41;
            opacity: 0.5;
        }

        .btn {
            background: rgba(0, 0, 0, 0.5);
            color: #00ff41;
            border: 2px solid #00ff41;
            padding: 15px 40px;
            font-size: 1em;
            font-weight: bold;
            cursor: pointer;
            font-family: 'Share Tech Mono', monospace;
            text-transform: uppercase;
            letter-spacing: 2px;
            position: relative;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: rgba(0, 255, 65, 0.2);
            transition: left 0.3s ease;
        }

        .btn:hover::before {
            left: 0;
        }

        .btn:hover {
            box-shadow: 0 0 20px rgba(0, 255, 65, 0.5);
            transform: translateY(-2px);
        }

        .btn-danger {
            border-color: #ff0040;
            color: #ff0040;
        }

        .btn-danger:hover {
            box-shadow: 0 0 20px rgba(255, 0, 64, 0.5);
        }

        .controls {
            display: flex;
            gap: 10px;
            margin-top: 20px;
            flex-wrap: wrap;
        }

        .btn-small {
            padding: 10px 20px;
            font-size: 0.85em;
        }

        .session-card {
            background: rgba(0, 0, 0, 0.5);
            border: 1px solid #00ff41;
            border-left: 4px solid #00ff41;
            padding: 25px;
            margin-bottom: 15px;
            position: relative;
            transition: all 0.3s ease;
            animation: fadeIn 0.5s ease;
        }

        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateX(-20px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }

        .session-card:hover {
            border-left-width: 8px;
            box-shadow: 0 0 20px rgba(0, 255, 65, 0.3);
            transform: translateX(5px);
        }

        .session-card.completed {
            border-left-color: #00d4ff;
            border-color: #00d4ff;
        }

        .session-card.completed:hover {
            box-shadow: 0 0 20px rgba(0, 212, 255, 0.3);
        }

        .session-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }

        .team-name {
            font-size: 1.5em;
            font-weight: bold;
            color: #00ff41;
            text-shadow: 0 0 10px #00ff41;
            text-transform: uppercase;
            letter-spacing: 2px;
        }

        .status-badge {
            padding: 8px 20px;
            border: 2px solid #00ff41;
            font-size: 0.8em;
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 1px;
            background: rgba(0, 255, 65, 0.1);
            box-shadow: 0 0 10px rgba(0, 255, 65, 0.3);
        }

        .status-badge.completed {
            border-color: #00d4ff;
            color: #00d4ff;
            background: rgba(0, 212, 255, 0.1);
            box-shadow: 0 0 10px rgba(0, 212, 255, 0.3);
        }

        .session-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

        .info-item {
            display: flex;
            align-items: center;
            gap: 10px;
            color: #00ff41;
            font-size: 0.9em;
        }

        .info-icon {
            font-size: 1.2em;
        }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: rgba(0, 255, 65, 0.1);
            border: 1px solid #00ff41;
            margin-top: 15px;
            overflow: hidden;
            position: relative;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #00ff41, #00d4ff);
            box-shadow: 0 0 10px #00ff41;
            transition: width 0.5s ease;
            position: relative;
        }

        .progress-fill::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
            animation: shimmer 2s infinite;
        }

        @keyframes shimmer {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(100%); }
        }

        .penalty {
            color: #ff0040;
            font-weight: bold;
            text-shadow: 0 0 5px #ff0040;
        }

        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #00ff41;
            opacity: 0.5;
        }

        .empty-state-icon {
            font-size: 4em;
            margin-bottom: 20px;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 0.5; transform: scale(1); }
            50% { opacity: 1; transform: scale(1.05); }
        }

        .glitch {
            position: relative;
        }

        .glitch::before,
        .glitch::after {
            content: attr(data-text);
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
        }

        .glitch::before {
            left: 2px;
            text-shadow: -2px 0 #ff0040;
            clip: rect(44px, 450px, 56px, 0);
            animation: glitch-anim 5s infinite linear alternate-reverse;
        }

        .glitch::after {
            left: -2px;
            text-shadow: -2px 0 #00d4ff;
            clip: rect(44px, 450px, 56px, 0);
            animation: glitch-anim 5s infinite linear alternate-reverse;
            animation-delay: 0.5s;
        }

        @keyframes glitch-anim {
            0% { clip: rect(10px, 9999px, 31px, 0); }
            20% { clip: rect(85px, 9999px, 140px, 0); }
            40% { clip: rect(65px, 9999px, 70px, 0); }
            60% { clip: rect(20px, 9999px, 105px, 0); }
            80% { clip: rect(40px, 9999px, 90px, 0); }
            100% { clip: rect(60px, 9999px, 130px, 0); }
        }
    </style>
</head>
<body>
    <div class="scanline"></div>
    <div class="container">
        <header>
            <h1 class="glitch" data-text="LINUX MAZE GAME">LINUX MAZE GAME</h1>
            <p class="subtitle">ADMIN CONTROL TERMINAL v3.0 [AUTO-SYNC ENABLED]</p>
        </header>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value" id="active-count">0</div>
                <div class="stat-label">Active Sessions</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="completed-count">0</div>
                <div class="stat-label">Completed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="total-penalties">0s</div>
                <div class="stat-label">Total Penalties</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="avg-time">0s</div>
                <div class="stat-label">Avg Completion</div>
            </div>
        </div>

        <div class="create-section">
            <h2>Create New Session</h2>
            <div class="form-group">
                <input type="text" id="team-name" placeholder="TEAM_NAME" />
                <input type="text" id="player1" placeholder="PLAYER_01" />
                <input type="text" id="player2" placeholder="PLAYER_02" />
            </div>
            <div class="controls">
                <button class="btn" onclick="createSession()">Initialize Session</button>
                <button class="btn btn-danger btn-small" onclick="clearAllSessions()">Purge All</button>
            </div>
        </div>

        <div class="sessions-section">
            <h2>Active Sessions</h2>
            <div id="sessions"></div>
        </div>
    </div>

    <script>
        async function loadSessions() {
            try {
                const res = await fetch('/api/sessions');
                const data = await res.json();
                const active = data.sessions.filter(s => !s.end_time);
                const completed = data.sessions.filter(s => s.end_time);
                const totalPenalties = data.sessions.reduce((sum, s) => sum + s.total_penalties, 0);
                const avgTime = completed.length > 0 ? (completed.reduce((sum, s) => sum + s.total_time, 0) / completed.length).toFixed(1) : 0;
                
                document.getElementById('active-count').textContent = active.length;
                document.getElementById('completed-count').textContent = completed.length;
                document.getElementById('total-penalties').textContent = totalPenalties + 's';
                document.getElementById('avg-time').textContent = avgTime + 's';
                
                const sessionsDiv = document.getElementById('sessions');
                
                if (data.sessions.length === 0) {
                    sessionsDiv.innerHTML = `<div class="empty-state"><div class="empty-state-icon">[NO_DATA]</div><p>>> AWAITING SESSION INITIALIZATION</p></div>`;
                    return;
                }
                
                sessionsDiv.innerHTML = data.sessions.map(s => {
                    const completed = s.end_time !== null;
                    const pathEmoji = s.current_path === 'easy' ? '[EASY]' : s.current_path === 'medium' ? '[MEDIUM]' : s.current_path === 'hard' ? '[HARD]' : '[STANDBY]';
                    const totalQuestions = s.current_path === 'easy' ? 10 : s.current_path === 'medium' ? 6 : s.current_path === 'hard' ? 4 : 0;
                    const progress = totalQuestions > 0 ? (s.current_question / totalQuestions * 100) : 0;
                    
                    return `<div class="session-card ${completed ? 'completed' : ''}">
                        <div class="session-header">
                            <div class="team-name">${s.team_name}</div>
                            <div class="status-badge ${completed ? 'completed' : 'active'}">${completed ? '[COMPLETE]' : '[ACTIVE]'}</div>
                        </div>
                        <div class="session-info">
                            <div class="info-item"><span class="info-icon">></span><span class="info-text">TEAM: ${s.player1} & ${s.player2}</span></div>
                            <div class="info-item"><span class="info-icon">></span><span class="info-text">PATH: ${pathEmoji}</span></div>
                            <div class="info-item"><span class="info-icon">></span><span class="info-text">Q${s.current_question + 1} | P${s.current_player}</span></div>
                            <div class="info-item"><span class="info-icon">></span><span class="info-text">TIME: ${s.total_time.toFixed(1)}s</span></div>
                            <div class="info-item"><span class="info-icon">></span><span class="info-text penalty">PENALTIES: ${s.total_penalties}s</span></div>
                        </div>
                        ${s.current_path ? `<div class="progress-bar"><div class="progress-fill" style="width: ${progress}%"></div></div>` : ''}
                    </div>`;
                }).join('');
            } catch (error) {
                console.error('ERROR:', error);
            }
        }
        
        async function createSession() {
            const team = document.getElementById('team-name').value;
            const p1 = document.getElementById('player1').value;
            const p2 = document.getElementById('player2').value;
            
            if (!team || !p1 || !p2) {
                alert('[ERROR] ALL FIELDS REQUIRED');
                return;
            }
            
            try {
                const res = await fetch('/api/session/create', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({team_name: team, player1: p1, player2: p2})
                });
                const data = await res.json();
                
                if (data.success) {
                    document.getElementById('team-name').value = '';
                    document.getElementById('player1').value = '';
                    document.getElementById('player2').value = '';
                    loadSessions();
                } else {
                    alert('[ERROR] ' + (data.error || 'FAILED TO CREATE SESSION'));
                }
            } catch (error) {
                alert('[ERROR] ' + error.message);
            }
        }
        
        async function clearAllSessions() {
            if (!confirm('[WARNING] PURGE ALL SESSIONS? THIS CANNOT BE UNDONE.')) return;
            
            try {
                await fetch('/api/sessions/clear', {method: 'POST'});
                loadSessions();
            } catch (error) {
                alert('[ERROR] ' + error.message);
            }
        }
        
        setInterval(loadSessions, 2000);
        loadSessions();
    </script>
</body>
</html>'''

@app.route('/api/session/create', methods=['POST'])
def create_session():
    data = request.json
    team_name = data.get('team_name')
    player1 = data.get('player1')
    player2 = data.get('player2')
    if not all([team_name, player1, player2]):
        return jsonify({'error': 'Missing required fields'}), 400
    if team_name in game_sessions:
        return jsonify({'success': True, 'team_name': team_name, 'already_exists': True, 
                       'message': 'Session already exists'})
    session = GameSession(team_name, player1, player2)
    game_sessions[team_name] = session
    return jsonify({'success': True, 'team_name': team_name, 'message': 'Session created'})

@app.route('/api/session/<team_name>/start', methods=['POST'])
def start_game(team_name):
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    if session.start_time:
        return jsonify({'error': 'Game already started'})
    session.start_time = datetime.now()
    session.increment_version()
    session.events.append({'type': 'game_start', 'timestamp': session.start_time.isoformat()})
    return jsonify({'success': True, 'start_time': session.start_time.isoformat()})

@app.route('/api/session/<team_name>/current_question', methods=['GET'])
def get_current_question(team_name):
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

# CRITICAL: Auto-sync polling endpoint
@app.route('/api/session/<team_name>/poll', methods=['GET'])
def poll_session(team_name):
    """Polling endpoint for auto-sync - checks for state changes"""
    session = game_sessions.get(team_name)
    if not session:
        return jsonify({'error': 'Session not found'}), 404
    
    client_version = int(request.args.get('version', 0))
    player_num = int(request.args.get('player', 1))
    
    # Check if there are changes since client's version
    has_changes = session.state_version > client_version
    
    # Determine if it's this player's turn
    is_your_turn = (session.current_player == player_num and 
                    session.start_time and not session.end_time)
    
    # Build response
    response_data = {
        'has_changes': has_changes,
        'state_version': session.state_version,
        'game_started': session.start_time is not None,
        'game_complete': session.end_time is not None,
        'current_path': session.current_path,
        'current_player': session.current_player,
        'current_question': session.current_question,
        'is_your_turn': is_your_turn,
        'total_penalties': session.total_penalties
    }
    
    # Include current question if game is active
    if session.current_path and not session.end_time:
        path = session.current_path
        question_idx = session.current_question
        if question_idx < len(QUESTIONS[path]):
            q = QUESTIONS[path][question_idx]
            response_data['question'] = {
                'text': q['question'],
                'options': list(q['options'].keys()),
                'number': question_idx + 1,
                'total': len(QUESTIONS[path])
            }
    
    # Include completion data if game is done
    if session.end_time:
        response_data['total_time'] = session.get_total_time()
    
    return jsonify(response_data)

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
    session.increment_version()
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
    session.increment_version()
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
            session.increment_version()  # FIX: Increment version so reset syncs
            return jsonify({'success': False, 'correct': False, 'penalty': penalty_config['penalty_time'],
                          'penalty_type': 'reset_path', 'message': f"Wrong! {penalty_config['penalty_time']}s penalty. Reset!",
                          'reset_to_question': QUESTIONS[path][0], 'current_player': 1})
        elif path == 'hard':
            session.total_penalties += penalty_config['penalty_time']
            session.current_path = None
            session.current_question = 0
            session.hard_path_locked = True
            session.current_player = 1
            session.increment_version()  # FIX: Increment version so ejection syncs
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

@app.route('/api/sessions/clear', methods=['POST'])
def clear_sessions():
    global game_sessions
    game_sessions = {}
    return jsonify({'success': True, 'message': 'All sessions cleared'})

@app.route('/api/session/<team_name>/delete', methods=['DELETE'])
def delete_session(team_name):
    if team_name in game_sessions:
        del game_sessions[team_name]
        return jsonify({'success': True, 'message': f'Session {team_name} deleted'})
    return jsonify({'error': 'Session not found'}), 404

@app.route('/api/leaderboard', methods=['GET'])
def get_leaderboard():
    completed = [s for s in game_sessions.values() if s.end_time]
    leaderboard = sorted(completed, key=lambda s: s.get_total_time())
    return jsonify({'leaderboard': [{'rank': idx + 1, 'team_name': s.team_name,
                   'total_time': s.get_total_time(), 'path': s.current_path,
                   'penalties': s.total_penalties, 'players': f"{s.player1} & {s.player2}"}
                   for idx, s in enumerate(leaderboard)]})

if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5000))
    print("🎮 Linux Maze Game Server Starting...")
    print("=" * 50)
    print(f"Server running on port {port}")
    print("✨ Auto-Sync Enabled: Clients poll every 2s")
    print("=" * 50)
    app.run(debug=False, host='0.0.0.0', port=port)