#!/bin/bash
# Task 4: Generate SSH Key Pair and Prepare Installation

set -e  # Exit on any error

echo "======================================"
echo "Starting SSH Key Generation and Preparation"
echo "======================================"
echo "Date: $(date)"
echo ""

# Create .ssh directory if it doesn't exist
echo "Creating SSH directory..."
mkdir -p /home/nutanix/.ssh
chmod 700 /home/nutanix/.ssh

# Generate SSH key pair for OpenShift cluster nodes
echo "Generating SSH key pair for cluster nodes..."
if [ ! -f /home/nutanix/.ssh/openshift_rsa ]; then
    ssh-keygen -t rsa -b 2048 -N '' -f /home/nutanix/.ssh/openshift_rsa
    echo "SSH key pair generated successfully"
else
    echo "SSH key pair already exists, skipping generation"
fi

# Display public key
echo ""
echo "SSH Public Key (this will be used in install-config.yaml):"
echo "=========================================================="
cat /home/nutanix/.ssh/openshift_rsa.pub
echo "=========================================================="

# Add SSH key to ssh-agent
echo "Adding SSH key to ssh-agent..."
eval "$(ssh-agent -s)"
ssh-add /home/nutanix/.ssh/openshift_rsa

# Create working directory for OpenShift installation
echo "Creating OpenShift installation directory..."
INSTALL_DIR="/home/nutanix/openshift-install-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Store installation directory path for next tasks
echo "${INSTALL_DIR}" > /home/nutanix/.openshift_install_dir

# Set proper ownership
chown -R nutanix:nutanix /home/nutanix/.ssh
chown -R nutanix:nutanix "${INSTALL_DIR}"

echo ""
echo "======================================"
echo "SSH key generation and preparation completed!"
echo "Installation directory: ${INSTALL_DIR}"
echo "======================================"
