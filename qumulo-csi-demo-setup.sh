#!/bin/sh

# Author: Brandon Williams <bwilliams@qumulo.com>

# Change these variables to match your envioronment.
cluster_address="192.168.0.190"
rest_port="8000"
username="admin" # This user must have permissions to create directories on the Qumulo filesystem and connect to the API
password="Admin123"
nfs_export="/k8s" # Keep this off the root of the filesystem for simplicity. Script mostly likely won't work otherwise.

# These variables should be left alone for now
replicas="1"
qumulo_csi_repo="https://github.com/Qumulo/csi-driver-qumulo"
path="./csi-driver-qumulo/deploy/"
test_db_repo="https://github.com/datacharmer/test_db"

# Determine OS type. Currently, CentOS/RHEL 7 and OS X should work
uname=`uname -a`
if [[ "$uname" == *"el7"* ]]
then
    os_type="Centos7"
elif [[ "$uname" == *"Darwin"* ]]
then
    os_type="Mac"
else
    printf "Unsupported OS type detected: $uname\n"
    exit -1
fi

# Print some info about the environment variables
printf "OS: $os_type\n"
printf "Qumulo cluster address: $cluster_address\n"
printf "Rest port: $rest_port\n"
printf "Qumulo username: $username\n"
printf "NFS Export: $nfs_export\n"
printf "Repo: $qumulo_csi_repo\n"
printf "Replicas: $replicas\n\n"

# Create directory structure and NFS export on Qumulo filesystem
printf "Creating NFS export on Qumulo...\n"
bearer_token=`curl -sk "https://$cluster_address:$rest_port/v1/session/login" -H "Content-Type: application/json" --data "{\"username\":\"$username\",\"password\":\"$password\"}"  | cut -f4 -d '"'`
curl -ks -X POST "https://$cluster_address:$rest_port/v1/files/%2F/entries/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"name\":\"${nfs_export:1}\",\"action\":\"CREATE_DIRECTORY\"}" 2>&1 > /dev/null
curl -ks -X POST "https://$cluster_address:$rest_port/v1/files/%2F${nfs_export:1}%2F/entries/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"name\":\"volumes\",\"action\":\"CREATE_DIRECTORY\"}" 2>&1 > /dev/null
curl -ks -X POST "https://$cluster_address:$rest_port/v2/nfs/exports/" -H "Content-Type: application/json" -H "Authorization: Bearer $bearer_token" --data "{\"export_path\":\"$nfs_export\",\"fs_path\":\"$nfs_export\",\"description\":\"Kubernetes CSI Demo\",\"restrictions\":[{\"read_only\":false,\"require_privileged_port\":false,\"host_restrictions\":[],\"user_mapping\":\"NFS_MAP_NONE\",\"map_to_user\":{\"id_type\":\"LOCAL_USER\",\"id_value\":\"0\"}}]}" 2>&1 > /dev/null

# Check for minikube installation and automatically install if not deteceted
printf "\nChecking for minikube installation...\n"
if minikube version 2> /dev/null
then
    printf ""
else
    printf "Installing minikube...\n\n"
    printf "\033[33;33mPROVIDE SUDO PASSWORD IF/WHEN PROMPTED.\033[33;37m\n\n"
    if [[ "$os_type" == "Mac" ]]
    then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
        sudo install minikube-darwin-amd64 /usr/local/bin/minikube
    elif [[ "$os_type" == "Centos7" ]]
    then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    fi
fi

# Check minikube status and start if it is not running
printf "\nChecking minikube status...\n"
minikube status | grep "Running" && minikube_status="running" || minikube_status="stopped"

if [[ "$minikube_status" == "stopped" ]]
then
    printf "Starting minikube...\n"
    minikube start
    minikube status | grep "Running" && minikube_status="running" || minikube_status="stopped"

    # Fail if minikube did not start for some reason
    if [[ "$minikube_status" == "stopped" ]]
    then
        printf "minikube failed to start.\n"
        printf "Qumulo CSI driver setup failed.\n"
        exit -1
    fi
fi

# Check for git client and install if not detected
printf "\nChecking for git client...\n"
if git --version 2> /dev/null
then
    printf ""
else
    printf "Installing git client...\n\n"
    printf "\033[33;33mPROVIDE SUDO PASSWORD IF/WHEN PROMPTED.\033[33;37m\n\n"
    if [[ "$os_type" == "Mac" ]]
    then
        # Use Homebrew to install git. If Homebrew is not installed, install it
        printf "\nChecking for Homebrew client...\n"
        if brew --version 2> /dev/null
        then
            printf "Installing git...\n"
            brew install git
        else
            printf "Installing Homebrew...\n"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            printf "Installing git...\n"
            brew install git
        fi
    elif [[ "$os_type" == "Centos7" ]]
    then
        sudo yum -y install git
    fi
fi

# Check for kubectl and install if not detected
printf "\nChecking for kubectl...\n"
if kubectl version 2> /dev/null
then
    printf ""
else
    printf "Installing kubectl...\n\n"
    printf "\033[33;33mPROVIDE SUDO PASSWORD IF/WHEN PROMPTED.\033[33;37m\n\n"
    if [[ "$os_type" == "Mac" ]]
    then
        brew install kubectl
    elif [[ "$os_type" == "Centos7" ]]
    then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    fi
fi

# Install and configure Qumulo CSI driver
printf "\nInstalling Qumulo CSI driver...\n"

# Check if git repo has been cloned previously and delete if it exists
if [ -d "./csi-driver-qumulo" ]
then
    rm -rf ./csi-driver-qumulo
fi

# Clone latest Qumulo CSI driver from github
git clone $qumulo_csi_repo

printf "\nConfiguring Qumulo CSI driver.\n"
printf "\033[33;33mErrors about configurations already existing can be ignored.\033[33;37m\n"

# Deploy Qumulo CSI driver components
sed -i.bak "s/replicas: 2/replicas: $replicas/g" $path/csi-qumulo-controller.yaml
kubectl create -f $path/rbac-csi-qumulo-controller.yaml
kubectl create -f $path/csi-qumulo-driverinfo.yaml
kubectl create -f $path/csi-qumulo-controller.yaml
kubectl create -f $path/csi-qumulo-node.yaml

# Apply configuration for current environment
sed -i.bak "s/10.116.10.177/$cluster_address/g" $path/example/storageclass-qumulo.yaml
sed -i.bak "s/\/regions\/4234/\\$nfs_export/g" $path/example/storageclass-qumulo.yaml
sed -i.bak "s/\/some\/export/\\$nfs_export/g" $path/example/storageclass-qumulo.yaml

kubectl create secret generic cluster1-login --type="kubernetes.io/basic-auth" --from-literal=username=$username --from-literal=password=$password --namespace=kube-system
kubectl create role access-secrets --verb=get,list,watch,update,create --resource=secrets --namespace kube-system
kubectl create rolebinding --role=access-secrets default-to-secrets --serviceaccount=kube-system:csi-qumulo-controller-sa --namespace kube-system

printf "\nSetting up storage class...\n"
kubectl apply -f $path/example/storageclass-qumulo.yaml
# kubectl apply -f $path/example/dynamic-pvc.yaml

printf "\nDeploying mysql...\n"
kubectl apply -f ./yaml/mysql-pvc-qumulo.yaml
kubectl apply -f ./yaml/mysql-deployment.yaml

until kubectl get pods | grep 'mysql' 2>&1 > /dev/null
do
    sleep 2
done

# Get the pod name for mysql deployment
mysql_pod=`kubectl get pods | grep -i 'mysql' | cut -f1 -d ' '`

printf "mysql pod name: $mysql_pod\n"

printf "\nWaiting for mysql pod deployment to complete...\n"
until kubectl get pods | grep mysql | grep -i 'running' 2>&1 > /dev/null
do
    printf "."
    sleep 2
done

printf "\n\nmysql deployed, waiting for database to initialize...\n"
until kubectl logs $mysql_pod | grep -i 'mysqld: ready for connections' 2>&1 > /dev/null
do
    printf "."
    sleep 2

    kubectl get pods | grep mysql | grep -i 'CrashLoopBackOff' && mysql_deploy_failed=true 2>&1 > /dev/null

    if [[ "$mysql_deploy_failed" == "true" ]]
    then
        printf "\nmysql failed to initialize correctly...\n\n"
        ./qumulo-csi-demo-destroy.sh
        printf "\nRetry deployment.\n"
        exit -1
    fi
done

# Pull test DB from github and populate mysql database with it
printf "\n\nPopulating mysql database. This process may take a while...\n"
printf "\n    *****************************************************\n"
printf "    **** \033[33;32mNOW IS A GOOD TIME TO LOOK AT THE QUMULO UI\033[33;37m ****\n"
printf "    *****************************************************\n\n"

# Check if git repo has been cloned previously and delete if it exists
if [ -d "./test_db" ]
then
    rm -rf ./test_db
fi

git clone $test_db_repo
# Correct path to .dump files in .sql imports
sed -i.bak "s/source /source \/test_db\//g" ./test_db/*.sql
# Copy sql dumps into container for importing
kubectl cp ./test_db $mysql_pod:/

kubectl exec $mysql_pod -- mysql -u root --password=password -A -e "source /test_db/employees.sql" 2>&1 > /dev/null

printf "\nDeploying nginx...\n"
kubectl apply -f ./yaml/nginx-pvc-qumulo.yaml
kubectl apply -f ./yaml/nginx-deployment.yaml

until kubectl get pods | grep 'nginx' 2>&1 > /dev/null
do
    sleep 2
done

# Get the pod name for nginx deployment
nginx_pod=`kubectl get pods | grep -i 'nginx' | cut -f1 -d ' '`

printf "nginx pod name: $nginx_pod\n"

printf "\nWaiting for nginx pod deployment to complete...\n"
until kubectl get pods | grep nginx | grep -i 'running' 2>&1 > /dev/null
do
    printf "."
    sleep 2
done

# Copy html onto nginx pvc via nginx container and change permissions so everyone can edit
kubectl cp ./html/ $nginx_pod:/usr/share/nginx/
kubectl exec $nginx_pod -- chmod 666 /usr/share/nginx/html/index.html

printf "\n\nSetting up port forward for nginx service...\n"

if [[ "$os_type" == "Mac" ]]
then
    host_ip_address=`ipconfig getifaddr en0`
elif [[ "$os_type" == "Centos7" ]]
then
    host_ip_address=`hostname -I | cut -f1 -d ' '`

    # If firewalld is running, open firewall port for port forwarding
    systemctl status firewalld | grep -i "running" && firewalld_status="running" || firewalld_status="stopped"
    if [[ "$firewalld_status" == "running" ]]
    then
        printf "\033[33;33mPROVIDE SUDO PASSWORD IF/WHEN PROMPTED.\033[33;37m\n"
        sudo firewall-cmd --zone=public --add-port=8080/tcp
    fi
fi

kubectl port-forward --address 0.0.0.0 service/nginx 8080:80 2>&1 > kubectl-port-forward.log &

printf "\n\033[33;32mAccess mysql prompt using the following command:\033[33;37m\n\n"

printf "kubectl exec -it $mysql_pod -- mysql -u root -p\n"

printf "\n\033[33;33mThe default password is \"password\"\033[33;37m\n"

printf "\n\033[33;32mWeb server can be accessed at:\033[33;37m http://$host_ip_address:8080\n"

printf "\nQumulo CSI driver setup complete.\n"