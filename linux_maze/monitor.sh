#!/bin/bash

# Monitor script to watch all teams in real-time

SERVER_URL="http://localhost:5000"

watch -n 1 "curl -s ${SERVER_URL}/api/sessions | python3 -m json.tool"
