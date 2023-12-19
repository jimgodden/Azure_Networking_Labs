# python script_name.py --account-name your_storage_account_name --account-key your_storage_account_key_or_sas_token --container-name your_container_name --local-file-path path/to/your/local/file.txt --blob-name your_blob_name

import argparse
from azure.storage.blob import BlobServiceClient, ContainerClient

def upload_blob(storage_account_name, storage_account_key, container_name, local_file_path, blob_name):
    # Create a BlobServiceClient using the storage account name and key
    blob_service_client = BlobServiceClient(
        account_url=f"https://{storage_account_name}.blob.core.windows.net",
        credential=storage_account_key
    )

    # Get a ContainerClient for the specified container
    container_client = blob_service_client.get_container_client(container_name)

    # Upload the file
    with open(local_file_path, "rb") as data:
        container_client.upload_blob(name=blob_name, data=data)

    print(f"Uploaded file: {local_file_path} to blob: {blob_name} in container: {container_name}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload a file to Azure Storage Container.")
    parser.add_argument("--account-name", required=True, help="Azure Storage Account Name")
    parser.add_argument("--account-key", required=True, help="Azure Storage Account Key or SAS Token")
    parser.add_argument("--container-name", required=True, help="Azure Storage Container Name")
    parser.add_argument("--local-file-path", required=True, help="Path to the local file to upload")
    parser.add_argument("--blob-name", required=True, help="Name to give to the uploaded blob")

    args = parser.parse_args()

    upload_blob(
        storage_account_name=args.account_name,
        storage_account_key=args.account_key,
        container_name=args.container_name,
        local_file_path=args.local_file_path,
        blob_name=args.blob_name
    )


