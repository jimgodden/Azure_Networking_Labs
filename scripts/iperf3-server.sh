#!/bin/bash
#
# iperf3-server.sh
# Runs iperf3 in server mode to receive traffic from clients
# Server runs infinitely until stopped with Ctrl+C
#
# Usage: ./iperf3-server.sh [port]
#

PORT=${1:-5201}

# Install iperf3 if not present
if ! command -v iperf3 &> /dev/null; then
    echo "Installing iperf3..."
    sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3
fi

# Open firewall port if ufw is active
if sudo ufw status | grep -q "active"; then
    echo "Opening port $PORT in firewall..."
    sudo ufw allow $PORT/tcp
fi

echo "Starting iperf3 server on port $PORT..."
echo "Press Ctrl+C to stop"
echo ""

# Run iperf3 server
# -s : server mode
# -p : port
# -i 1 : report interval of 1 second
iperf3 -s -p $PORT -i 1
