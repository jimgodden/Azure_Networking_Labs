#!/bin/bash

destinationIPAddress=$1
storage_account_name=$2
storage_account_key=$3
container_name=$4
local_folder_path=$5

hname=$(hostname)

mkdir $local_folder_path

curl -o $local_folder_path/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x $local_folder_path/conntest

curl -o $local_folder_path/capture_and_upload.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/capture_and_upload.sh
chmod +x $local_folder_path/capture_and_upload.sh

curl -o $local_folder_path/upload_to_blob.py https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/upload_to_blob.py
chmod +x $local_folder_path/upload_to_blob.py

sudo apt-get update -y
sudo apt-get install python3-pip -y
pip install azure-storage-blob

nohup $local_folder_path/capture_and_upload.sh $destinationIPAddress $storage_account_name $storage_account_key $container_name $local_folder_path &

nohup $local_folder_path/conntest -c $1 -p 5001 &
