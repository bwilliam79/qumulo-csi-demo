#!/bin/sh

# Author: Brandon Williams <bwilliams@qumulo.com>
# This script will remove the directory and quota created by the qumulo-csi-demo-setup.sh script and delete the minikube instance it deployed
# If the script completes successfully, you should no longer see a quota in the Qumulo UI or a directory within the volumes directory of the NFS export

# Change these variables to match your envioronment.
# You will need to manually create the NFS export in Qumulo prior to running this script.
cluster_address="192.168.0.190"
rest_port="8000"
username="admin" # This user must have permissions to create directories on the Qumulo filesystem and connect to the API
password="Admin123"
nfs_export="/k8s" # Keep this off the root of the filesystem for simplicity. Script mostly likely won't work otherwise.

# This variable should be left alone for now
path="./csi-driver-qumulo/deploy/"

# Print some info about the environment variables
echo "Qumulo cluster address: $cluster_address"
echo "Rest port: $rest_port"
echo "Qumulo username: $username"
echo "NFS Export: $nfs_export\n"

echo "Removing PVC and quota from Qumulo filesystem...\n"

kubectl delete -f ./mysql-deployment.yaml
kubectl delete -f ./mysql-pvc-qumulo.yaml
#kubectl delete -f $path/example/dynamic-pvc.yaml
kubectl delete -f $path/example/storageclass-qumulo.yaml

echo "\nDeleting minikube instance..."
minikube delete

# Delete the NFS export and directory structure on Qumulo filesystem
echo "\nDeleting NFS export on Qumulo..."
bearer_token=`curl -sk "https://$cluster_address:$rest_port/v1/session/login" -H "Content-Type: application/json" --data "{\"username\":\"$username\",\"password\":\"$password\"}"  | cut -f4 -d '"'`
curl -ks -X DELETE "https://$cluster_address:$rest_port/v1/files/%2F${nfs_export:1}%2Fvolumes" -H "Authorization: Bearer $bearer_token" 2>&1 > /dev/null
curl -ks -X DELETE "https://$cluster_address:$rest_port/v1/files/%2F${nfs_export:1}" -H "Authorization: Bearer $bearer_token" 2>&1 > /dev/null
curl -ks -X DELETE "https://$cluster_address:$rest_port/v2/nfs/exports/%2F${nfs_export:1}" -H "Authorization: Bearer $bearer_token" 2>&1 > /dev/null

echo "\nDone."