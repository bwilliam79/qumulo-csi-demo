# Qumulo CSI Demo

These scripts have only been tested on OS X and depend on VMware Fusion and an existing Qumulo filesystem.

qumulo-csi-demo-setup.sh is designed to deploy a single node Kubernetes deployment, configure the Qumulo CSI driver to demonstrate persistent storage for containerzied workloads, and deploy a mysql instance using a persistent volume provisioined via the Qumulo CSI driver.
If the script completes successfully, you should see a quota in the Qumulo UI and a directory within the volumes directory of the NFS export e.g. /k8s/volumes/pvc-24be5dae-8591-494a-9e93-ca14df36a5c8/. Instructions for accessing the mysql instance are displayed during the script's execution.
It can take a few minutes before the mysql instance is fully running as it has to pull down a mysql container image, deploy, and initialize it. You should see activity within the Qumulo UI once the mysql instance has started.

qumulo-csi-demo-destroy.sh will remove the directory and quota created by the qumulo-csi-demo-setup.sh script and delete the minikube instance it deployed
If the script completes successfully, you should no longer see a quota in the Qumulo UI or a directory within the volumes directory of the NFS export