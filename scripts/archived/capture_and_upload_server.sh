#!/bin/bash

port=$1
storage_account_name=$2
storage_account_key=$3
container_name=$4
local_folder_path=$5

hostname=$(hostname)

while true; do
    # Capture the current date and time
    timestamp=$(date +"%Y%m%d_%H-%M-%S")

    # Define the output file name using hostname and timestamp
    output_file="${hostname}_${timestamp}.pcap"
    output_file_path="${local_folder_path}/${output_file}"

    # Run tcpdump for 30 minutes and save the capture to the output file
    sudo tcpdump -w $output_file_path port $port -s 120 -K -n &

    # Capture the PID of the tcpdump process
    tcpdump_pid=$!

    # Sleep for 10 minutes
    sleep 600

    # Stop tcpdump
    kill $tcpdump_pid

    # Run the upload.py script with the output file as an argument
    python3 $local_folder_path/upload_to_blob.py --account-name $storage_account_name --account-key $storage_account_key --container-name $container_name --local-file-path $output_file_path  --blob-name $output_file
    
    # Sleep for a while before starting the next iteration
    sleep 1
done
