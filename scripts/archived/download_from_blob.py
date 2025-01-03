# python script_name.py --account-name your_storage_account_name --account-key your_storage_account_key_or_sas_token --container-name your_container_name --local-path your_local_path


import argparse
from azure.storage.blob import BlobServiceClient, ContainerClient

def download_blobs(storage_account_name, storage_account_key, container_name, local_path):
    # Create a BlobServiceClient using the storage account name and key
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
        local_file_path = f"{local_path}/{blob_name}"

        with open(local_file_path, "wb") as file:
            data = blob_client.download_blob().readall()
            file.write(data)

        print(f"Downloaded blob: {blob_name} to {local_file_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download blobs from Azure Storage Container.")
    parser.add_argument("--account-name", required=True, help="Azure Storage Account Name")
    parser.add_argument("--account-key", required=True, help="Azure Storage Account Key or SAS Token")
    parser.add_argument("--container-name", required=True, help="Azure Storage Container Name")
    parser.add_argument("--local-path", required=True, help="Local path to save downloaded files")

    args = parser.parse_args()

    download_blobs(
        storage_account_name=args.account_name,
        storage_account_key=args.account_key,
        container_name=args.container_name,
        local_path=args.local_path
    )


