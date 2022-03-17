"# Qumulo CSI Demo" 

# These scripts have only been tested on OS X and depend on VMware Fusion and an existing Qumulo filesystem.

# qumulo-csi-demo-setup.sh is designed to deploy a single node Kubernetes deployment and configure the Qumulo CSI driver to demonstrate persistent storage for containerzied workloads.
# If the script completes successfully, you should see a quota in the Qumulo UI and a directory within the volumes directory of the NFS export
# e.g. /k8s/volumes/pvc-24be5dae-8591-494a-9e93-ca14df36a5c8/

# qumulo-csi-demo-destroy.sh will remove the directory and quota created by the qumulo-csi-demo-setup.sh script and delete the minikube instance it deployed
# If the script completes successfully, you should no longer see a quota in the Qumulo UI or a directory within the volumes directory of the NFS export
