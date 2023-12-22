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
    # Replace these values with your Azure Storage account information
    account_name = "your_storage_account_name"
    account_key = "your_storage_account_key_or_sas_token"
    container_name = "your_container_name"

    delete_all_blobs(
        storage_account_name=account_name,
        storage_account_key=account_key,
        container_name=container_name
    )
    