# Qumulo CSI Demo

###### These scripts have only been tested on OS X and depend on VMware Fusion and an existing Qumulo filesystem.

**Prerequisites**
- Client running OS X
- VMware Fusion
- A deployed Qumulo filesystem (either OVA or physical)

Before running the scripts qumulo-csi-demo-setup or qumulo-csi-demo-destroy scripts, edit them and change the following variables to match your environment:
```
cluster_address="192.168.0.190"
rest_port="8000"
username="admin"
password="Admin123"
nfs_export="/k8s"
```

###### qumulo-csi-demo-setup.sh
This script performs the folloing tasks
1. Installs the following components if they are not present:
    - minikube
    - homebrew
    - git
    - kubectl
2. Create a directory on the Qumulo filesystem to be shared via NFS
3. Create an NFS export using the directory created in step 1
4. Deploy a Kubernetes cluster using minikube
5. Provision and configure the Qumulo CSI driver
6. Deploy a mysql instance on Kubernetes using a persistent volume from Qumulo
7. Populate the mysql database with test data.

###### qumulo-csi-demo-destroy.sh
This script performs teh following tasks
1. Deletes the mysql data on the Qumulo filesystem
2. Deletes the Kubernetes deployment in minikube