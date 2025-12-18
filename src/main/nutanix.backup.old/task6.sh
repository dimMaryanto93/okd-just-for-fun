#!/bin/bash
# Task 6: Deploy OpenShift Cluster with Proper DNS Configuration

set -e

echo "======================================"
echo "Starting OpenShift Cluster Deployment (FIXED DNS)"
echo "======================================"
echo "Date: $(date)"
echo ""

# Get installation directory
INSTALL_DIR=$(cat /home/nutanix/.openshift_install_dir)
cd "${INSTALL_DIR}"

# Environment variables
PRISM_CENTRAL_ENDPOINT="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
PRISM_CENTRAL_USERNAME="${PRISM_CENTRAL_USERNAME:-admin}"
PRISM_CENTRAL_PASSWORD="${PRISM_CENTRAL_PASSWORD:-Pratista17@20@5}"
DNS_SERVER="10.11.1.63"
CLUSTER_NAME="ocp-cluster"
BASE_DOMAIN="nutanix.local"
API_VIP="10.11.1.42"
INGRESS_VIP="10.11.1.43"

# Set certificate trust environment
export SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export SSL_CERT_DIR=/etc/pki/ca-trust/extracted/pem
export NODE_EXTRA_CA_CERTS=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=quay.io/openshift-release-dev/ocp-release:4.14.15-x86_64

echo "Environment Configuration:"
echo "========================="
echo "Using Prism Central at: ${PRISM_CENTRAL_ENDPOINT}"
echo "DNS Server: ${DNS_SERVER}"
echo "API VIP: ${API_VIP}"
echo "Ingress VIP: ${INGRESS_VIP}"
echo ""

# Step 1: Configure DNS for installer VM
echo "Step 1: Configuring DNS for installer..."
sudo cp /etc/resolv.conf /etc/resolv.conf.backup-task4

# Create proper resolv.conf
cat <<EOF | sudo tee /etc/resolv.conf
search ${CLUSTER_NAME}.${BASE_DOMAIN}
nameserver ${DNS_SERVER}
EOF

# Test DNS resolution
echo "Testing DNS resolution..."
for i in {1..3}; do
    nslookup api.${CLUSTER_NAME}.${BASE_DOMAIN} && break
    echo "DNS resolution attempt $i failed, retrying..."
    sleep 2
done

# Step 2: Create wrapper script with environment
echo ""
echo "Step 2: Creating installer wrapper..."
cat > openshift-install-wrapper.sh <<'WRAPPER'
#!/bin/bash
# Set certificate trust
export SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export SSL_CERT_DIR=/etc/pki/ca-trust/extracted/pem
export NODE_EXTRA_CA_CERTS=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# Set Nutanix credentials
export NUTANIX_ENDPOINT="${PRISM_CENTRAL_ENDPOINT}"
export NUTANIX_PORT=9440
export NUTANIX_USERNAME="${PRISM_CENTRAL_USERNAME}"
export NUTANIX_PASSWORD="${PRISM_CENTRAL_PASSWORD}"

# Set RHCOS image
export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE=https://rhcos.mirror.openshift.com/art/storage/prod/streams/4.14-9.2/builds/414.92.202402130420-0/x86_64/rhcos-414.92.202402130420-0-nutanix.x86_64.qcow2

# Run installer
exec openshift-install "$@"
WRAPPER

chmod +x openshift-install-wrapper.sh

# Step 3: Create manifests
echo ""
echo "Step 3: Creating manifests..."
./openshift-install-wrapper.sh create manifests --dir . || {
    echo "ERROR: Failed to create manifests"
    exit 1
}

# Step 4: Create PROPER DNS configuration using NetworkManager
echo ""
echo "Step 4: Adding proper DNS configuration to manifests..."

# Create DNS config using NetworkManager for master nodes
cat > manifests/99-master-dns-networkmanager.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-master-dns-networkmanager
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(echo -e "[global-dns-domain-*]\nservers=${DNS_SERVER}" | base64 -w0)
        mode: 0644
        path: /etc/NetworkManager/conf.d/99-openshift-dns.conf
EOF

# Create DNS config using NetworkManager for worker nodes
cat > manifests/99-worker-dns-networkmanager.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-dns-networkmanager
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(echo -e "[global-dns-domain-*]\nservers=${DNS_SERVER}" | base64 -w0)
        mode: 0644
        path: /etc/NetworkManager/conf.d/99-openshift-dns.conf
EOF

# Create DHCP client configuration to append DNS
cat > manifests/99-master-dhcp-dns.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-master-dhcp-dns
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(echo "prepend domain-name-servers ${DNS_SERVER};" | base64 -w0)
        mode: 0644
        path: /etc/dhcp/dhclient.conf
EOF

cat > manifests/99-worker-dhcp-dns.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-dhcp-dns
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(echo "prepend domain-name-servers ${DNS_SERVER};" | base64 -w0)
        mode: 0644
        path: /etc/dhcp/dhclient.conf
EOF

# Step 5: Configure Nutanix credentials for manual mode
echo ""
echo "Step 5: Configuring Nutanix credentials..."

# Create credentials JSON
CREDS_JSON='[{"type":"basic_auth","data":{"prismCentral":{"username":"'${PRISM_CENTRAL_USERNAME}'","password":"'${PRISM_CENTRAL_PASSWORD}'"}}}]'

# Create secrets for machine-api
cat > manifests/openshift-machine-api-nutanix-credentials-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nutanix-credentials
  namespace: openshift-machine-api
type: Opaque
data:
  credentials: $(echo -n "${CREDS_JSON}" | base64 -w 0)
EOF

# Create secrets for cloud-controller-manager
cat > manifests/openshift-cloud-controller-manager-nutanix-credentials-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nutanix-credentials
  namespace: openshift-cloud-controller-manager
type: Opaque
data:
  credentials: $(echo -n "${CREDS_JSON}" | base64 -w 0)
EOF

# Create cloud config
cat > manifests/openshift-cloud-controller-manager-cloud-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-conf
  namespace: openshift-cloud-controller-manager
data:
  cloud.conf: |
    {
      "prismCentral": {
        "address": "${PRISM_CENTRAL_ENDPOINT}",
        "port": 9440,
        "credentialRef": {
          "kind": "Secret",
          "name": "nutanix-credentials",
          "namespace": "openshift-cloud-controller-manager"
        }
      },
      "topologyDiscovery": {
        "type": "Prism",
        "topologyCategories": null
      },
      "enableCustomLabeling": true
    }
EOF

# Step 6: Create ignition configs
echo ""
echo "Step 6: Creating ignition configs..."
./openshift-install-wrapper.sh create ignition-configs --dir . || {
    echo "ERROR: Failed to create ignition configs"
    exit 1
}

# Step 7: Deploy cluster
echo ""
echo "Step 7: Starting cluster deployment..."
echo "This will take 30-45 minutes..."
echo ""

# Create log directory
mkdir -p logs

# Start deployment with detailed logging
./openshift-install-wrapper.sh create cluster --dir . --log-level=debug 2>&1 | tee logs/install.log

echo ""
echo "======================================"
echo "Deployment completed successfully!"
echo "======================================"

export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"

# Save cluster information
CONSOLE_URL=$(oc whoami --show-console 2>/dev/null || echo "Check console route")
KUBEADMIN_PWD=$(cat auth/kubeadmin-password 2>/dev/null || echo "Check auth/kubeadmin-password")

cat > /home/nutanix/cluster-info.txt <<EOF
OpenShift Cluster Information
=============================
Cluster Name: ${CLUSTER_NAME}
Base Domain: ${BASE_DOMAIN}
Deployment Date: $(date)

Access Information:
- API URL: https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443
- Console URL: ${CONSOLE_URL}
- Username: kubeadmin
- Password: ${KUBEADMIN_PWD}

CLI Access:
export KUBECONFIG=${INSTALL_DIR}/auth/kubeconfig
oc login https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443 -u kubeadmin -p ${KUBEADMIN_PWD}

DNS Configuration:
- DNS Server: ${DNS_SERVER}
- API VIP: ${API_VIP}
- Ingress VIP: ${INGRESS_VIP}
EOF
    
echo ""
echo "Cluster information saved to: /home/nutanix/cluster-info.txt"
echo ""
echo "======================================"
echo "Deployment process completed!"
echo "======================================"
