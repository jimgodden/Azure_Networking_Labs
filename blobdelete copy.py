from azure.storage.blob import BlobServiceClient

storage_account_name = "mainjamesgstorage"
storage_account_key = ""
container_name = "test"

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


