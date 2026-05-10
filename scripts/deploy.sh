
#!/bin/bash

set -e

echo "🚀 Starting Analytics App Deployment"

# Configuration
DOCKER_IMAGE="your-dockerhub-username/analytics-app"
NAMESPACE="analytics-prod"
KUBECONFIG_FILE="${HOME}/.kube/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi
    
    # Check kubeconfig
    if [[ ! -f "$KUBECONFIG_FILE" ]]; then
        log_error "Kubeconfig file not found: $KUBECONFIG_FILE"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building Docker image..."
    
    # Get current timestamp for tag
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BUILD_TAG="${TIMESTAMP}-$(git rev-parse --short HEAD)"
    
    # Build image
    docker build -t "${DOCKER_IMAGE}:${BUILD_TAG}" .
    docker tag "${DOCKER_IMAGE}:${BUILD_TAG}" "${DOCKER_IMAGE}:latest"
    
    log_info "Pushing Docker image to registry..."
    docker push "${DOCKER_IMAGE}:${BUILD_TAG}"
    docker push "${DOCKER_IMAGE}:latest"
    
    # Update Kubernetes manifests with new tag
    sed -i.bak "s|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${BUILD_TAG}|g" kubernetes/deployment.yaml
    
    log_info "Docker image built and pushed: ${DOCKER_IMAGE}:${BUILD_TAG}"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log_info "Deploying to Kubernetes..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations in order
    kubectl apply -f kubernetes/configmap.yaml
    kubectl apply -f kubernetes/secrets.yaml
    kubectl apply -f kubernetes/service-account.yaml
    kubectl apply -f kubernetes/rbac.yaml
    kubectl apply -f kubernetes/deployment.yaml
    kubectl apply -f kubernetes/service.yaml
    
    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready..."
    kubectl rollout status deployment/analytics-app -n "$NAMESPACE" --timeout=300s
    
    # Get service details
    log_info "Getting service details..."
    kubectl get services -n "$NAMESPACE"
    
    # Get external IP/NodePort
    NODE_PORT=$(kubectl get svc analytics-app-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    EXTERNAL_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    
    log_info "✅ Deployment completed successfully!"
    log_info "🌐 Application accessible at: http://${EXTERNAL_IP}:${NODE_PORT}"
    log_info "🌐 Direct access: http://<node-ip>:30008"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    # Wait a bit for application to start
    sleep 30
    
    # Check if pods are running
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-app --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [[ "$RUNNING_PODS" -ge 2 ]]; then
        log_info "✅ Health check passed: $RUNNING_PODS pods running"
    else
        log_warn "⚠️  Health check warning: Only $RUNNING_PODS pods running"
    fi
}


# Main execution
main() {
    log_info "=== Analytics App Deployment Script ==="
    
    check_prerequisites
    build_and_push_image
    deploy_to_kubernetes
    health_check
    
    log_info "🎉 Deployment process completed!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
