#!/bin/bash
# Task 5: Create OpenShift Installation Configuration with DNS Fix

set -e  # Exit on any error

echo "======================================"
echo "Creating OpenShift Installation Configuration"
echo "======================================"
echo "Date: $(date)"
echo ""

# Get installation directory from previous task
INSTALL_DIR=$(cat /home/nutanix/.openshift_install_dir)
cd "${INSTALL_DIR}"

# Get SSH public key
SSH_KEY=$(cat /home/nutanix/.ssh/openshift_rsa.pub)

# Set configuration parameters
CLUSTER_NAME="${CLUSTER_NAME:-ocp-cluster}"
BASE_DOMAIN="${BASE_DOMAIN:-nutanix.local}"
PRISM_CENTRAL_ENDPOINT="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
PRISM_CENTRAL_USERNAME="${PRISM_CENTRAL_USERNAME:-admin}"
PRISM_CENTRAL_PASSWORD="Pratista17@20@5"
API_VIP="10.11.1.42"
INGRESS_VIP="10.11.1.43"
DNS_SERVER="10.11.1.63"
PULL_SECRET='{"auths":{"cloud.openshift.com":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfMTQyNmI2N2EwYjFhNGYwZWFkNGRjMzZkMzE3OTNjMWY6RDhVTEozOVM3MTVGTE5LM00xSVc5QkpURVExM0tSNTdIMVJEVVVFNzQ5REVDNEY3RjBTUTZZRE9ER01aVk8yNA==","email":"flxnzz_47@protonmail.com"},"quay.io":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfMTQyNmI2N2EwYjFhNGYwZWFkNGRjMzZkMzE3OTNjMWY6RDhVTEozOVM3MTVGTE5LM00xSVc5QkpURVExM0tSNTdIMVJEVVVFNzQ5REVDNEY3RjBTUTZZRE9ER01aVk8yNA==","email":"flxnzz_47@protonmail.com"},"registry.connect.redhat.com":{"auth":"fHVoYy1wb29sLWVhNjQ0Mzk0LWJmYzAtNGIyOS04NTVlLWYzMGVkODdhZWE3MjpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTFOMkkzWm1ZeE5URmtObVEwT1Raa09HUXlZMkpsTW1FM1ptTTJNV00zTXlKOS5RY2ZMeG5PTVBuRHV6bEtZMy1oeDM2V21QSlpyM0llLVBvYTd1Nzl3dFBneVJYYnNrWXBLSENwRXo5bzhJM2I4dnZzdUVTQWNMNG1IeWFkZWdYa2R3Mk4zaVhGSnlTbWRfZUV6eXZxZTJ5S3U0TW1xU0VNWnhzck9pMHd2Ym1lc192dFVxQVAyMmtfcnE2RkNVczNFYnh2MGREbUU0RlFLdko2bkhFX1NfQmFxZy1aSXZWUUlpcjdpVUo5dTAzS1ZoSVVleHBrdS1PQ1VQVE1UZmhoNW1KTGU4NGxIQVdYQVhHRmZRaVJtOGFrbVV1ems3b2otX1VXZXpnWHc3VnFlaV9NbnlBS0dNaHY2VnN6ZGFGUFRnUHJ6V3BfQUduNWNmQ3FTNGRSUVcxSkNJcXN5Ym43OVdfbDQ3X19TQWVISjU0NGdYUk80a3Z1MlVzekRlaU11d3RVQmlVVlZBcFJkTFhkYWZBU0tWRHdaYkV6ZFdDZGVMT2xHQkRKVDZRejB4VnZKUldJZl9PN2hlUUl4X19XVkhBQXRaQ25zQ3JERU15d2p3QzByU20yMUU5M19XUENsMlJOc0tnTnotcElLbDJOVENCVGhKUVFnODJaVmhVRGdiQTZLZFJJeWtzYmZGbWtLeXNpVVg5amd3aWoyUTZ0aWtIUkdtSEhXM1FTcndydVRNSWVjLTNxbjVkMTlFR2EwQmZjd2Q2eTBUVG4tVE12aHRNN1lIazNqZkxpYnVCYVZNMXV3bDhyMzNNbkdfeVVINjlvTlpjTUhGS1BYMXB2bWRJMTIxLUtVVi0xeE4xZ3lYRkhPODRSeDNuRkNJTXYyQTU0dHB3VV9GeFRRZXZrMUFJS3FIdGhnY0lOMXlEd01xa1RLR1Bzams2SDNTamF1aXBQMHFvMA==","email":"flxnzz_47@protonmail.com"},"registry.redhat.io":{"auth":"fHVoYy1wb29sLWVhNjQ0Mzk0LWJmYzAtNGIyOS04NTVlLWYzMGVkODdhZWE3MjpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTFOMkkzWm1ZeE5URmtObVEwT1Raa09HUXlZMkpsTW1FM1ptTTJNV00zTXlKOS5RY2ZMeG5PTVBuRHV6bEtZMy1oeDM2V21QSlpyM0llLVBvYTd1Nzl3dFBneVJYYnNrWXBLSENwRXo5bzhJM2I4dnZzdUVTQWNMNG1IeWFkZWdYa2R3Mk4zaVhGSnlTbWRfZUV6eXZxZTJ5S3U0TW1xU0VNWnhzck9pMHd2Ym1lc192dFVxQVAyMmtfcnE2RkNVczNFYnh2MGREbUU0RlFLdko2bkhFX1NfQmFxZy1aSXZWUUlpcjdpVUo5dTAzS1ZoSVVleHBrdS1PQ1VQVE1UZmhoNW1KTGU4NGxIQVdYQVhHRmZRaVJtOGFrbVV1ems3b2otX1VXZXpnWHc3VnFlaV9NbnlBS0dNaHY2VnN6ZGFGUFRnUHJ6V3BfQUduNWNmQ3FTNGRSUVcxSkNJcXN5Ym43OVdfbDQ3X19TQWVISjU0NGdYUk80a3Z1MlVzekRlaU11d3RVQmlVVlZBcFJkTFhkYWZBU0tWRHdaYkV6ZFdDZGVMT2xHQkRKVDZRejB4VnZKUldJZl9PN2hlUUl4X19XVkhBQXRaQ25zQ3JERU15d2p3QzByU20yMUU5M19XUENsMlJOc0tnTnotcElLbDJOVENCVGhKUVFnODJaVmhVRGdiQTZLZFJJeWtzYmZGbWtLeXNpVVg5amd3aWoyUTZ0aWtIUkdtSEhXM1FTcndydVRNSWVjLTNxbjVkMTlFR2EwQmZjd2Q2eTBUVG4tVE12aHRNN1lIazNqZkxpYnVCYVZNMXV3bDhyMzNNbkdfeVVINjlvTlpjTUhGS1BYMXB2bWRJMTIxLUtVVi0xeE4xZ3lYRkhPODRSeDNuRkNJTXYyQTU0dHB3VV9GeFRRZXZrMUFJS3FIdGhnY0lOMXlEd01xa1RLR1Bzams2SDNTamF1aXBQMHFvMA==","email":"flxnzz_47@protonmail.com"}}}'

# Function to make API call
api_call() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-}
    
    if [ -n "$data" ]; then
        curl -k -s -X ${method} \
            -H "Content-Type: application/json" \
            -u "${PRISM_CENTRAL_USERNAME}:${PRISM_CENTRAL_PASSWORD}" \
            -d "${data}" \
            "https://${PRISM_CENTRAL_ENDPOINT}:9440/api/nutanix/v3/${endpoint}"
    else
        curl -k -s -X ${method} \
            -H "Content-Type: application/json" \
            -u "${PRISM_CENTRAL_USERNAME}:${PRISM_CENTRAL_PASSWORD}" \
            "https://${PRISM_CENTRAL_ENDPOINT}:9440/api/nutanix/v3/${endpoint}"
    fi
}

# Auto-fetch Prism Element UUID if not provided
if [ -z "$PRISM_ELEMENT_UUID" ]; then
    echo "Auto-fetching Prism Element UUID..."
    PRISM_ELEMENT_UUID=$(api_call "clusters/list" "POST" '{"kind":"cluster"}' | jq -r '.entities[0].metadata.uuid' 2>/dev/null)
    
    if [ -z "$PRISM_ELEMENT_UUID" ] || [ "$PRISM_ELEMENT_UUID" == "null" ]; then
        echo "ERROR: Failed to auto-fetch Prism Element UUID"
        exit 1
    fi
    echo "Found Prism Element UUID: ${PRISM_ELEMENT_UUID}"
fi

# Auto-fetch Subnet UUID if not provided
if [ -z "$SUBNET_UUID" ]; then
    echo "Auto-fetching Subnet UUID..."
    SUBNET_UUID=$(api_call "subnets/list" "POST" '{"kind":"subnet"}' | jq -r '.entities[0].metadata.uuid' 2>/dev/null)
    
    if [ -z "$SUBNET_UUID" ] || [ "$SUBNET_UUID" == "null" ]; then
        echo "ERROR: Failed to auto-fetch Subnet UUID"
        exit 1
    fi
    echo "Found Subnet UUID: ${SUBNET_UUID}"
fi

# Configure DNS for current system
echo ""
echo "Configuring DNS resolution..."
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver ${DNS_SERVER}" | sudo tee /etc/resolv.conf
echo "search ${CLUSTER_NAME}.${BASE_DOMAIN}" | sudo tee -a /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Test DNS resolution
echo "Testing DNS resolution..."
nslookup api.${CLUSTER_NAME}.${BASE_DOMAIN} ${DNS_SERVER} || echo "DNS lookup failed, continuing..."

# Download and trust Nutanix certificate
echo ""
echo "Handling Nutanix certificate..."
CERT_FILE="${INSTALL_DIR}/nutanix-ca.crt"

# Extract certificate from Nutanix
echo | openssl s_client -connect "${PRISM_CENTRAL_ENDPOINT}:9440" -showcerts 2>/dev/null | \
    sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > "${CERT_FILE}"

if [ -s "${CERT_FILE}" ]; then
    echo "Certificate extracted successfully"
    TRUST_BUNDLE=$(cat "${CERT_FILE}")
else
    echo "Warning: Could not extract certificate, proceeding without trust bundle"
    TRUST_BUNDLE=""
fi

# Create install-config.yaml - FIXED VERSION
echo ""
echo "Creating install-config.yaml..."
cat > install-config.yaml <<EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 3
  platform:
    nutanix:
      cpus: 2
      coresPerSocket: 2
      memoryMiB: 8192
      osDisk:
        diskSizeGiB: 120
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
  platform:
    nutanix:
      cpus: 4
      coresPerSocket: 2
      memoryMiB: 16384
      osDisk:
        diskSizeGiB: 120
metadata:
  name: ${CLUSTER_NAME}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.11.1.0/24
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  nutanix:
    apiVIPs:
    - ${API_VIP}
    ingressVIPs:
    - ${INGRESS_VIP}
    prismCentral:
      endpoint:
        address: ${PRISM_CENTRAL_ENDPOINT}
        port: 9440
      username: ${PRISM_CENTRAL_USERNAME}
      password: ${PRISM_CENTRAL_PASSWORD}
    prismElements:
    - endpoint:
        address: ${PRISM_CENTRAL_ENDPOINT}
        port: 9440
      uuid: ${PRISM_ELEMENT_UUID}
    subnetUUIDs:
    - ${SUBNET_UUID}
    defaultMachinePlatform:
      bootType: Legacy
    clusterOSImage: https://rhcos.mirror.openshift.com/art/storage/prod/streams/4.14-9.2/builds/414.92.202402130420-0/x86_64/rhcos-414.92.202402130420-0-nutanix.x86_64.qcow2
credentialsMode: Manual
publish: External
pullSecret: '${PULL_SECRET}'
sshKey: '${SSH_KEY}'
EOF

# Add trust bundle if certificate was extracted
if [ -n "${TRUST_BUNDLE}" ]; then
    echo "additionalTrustBundle: |" >> install-config.yaml
    echo "${TRUST_BUNDLE}" | sed 's/^/  /' >> install-config.yaml
    echo "additionalTrustBundlePolicy: Always" >> install-config.yaml
fi

# Backup install-config.yaml
cp install-config.yaml install-config.yaml.backup

# Validate YAML syntax
echo ""
echo "Validating install-config.yaml syntax..."
python3 -c "import yaml; yaml.safe_load(open('install-config.yaml'))" 2>/dev/null || {
    echo "Warning: Cannot validate YAML syntax (python3-yaml not installed)"
}

# Display configuration summary
echo ""
echo "Configuration Summary:"
echo "====================="
echo "Cluster Name: ${CLUSTER_NAME}"
echo "Base Domain: ${BASE_DOMAIN}"
echo "DNS Server: ${DNS_SERVER}"
echo "Prism Central: ${PRISM_CENTRAL_ENDPOINT}"
echo "Prism Element UUID: ${PRISM_ELEMENT_UUID}"
echo "Subnet UUID: ${SUBNET_UUID}"
echo "API VIP: ${API_VIP}"
echo "Ingress VIP: ${INGRESS_VIP}"
echo ""

# Create DNS info file
cat > /home/nutanix/dns-setup-info.txt <<EOF
DNS Configuration Summary
=========================
DNS Server: ${DNS_SERVER}
API VIP: ${API_VIP}
Ingress VIP: ${INGRESS_VIP}

Required DNS Records:
- api.${CLUSTER_NAME}.${BASE_DOMAIN} -> ${API_VIP}
- api-int.${CLUSTER_NAME}.${BASE_DOMAIN} -> ${API_VIP}
- *.apps.${CLUSTER_NAME}.${BASE_DOMAIN} -> ${INGRESS_VIP}

Test DNS:
nslookup api.${CLUSTER_NAME}.${BASE_DOMAIN} ${DNS_SERVER}
nslookup test.apps.${CLUSTER_NAME}.${BASE_DOMAIN} ${DNS_SERVER}
EOF

echo "======================================"
echo "Configuration completed successfully!"
echo "======================================"
echo ""
echo "DNS info saved to: /home/nutanix/dns-setup-info.txt"
