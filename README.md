# Qumulo CSI Demo

###### These scripts have only been tested on OS X and CentOS 7

**Prerequisites**
- Client running OS X or CentOS 7
- VMware Fusion, VirtualBox, or Docker Engine installed (docker must be user runnable)
- A deployed Qumulo filesystem (either OVA or physical)

Before running the scripts `qumulo-csi-demo-setup.sh` or `qumulo-csi-demo-destroy.sh` scripts, edit them and change the following variables to match your environment:
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

**Demoing**
If everything deployed correctly, you should see instructions printed to the console for accessing the mysql instance and the web server which were deployed. You can determine the path of the pvc for the web server using the following command:

```
kubectl get pvc
```

Look for the volume name bound to nginx-pvc. This is the directory name you will look for on your Qumulo filesystem under /<NFS export>/volumes/ (e.g. /k8s/volumes/). In the directory for the nginx-pvc, you will see index.html. This file can be modified with the text editor of your choice and after doing so, you can refresh the web page for the web service to view any changes you have made.