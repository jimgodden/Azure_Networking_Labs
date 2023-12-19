# python script_name.py --account-name your_storage_account_name --account-key your_storage_account_key_or_sas_token --container-name your_container_name --local-path your_local_path


from azure.storage.blob import BlobServiceClient, ContainerClient

storage_account_name = "mainjamesgstorage"
storage_account_key = ""
container_name = "test"
local_path = "c:\\temp"

blob_service_client = BlobServiceClient(
    account_url=f"https://{storage_account_name}.blob.core.windows.net",
    credential=storage_account_key
)

# Get a ContainerClient for the specified container
container_client = blob_service_client.get_container_client(container_name)

# List all blobs in the container
blobs = container_client.list_blobs()

# Download each blob
for blob in blobs:
    blob_name = blob.name
    blob_client = container_client.get_blob_client(blob_name)

    # Construct the local path for the downloaded file
    local_file_path = f"{local_path}\{blob_name}"

    with open(local_file_path, "wb") as file:
        data = blob_client.download_blob().readall()
        file.write(data)

    print(f"Downloaded blob: {blob_name} to {local_file_path}")
