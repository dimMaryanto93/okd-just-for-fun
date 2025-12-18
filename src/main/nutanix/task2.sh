#!/bin/bash
# Task 2: Prerequisites & certificate validation

set -e  # Exit on any error

echo "======================================"
echo "OpenShift Installation Prerequisites Check"  
echo "======================================"
echo "Date: $(date)"
echo ""

check_nutanix_certificate() {
    echo "Checking Nutanix Certificate..."
    
    PRISM_IP="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
    
    # Download current certificate
    echo | openssl s_client -connect "${PRISM_IP}:9440" -showcerts 2>/dev/null | \
        openssl x509 -text -noout > /tmp/cert-check.txt 2>/dev/null || true
    
    # Check for IP SANs
    if grep -q "IP Address:${PRISM_IP}" /tmp/cert-check.txt 2>/dev/null; then
        echo "✓ Certificate has IP SANs - Good!"
        return 0
    else
        echo "✗ ERROR: Certificate does NOT have IP SANs"
        echo ""
        echo "Current certificate Subject Alternative Names:"
        grep -A2 "Subject Alternative Name" /tmp/cert-check.txt 2>/dev/null || echo "  No SANs found"
        echo ""
        echo "======================================"
        echo "ACTION REQUIRED: Replace Nutanix Certificate"
        echo "======================================"
        echo ""
        echo "The current Nutanix certificate doesn't contain IP SANs."
        echo "OpenShift installation WILL FAIL with this certificate."
        echo ""
        echo "To fix this, you need to:"
        echo ""
        echo "1. Generate new certificate with IP SANs:"
        echo "   Run: /home/nutanix/fix-nutanix-certificate.sh"
        echo ""
        echo "2. Replace certificate in Prism Central UI"
        echo ""
        echo "3. Re-run this prerequisites check"
        echo ""
        
        # Create the fix script
        create_fix_certificate_script
        
        return 1
    fi
}

# Function to create certificate fix script
create_fix_certificate_script() {
    cat > /home/nutanix/fix-nutanix-certificate.sh <<'FIXSCRIPT'
#!/bin/bash
# Generate new certificate with IP SANs for Nutanix

PRISM_IP="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
PRISM_FQDN="${PRISM_FQDN:-prism-central.local}"

echo "Generating new certificate with IP SANs..."

openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 -keyout nutanix-${PRISM_IP}.key -out nutanix-${PRISM_IP}.crt \
  -subj "/C=US/ST=CA/L=San Jose/O=Nutanix Inc./OU=Manageability/CN=*.nutanix.local" \
  -addext "subjectAltName=IP:${PRISM_IP},DNS:${PRISM_FQDN},DNS:*.nutanix.local"

echo ""
echo "Certificate generated!"
echo "Files: nutanix-${PRISM_IP}.crt and nutanix-${PRISM_IP}.key"
echo ""
echo "Now replace certificate in Prism Central:"
echo "1. Login to https://${PRISM_IP}:9440"
echo "2. Go to Settings → SSL Certificate"
echo "3. Click 'Replace Certificate'"
echo "4. Copy contents of .crt and .key files"
echo "5. Wait for restart"
FIXSCRIPT
    
    chmod +x /home/nutanix/fix-nutanix-certificate.sh
}

# Function to setup environment
setup_environment() {
    echo "Setting up environment..."
    
    # Create necessary directories
    mkdir -p /home/nutanix/{.ssh,bin,openshift-deployments}
    mkdir -p /home/nutanix/.bashrc.d
    
    # Set environment variables
    cat > /home/nutanix/.bashrc.d/openshift-env.sh <<EOF
# OpenShift Environment Variables
export PATH=\$PATH:/usr/local/bin:/home/nutanix/bin
export NUTANIX_ENDPOINT=${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}
export NUTANIX_PORT=9440
EOF
    
    # Source the environment
    source /home/nutanix/.bashrc.d/openshift-env.sh
    
    # Set proper permissions
    chown -R nutanix:nutanix /home/nutanix/{.ssh,bin,openshift-deployments,.bashrc.d}
    chmod 700 /home/nutanix/.ssh
    
    echo "✓ Environment setup completed"
}

# Function to validate connectivity
validate_connectivity() {
    echo ""
    echo "Validating connectivity..."
    
    PRISM_IP="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
    
    # Check connectivity
    if nc -zv "${PRISM_IP}" 9440 2>&1 | grep -q succeeded; then
        echo "✓ Can connect to Prism Central at ${PRISM_IP}:9440"
    else
        echo "✗ ERROR: Cannot connect to Prism Central ${PRISM_IP}:9440"
        return 1
    fi
}

# Function to create summary
create_prerequisites_summary() {
    echo ""
    echo "Creating prerequisites summary..."
    
    PRISM_IP="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
    CERT_STATUS="Unknown"
    
    # Check certificate status
    if grep -q "IP Address:${PRISM_IP}" /tmp/cert-check.txt 2>/dev/null; then
        CERT_STATUS="Valid (has IP SANs)"
    else
        CERT_STATUS="INVALID (missing IP SANs) - MUST FIX!"
    fi
    
    cat > /home/nutanix/prerequisites-summary.txt <<EOF
OpenShift on Nutanix Prerequisites Summary
==========================================
Generated: $(date)

Environment:
- Prism Central IP: ${PRISM_IP}
- Certificate Status: ${CERT_STATUS}
- Connectivity: $(nc -zv "${PRISM_IP}" 9440 >/dev/null 2>&1 && echo "OK" || echo "Failed")

Required Variables Status:
- CLUSTER_NAME: ${CLUSTER_NAME:-Not Set}
- BASE_DOMAIN: ${BASE_DOMAIN:-Not Set}
- API_VIP: ${API_VIP:-Not Set}
- INGRESS_VIP: ${INGRESS_VIP:-Not Set}
- PULL_SECRET: $([ -n "${PULL_SECRET}" ] && echo "Set" || echo "Not Set")

Action Items:
$(grep -q "IP Address:${PRISM_IP}" /tmp/cert-check.txt 2>/dev/null || echo "1. FIX CERTIFICATE - Run: /home/nutanix/fix-nutanix-certificate.sh")
$([ -z "${PULL_SECRET}" ] && echo "2. Provide Red Hat pull secret during launch")
3. Configure DNS for cluster domains after getting VIP addresses
EOF
    
    echo "Summary saved to: /home/nutanix/prerequisites-summary.txt"
}

# Main execution
main() {
    echo "Running comprehensive prerequisites check..."
    
    # Setup environment first
    setup_environment
    
    # Check certificate - this is CRITICAL
    if ! check_nutanix_certificate; then
        echo ""
        echo "======================================"
        echo "PREREQUISITES CHECK FAILED!"
        echo "======================================"
        echo "Certificate issue MUST be fixed before proceeding."
        echo "See instructions above."
        
        # Still create summary
        create_prerequisites_summary
        
        exit 1
    fi
    
    # Validate connectivity
    validate_connectivity || echo "⚠ Connectivity warning"
    
    # Create summary
    create_prerequisites_summary
    
    echo ""
    echo "======================================"
    echo "Prerequisites check completed!"
    echo "======================================"
    echo ""
    echo "✓ Certificate has IP SANs - Ready for OpenShift installation"
    echo ""
    echo "Review /home/nutanix/prerequisites-summary.txt for details"
}

# Run main function
main
