import argparse
from azure.storage.blob import BlobServiceClient

def delete_all_blobs(storage_account_name, storage_account_key, container_name):
    # Create a BlobServiceClient using the storage account name and key
    blob_service_client = BlobServiceClient(
        account_url=f"https://{storage_account_name}.blob.core.windows.net",
        credential=storage_account_key
    )

    # Get a ContainerClient for the specified container
    container_client = blob_service_client.get_container_client(container_name)

    # List all blobs in the container
    blobs = container_client.list_blobs()

    # Delete each blob
    for blob in blobs:
        blob_client = container_client.get_blob_client(blob.name)
        blob_client.delete_blob()

        print(f"Deleted blob: {blob.name} from container: {container_name}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download blobs from Azure Storage Container.")
    parser.add_argument("--account-name", required=True, help="Azure Storage Account Name")
    parser.add_argument("--account-key", required=True, help="Azure Storage Account Key or SAS Token")
    parser.add_argument("--container-name", required=True, help="Azure Storage Container Name")

    args = parser.parse_args()

    delete_all_blobs(
        storage_account_name=args.account_name,
        storage_account_key=args.account_key,
        container_name=args.container_name
    )
