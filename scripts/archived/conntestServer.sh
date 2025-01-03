#!/bin/bash

storage_account_name=$1
storage_account_key=$2
container_name=$3
local_folder_path=$4

hname=$(hostname)

mkdir $local_folder_path

curl -o $local_folder_path/conntest https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/conntest
chmod +x $local_folder_path/conntest

curl -o $local_folder_path/capture_and_upload_server.sh https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/capture_and_upload_server.sh
chmod +x $local_folder_path/capture_and_upload_server.sh

curl -o $local_folder_path/upload_to_blob.py https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/upload_to_blob.py
chmod +x $local_folder_path/upload_to_blob.py

sudo apt-get update -y
sudo apt-get install python3-pip -y
pip install azure-storage-blob

nohup $local_folder_path/capture_and_upload_server.sh 5001 $storage_account_name $storage_account_key $container_name $local_folder_path &

nohup $local_folder_path/conntest -s -p 5001 &
