#!/bin/sh

# Author: Brandon Williams <bwilliams@qumulo.com>

# Change these variables to match your envioronment.
cluster_address="192.168.0.190"
rest_port="8000"
username="admin" # This user must have permissions to create directories on the Qumulo filesystem and connect to the API
password="Admin123"
nfs_export="/k8s" # Keep this off the root of the filesystem for simplicity. Script mostly likely won't work otherwise.

printf "\033[33;33m******************************************************************************************\n"
printf "**** WARNING: THIS SCIPT WILL DELETE THE $nfs_export DIRECTORY FROM YOUR QUMULO FILESYSTEM!!! ****\n"
printf "******************************************************************************************\033[33;37m\n"
read -p "Type \"DELETE\" to continue: " confirm && [[ $confirm == "DELETE" ]] || exit 1

# This variable should be left alone for now
path="./csi-driver-qumulo/deploy/"

# Print some info about the environment variables
printf "Qumulo cluster address: $cluster_address\n"
printf "Rest port: $rest_port\n"
printf "Qumulo username: $username\n"
printf "NFS Export: $nfs_export\n\n"

printf "Removing PVCs and quotas from Qumulo filesystem...\n\n"

kubectl delete -f ./yaml/mysql-deployment.yaml
kubectl delete -f ./yaml/mysql-pvc-qumulo.yaml
kubectl delete -f ./yaml/nginx-deployment.yaml
kubectl delete -f ./yaml/nginx-pvc-qumulo.yaml
#kubectl delete -f $path/example/dynamic-pvc.yaml
kubectl delete -f $path/example/storageclass-qumulo.yaml

printf "\nDeleting minikube instance...\n"
minikube delete

# Delete the NFS export and directory structure on Qumulo filesystem
printf "\nDeleting NFS export on Qumulo...\n"
bearer_token=`curl -sk "https://$cluster_address:$rest_port/v1/session/login" -H "Content-Type: application/json" --data "{\"username\":\"$username\",\"password\":\"$password\"}"  | cut -f4 -d '"'`
tree_id=`curl -ks -X GET "https://$cluster_address:$rest_port/v1/files/%2F${nfs_export:1}/info/attributes" -H "Authorization: Bearer $bearer_token" | grep -Eo '"id": .*?[^\\]"' | cut -f4 -d '"'`
curl -ks -X POST "https://$cluster_address:$rest_port/v1/tree-delete/jobs/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"id\":\"$tree_id\"}" 2>&1 > /dev/null
curl -ks -X DELETE "https://$cluster_address:$rest_port/v2/nfs/exports/%2F${nfs_export:1}" -H "Authorization: Bearer $bearer_token" 2>&1 > /dev/null

printf "\nDone.\n"