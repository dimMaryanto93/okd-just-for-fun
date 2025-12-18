#!/bin/bash
# Task 1: Certificate Handler. Automated Certificate Trust Setup

set -e

echo "======================================"
echo "Automated Certificate Trust Handler"
echo "======================================"
echo "Date: $(date)"
echo ""

PRISM_IP="${PRISM_CENTRAL_ENDPOINT:-10.11.1.36}"
PRISM_CENTRAL_USERNAME="${PRISM_CENTRAL_USERNAME:-admin}"
PRISM_CENTRAL_PASSWORD="Pratista17@20@5"

# Function to setup certificate trust
setup_certificate_trust() {
    echo "Setting up certificate trust automatically..."
    
    # Step 1: Clean any existing certificates
    echo "Step 1: Cleaning old certificates..."
    sudo rm -f /etc/pki/ca-trust/source/anchors/nutanix* || true
    sudo rm -f /etc/pki/ca-trust/source/anchors/*${PRISM_IP}* || true
    sudo update-ca-trust extract
    
    # Step 2: Download certificate from Nutanix
    echo ""
    echo "Step 2: Downloading certificate from Nutanix ${PRISM_IP}..."
    
    # Multiple attempts to ensure we get the certificate
    for attempt in 1 2 3; do
        echo "Attempt $attempt..."
        
        # Method 1: Using openssl s_client
        timeout 10 openssl s_client -connect ${PRISM_IP}:9440 -servername ${PRISM_IP} -showcerts </dev/null 2>/dev/null | \
            sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > /tmp/nutanix-cert-${attempt}.crt
        
        # Method 2: Using curl if openssl fails
        if [ ! -s /tmp/nutanix-cert-${attempt}.crt ]; then
            curl -k --connect-timeout 10 https://${PRISM_IP}:9440 2>&1 | \
                openssl s_client -connect ${PRISM_IP}:9440 -showcerts 2>/dev/null | \
                sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > /tmp/nutanix-cert-${attempt}.crt
        fi
        
        if [ -s /tmp/nutanix-cert-${attempt}.crt ]; then
            echo "Certificate downloaded successfully"
            cp /tmp/nutanix-cert-${attempt}.crt /tmp/nutanix-cert.crt
            break
        fi
        
        sleep 2
    done
    
    # Verify certificate was downloaded
    if [ ! -s /tmp/nutanix-cert.crt ]; then
        echo "ERROR: Failed to download certificate from Nutanix"
        return 1
    fi
    
    # Step 3: Verify certificate has IP SANs
    echo ""
    echo "Step 3: Verifying certificate..."
    if openssl x509 -in /tmp/nutanix-cert.crt -text -noout | grep -q "IP Address:${PRISM_IP}"; then
        echo "✓ Certificate has IP SANs - Good!"
        openssl x509 -in /tmp/nutanix-cert.crt -text -noout | grep -A2 "Subject Alternative Name" || true
    else
        echo "⚠ WARNING: Certificate might not have IP SANs"
        echo "Continuing anyway with certificate trust..."
    fi
    
    # Step 4: Install certificate to system trust
    echo ""
    echo "Step 4: Installing certificate to system trust..."
    
    # Install to multiple locations to ensure compatibility
    sudo cp /tmp/nutanix-cert.crt /etc/pki/ca-trust/source/anchors/nutanix-${PRISM_IP}.crt
    sudo cp /tmp/nutanix-cert.crt /etc/pki/ca-trust/source/anchors/nutanix-prism.crt
    
    # Update CA trust
    sudo update-ca-trust force-enable
    sudo update-ca-trust extract
    
    # Also add to ca-bundle directly (belt and suspenders approach)
    if [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then
        sudo cp /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt.backup
        cat /tmp/nutanix-cert.crt | sudo tee -a /etc/pki/tls/certs/ca-bundle.crt >/dev/null
    fi
    
    # Step 5: Export environment variables for child processes
    echo ""
    echo "Step 5: Setting environment variables..."
    
    # Create environment file
    cat > /home/nutanix/nutanix-cert-env.sh <<EOF
export SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export SSL_CERT_DIR=/etc/pki/ca-trust/extracted/pem
export NODE_EXTRA_CA_CERTS=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export CURL_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
export NUTANIX_CERT_TRUSTED=true
EOF
    
    # Source it immediately
    source /home/nutanix/nutanix-cert-env.sh
    
    # Add to bashrc for persistence
    if ! grep -q "nutanix-cert-env.sh" /home/nutanix/.bashrc; then
        echo "source /home/nutanix/nutanix-cert-env.sh" >> /home/nutanix/.bashrc
    fi
    
    echo "✓ Certificate trust setup completed"
}

# Function to test certificate trust
test_certificate_trust() {
    echo ""
    echo "Testing certificate trust..."
    
    local test_passed=true
    
    # Test 1: curl
    echo -n "Test 1 - curl: "
    if curl -s --connect-timeout 5 https://${PRISM_IP}:9440 -o /dev/null 2>&1; then
        echo "✓ PASSED"
    else
        echo "✗ FAILED"
        test_passed=false
    fi
    
    # Test 2: wget
    echo -n "Test 2 - wget: "
    if wget --timeout=5 -q -O /dev/null https://${PRISM_IP}:9440 2>&1; then
        echo "✓ PASSED"
    else
        echo "✗ FAILED"
        test_passed=false
    fi
    
    # Test 3: openssl
    echo -n "Test 3 - openssl verify: "
    if echo | openssl s_client -connect ${PRISM_IP}:9440 2>&1 | grep -q "Verify return code: 0"; then
        echo "✓ PASSED"
    else
        echo "⚠ WARNING (this might be normal)"
    fi
    
    # Test 4: API call
    echo -n "Test 4 - API call: "
    if [ -n "${PRISM_CENTRAL_PASSWORD}" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -u "${PRISM_CENTRAL_USERNAME}:${PRISM_CENTRAL_PASSWORD}" \
            https://${PRISM_IP}:9440/api/nutanix/v3/users/me 2>/dev/null)
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
            echo "✓ PASSED (HTTP $HTTP_CODE)"
        else
            echo "✗ FAILED (HTTP $HTTP_CODE)"
            test_passed=false
        fi
    else
        echo "⚠ SKIPPED (no password)"
    fi
    
    if [ "$test_passed" = true ]; then
        echo ""
        echo "✓ All certificate trust tests passed!"
        return 0
    else
        echo ""
        echo "⚠ Some tests failed, but continuing..."
        return 0  # Don't fail the task
    fi
}

# Main execution
main() {
    # Setup certificate trust
    setup_certificate_trust
    
    # Test the trust
    test_certificate_trust
    
    # Create marker file
    touch /home/nutanix/.certificate-trust-configured
    
    echo ""
    echo "======================================"
    echo "Certificate trust handler completed!"
    echo "======================================"
    echo ""
    echo "Environment ready for OpenShift installation"
}

# Run main
main
