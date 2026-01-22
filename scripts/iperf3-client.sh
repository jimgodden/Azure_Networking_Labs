#!/bin/bash
#
# iperf3-client.sh
# Runs iperf3 in client mode to send maximum TCP traffic to a server
#
# Usage: ./iperf3-client.sh <server-ip> [duration] [parallel-streams] [port]
#
# Examples:
#   ./iperf3-client.sh 10.1.0.4              # 60 second test, 8 streams
#   ./iperf3-client.sh 10.1.0.4 120          # 2 minute test
#   ./iperf3-client.sh 10.1.0.4 0            # Infinite duration (Ctrl+C to stop)
#   ./iperf3-client.sh 10.1.0.4 60 16        # 16 parallel streams
#   ./iperf3-client.sh 10.1.0.4 60 8 5201    # Custom port
#

SERVER_IP=$1
DURATION=${2:-60}
PARALLEL=${3:-8}
PORT=${4:-5201}

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server-ip> [duration-seconds] [parallel-streams] [port]"
    echo ""
    echo "Duration: Use 0 for infinite (Ctrl+C to stop)"
    echo ""
    echo "Examples:"
    echo "  $0 10.1.0.4              # 60 second test, 8 streams"
    echo "  $0 10.1.0.4 120          # 2 minute test"
    echo "  $0 10.1.0.4 0            # Infinite duration"
    echo "  $0 10.1.0.4 60 16        # 16 parallel streams"
    exit 1
fi

# Install iperf3 if not present
if ! command -v iperf3 &> /dev/null; then
    echo "Installing iperf3..."
    sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3
fi

# Wait 5 minutes to ensure server is ready
echo "Waiting 5 minutes for server to be ready..."
sleep 300

# Set duration display text
if [ "$DURATION" -eq 0 ]; then
    DURATION_DISPLAY="Infinite (Ctrl+C to stop)"
else
    DURATION_DISPLAY="$DURATION seconds"
fi

echo "=============================================="
echo "iperf3 TCP Throughput Test"
echo "=============================================="
echo "Server:           $SERVER_IP:$PORT"
echo "Duration:         $DURATION_DISPLAY"
echo "Parallel Streams: $PARALLEL"
echo "=============================================="
echo ""

# Run iperf3 client for maximum throughput
# -c : client mode, connect to server
# -p : port
# -t : duration in seconds
# -P : number of parallel streams (increases throughput)
# -i 1 : report interval of 1 second
# -w 256K : window size (TCP buffer) for high throughput
# --get-server-output : also show server-side results

if [ "$DURATION" -eq 0 ]; then
    # Infinite mode - loop forever until Ctrl+C
    echo "Running in infinite mode. Press Ctrl+C to stop."
    echo ""
    while true; do
        iperf3 -c $SERVER_IP -p $PORT -t 60 -P $PARALLEL -i 1 -w 256K
        echo ""
        echo "Restarting test..."
        echo ""
    done
else
    iperf3 -c $SERVER_IP -p $PORT -t $DURATION -P $PARALLEL -i 1 -w 256K --get-server-output
fi

echo ""
echo "Test complete!"
