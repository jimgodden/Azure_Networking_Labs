import os
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient

storage_account_name = "mainjamesgstorage"
storage_account_key = ""
container_name = "test"
local_folder_path = "c:\\temp"

# Create a BlobServiceClient using the storage account name and key
blob_service_client = BlobServiceClient(
    account_url=f"https://{storage_account_name}.blob.core.windows.net",
    credential=storage_account_key
)

# Get a ContainerClient for the specified container
container_client = blob_service_client.get_container_client(container_name)

# List all files in the local folder
local_files = []
for file_name in os.listdir(local_folder_path):
    if os.path.isfile(os.path.join(local_folder_path, file_name)):
        local_files.append(file_name)


# Upload each file to the container
for local_file in local_files:
    local_file_path = os.path.join(local_folder_path, local_file)
    blob_client = container_client.get_blob_client(local_file)

    with open(local_file_path, "rb") as data:
        blob_client.upload_blob(data)

    print(f"Uploaded file: {local_file} to blob: {local_file} in container: {container_name}")


