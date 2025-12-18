#!/bin/bash
# Task 3: Install OpenShift Tools

set -e 

echo "Checking for required tools..."
if ! command -v wget &> /dev/null; then
    echo "wget not found, installing..."
    sudo yum install -y wget || sudo dnf install -y wget
fi

OCP_VERSION="4.14.15"
MIRROR_URL="https://mirror.openshift.com/pub/openshift-v4"

echo "======================================"
echo "Starting OpenShift Tools Installation"
echo "======================================"
echo "OpenShift Version: ${OCP_VERSION}"
echo "Date: $(date)"
echo ""

echo "Creating temporary directory..."
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"
cp ~/openshift-install-linux.tar.gz .
cp ~/openshift-client-linux.tar.gz .

# Extract and install client tools
echo "Installing OpenShift client tools..."
sudo chmod +x openshift-client-linux.tar.gz
tar -xzf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
sudo chmod +x /usr/local/bin/oc /usr/local/bin/kubectl

# Extract and install installer
echo "Installing OpenShift installer..."
tar -xzf openshift-install-linux.tar.gz
sudo mv openshift-install /usr/local/bin/
sudo chmod +x /usr/local/bin/openshift-install

echo "Creating working directories..."
mkdir -p /home/nutanix/openshift-deployments
mkdir -p /home/nutanix/bin
mkdir -p /home/nutanix/.kube
chown -R nutanix:nutanix /home/nutanix/openshift-deployments
chown -R nutanix:nutanix /home/nutanix/bin  
chown -R nutanix:nutanix /home/nutanix/.kube

echo "Cleaning up temporary files..."
cd /
rm -rf "${TEMP_DIR}"

echo ""
echo "======================================"
echo "Verification"
echo "======================================"

echo -n "oc version: "
/usr/local/bin/oc version --client || echo "FAILED"

echo -n "kubectl version: "
/usr/local/bin/kubectl version --client --short || echo "FAILED"

echo -n "openshift-install version: "
/usr/local/bin/openshift-install version || echo "FAILED"

echo ""
echo "======================================"
echo "OpenShift tools installation completed!"
echo "======================================"
