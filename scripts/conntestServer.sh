hname=$(hostname)

curl -o /tmp/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x /tmp/conntest
curl -o /tmp/fsconn.sh https://mainjamesgstorage.blob.core.windows.net/scripts/fsconn.sh
chmod +x /tmp/fsconn.sh
/tmp/fsconn.sh

mkdir /mnt/mainfileshare/$1
chmod 600 /mnt/mainfile/$1

nohup tcpdump -w /mnt/mainfileshare/$1/$hname-trace-%m-%d-%H-%M-%S.pcap port 5001 -G 3800 -C 500M -s 120 -K -n &

nohup /tmp/conntest -s -p 5001 &
