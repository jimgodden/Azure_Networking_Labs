hname=$(hostname)

curl -o /tmp/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x /tmp/conntest
curl -o /tmp/fsconn.sh https://mainjamesgstorage.blob.core.windows.net/scripts/fsconn.sh
chmod +x /tmp/fsconn.sh
/tmp/fsconn.sh

mkdir /mnt/mainfileshare/$2
chmod 600 /mnt/mainfile/$2

nohup tcpdump -w /mnt/mainfileshare/$2/$hname-trace-%m-%d-%H-%M-%S.pcap host $1 -G 3800 -C 500M -s 120 -K -n &

nohup /tmp/conntest -c $1 -p 5001 &
