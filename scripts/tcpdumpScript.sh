sudo tcpdump -w "/tmp/$(hostname)_packetcapture-" -B 10 -C 3 -s 100 -K -n -W 5 &

echo "the script has finished" > /tmp/scripthasbeen completed.txt