#!/bin/sh

# Author: Brandon Williams <bwilliams@qumulo.com>
# This script is designed to deploy a single node Kubernetes deployment and configure the Qumulo CSI driver to demonstrate persistent storage for containerzied workloads.
# If the script completes successfully, you should see a quota in the Qumulo UI and a directory within the volumes directory of the NFS export
# e.g. /k8s/volumes/pvc-24be5dae-8591-494a-9e93-ca14df36a5c8/
#
# Prerequisites: Existing Qumulo filesystem (OVA or physical deployment)

# Change these variables to match your envioronment.
cluster_address="192.168.0.190"
rest_port="8000"
username="admin" # This user must have permissions to create directories on the Qumulo filesystem and connect to the API
password="Admin123"
nfs_export="/k8s" # Keep this off the root of the filesystem for simplicity. Script mostly likely won't work otherwise.

# These variables should be left alone for now
replicas="1"
qumulo_csi_repo="https://github.com/ScottUrban/csi-driver-qumulo"
path="./csi-driver-qumulo/deploy/"
test_db_repo="https://github.com/datacharmer/test_db"

# Print some info about the environment variables
echo "Qumulo cluster address: $cluster_address"
echo "Rest port: $rest_port"
echo "Qumulo username: $username"
echo "NFS Export: $nfs_export"
echo "Repo: $qumulo_csi_repo"
echo "Replicas: $replicas\n"

# Create directory structure and NFS export on Qumulo filesystem
echo "Creating NFS export on Qumulo..."
bearer_token=`curl -sk "https://$cluster_address:$rest_port/v1/session/login" -H "Content-Type: application/json" --data "{\"username\":\"$username\",\"password\":\"$password\"}"  | cut -f4 -d '"'`
curl -ks -X POST "https://$cluster_address:$rest_port/v1/files/%2F/entries/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"name\":\"${nfs_export:1}\",\"action\":\"CREATE_DIRECTORY\"}" 2>&1 > /dev/null
curl -ks -X POST "https://$cluster_address:$rest_port/v1/files/%2F${nfs_export:1}%2F/entries/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"name\":\"volumes\",\"action\":\"CREATE_DIRECTORY\"}" 2>&1 > /dev/null
curl -ks -X POST "https://$cluster_address:$rest_port/v2/nfs/exports/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"export_path\":\"$nfs_export\",\"fs_path\":\"$nfs_export\",\"description\":\"Kubernetes CSI Demo\",\"restrictions\":[{\"read_only\":false,\"require_privileged_port\":false,\"host_restrictions\":[],\"user_mapping\":\"NFS_MAP_NONE\",\"map_to_user\":{\"id_type\":\"LOCAL_USER\",\"id_value\":\"0\"}}]}" 2>&1 > /dev/null

# Check for minikube installation and automatically install if not deteceted
echo "\nChecking for minikube installation..."
if minikube version 2> /dev/null
then
    echo ""
else
    echo "Installing minikube...\n"
    echo "\033[33;33mPROVIDE SUDO PASSWORD IF/WHEN PROMPTED.\033[33;37m\n"
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
    sudo install minikube-darwin-amd64 /usr/local/bin/minikube
fi

# Check minikube status and start if it is not running
#echo "Checking minikube status..."
minikube status | grep "Running" && minikube_status=running || minikube_status=stopped

if [[ "$minikube_status" == "stopped" ]]
then
    echo "Starting minikube..."
    minikube start
    minikube status | grep "Running" && minikube_status=running || minikube_status=stopped

    # Fail if minikube did not start for some reason
    if [[ "$minikube_status" == "stopped" ]]
    then
        echo "minikube failed to start."
        echo "Qumulo CSI driver setup failed."
        exit -1
    fi
fi

# Check for git client and install if not detected
echo "\nChecking for git client..."
if git --version 2> /dev/null
then
    echo ""
else
    # Use Homebrew to install git. If Homebrew is not installed, install it
    echo "\nChecking for Homebrew client..."
    if brew --version 2> /dev/null
    then
        echo ""
    else
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo "Installing git..."
        brew install git
    fi
fi

# Check for kubectl and install if not detected
echo "Checking for kubectl..."
if kubectl version 2> /dev/null
then
    echo ""
else
    echo "Installing kubectl..."
    brew install kubectl
fi

# Install and configure Qumulo CSI driver
echo "Installing Qumulo CSI driver..."

# Check if git repo has been cloned previously and delete if it exists
if [ -d "./csi-driver-qumulo" ]
then
    rm -rf ./csi-driver-qumulo
fi

# Clone latest Qumulo CSI driver from github
git clone $qumulo_csi_repo

echo "\nConfiguring Qumulo CSI driver."
echo "\033[33;33mErrors about configurations already existing can be ignored.\033[33;37m"

# Deploy Qumulo CSI driver components
sed -i '' "s/replicas: 2/replicas: $replicas/g" $path/csi-qumulo-controller.yaml
kubectl create -f $path/rbac-csi-qumulo-controller.yaml
kubectl create -f $path/csi-qumulo-driverinfo.yaml
kubectl create -f $path/csi-qumulo-controller.yaml
kubectl create -f $path/csi-qumulo-node.yaml

# Apply configuration for current environment
sed -i '' "s/10.116.10.177/$cluster_address/g" $path/example/storageclass-qumulo.yaml
sed -i '' "s/\/regions\/4234/\\$nfs_export/g" $path/example/storageclass-qumulo.yaml
sed -i '' "s/\/some\/export/\\$nfs_export/g" $path/example/storageclass-qumulo.yaml

kubectl create secret generic cluster1-login --type="kubernetes.io/basic-auth" --from-literal=username=$username --from-literal=password=$password --namespace=kube-system
kubectl create role access-secrets --verb=get,list,watch,update,create --resource=secrets --namespace kube-system
kubectl create rolebinding --role=access-secrets default-to-secrets --serviceaccount=kube-system:csi-qumulo-controller-sa --namespace kube-system

echo "\nSetting up storage class..."
kubectl apply -f $path/example/storageclass-qumulo.yaml
# kubectl apply -f $path/example/dynamic-pvc.yaml

echo "\nDeploying mysql..."
kubectl apply -f ./mysql-pvc-qumulo.yaml
kubectl apply -f ./mysql-deployment.yaml

# Wait a few seconds for mysql pod to deploy
sleep 5

# Get the pod name for mysql deployment
mysql_pod=`kubectl get pods | grep mysql | cut -f1 -d ' '`

echo "\nWaiting for mysql pod deployment to complete..."
until kubectl get pods | grep mysql | grep -i running 2>&1 > /dev/null
do
    printf "."
    sleep 2
done

echo "\n\nmysql deployed, waiting for database to initialize..."
until kubectl logs $mysql_pod | grep -i 'mysqld: ready for connections' 2>&1 > /dev/null
do
    printf "."
    sleep 2

    kubectl get pods | grep mysql | grep -i 'CrashLoopBackOff' && mysql_deploy_failed= true

    if [[ "mysql_deploy_failed" == true ]]
    then
        echo "\nmysql failed to initialize correctly..."
        ./qumulo-csi-demo-destroy.sh
        echo "\nRetry deployment."
        exit
    fi
done

# Pull test DB from github and populate mysql database with it
echo "\n\nPopulating mysql database. This process will take a while..."
echo "\n    *****************************************************"
echo "    **** \033[33;32mNOW IS A GOOD TIME TO LOOK AT THE QUMULO UI\033[33;37m ****    "
echo "    *****************************************************\n"

# Check if git repo has been cloned previously and delete if it exists
if [ -d "./test_db" ]
then
    rm -rf ./test_db
fi

git clone $test_db_repo
# Correct path to .dump files in .sql imports
sed -i '' "s/source /source \/test_db\//g" ./test_db/*.sql
# Copy sql dumps into container for importing
kubectl cp ./test_db $mysql_pod:/

kubectl exec $mysql_pod -- mysql -u root --password=password -A -e "source /test_db/employees.sql" 2>&1 > /dev/null

echo "\n\033[33;32mAccess mysql prompt using the following command:\033[33;37m\n"

echo "kubectl exec -it $mysql_pod -- mysql -u root -p"

echo "\n\033[33;33mThe default password is \"password\"\033[33;37m"

echo "\nQumulo CSI driver setup complete."