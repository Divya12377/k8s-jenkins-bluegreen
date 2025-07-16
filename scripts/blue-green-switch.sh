
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to switch traffic
switch_traffic() {
    local color=$1
    local other_color=$2
    
    print_status "Switching traffic to $color environment..."
    
    kubectl annotate ingress/nodejs-app \
        alb.ingress.kubernetes.io/actions.blue-green="{
            \"type\":\"forward\",
            \"forwardConfig\":{
                \"targetGroups\":[
                    {\"serviceName\":\"nodejs-app-$color\",\"servicePort\":80,\"weight\":100},
                    {\"serviceName\":\"nodejs-app-$other_color\",\"servicePort\":80,\"weight\":0}
                ]
            }
        }" --overwrite
    
    print_status "Traffic switched to $color environment"
}

# Function to test deployment
test_deployment() {
    local color=$1
    print_status "Testing $color deployment..."
    
    # Get a pod from the specified color
    local pod=$(kubectl get pods -l app=nodejs-app,version=$color -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod" ]; then
        print_error "No pods found for $color environment"
        return 1
    fi
    
    # Test health endpoint
    kubectl exec $pod -- curl -s -f http://localhost:3000/health > /dev/null
    if [ $? -eq 0 ]; then
        print_status "$color environment health check passed"
        return 0
    else
        print_error "$color environment health check failed"
        return 1
    fi
}

# Function to get current active environment
get_active_environment() {
    local annotation=$(kubectl get ingress nodejs-app -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.blue-green}')
    if echo "$annotation" | grep -q '"serviceName":"nodejs-app-blue","servicePort":80,"weight":100'; then
        echo "blue"
    elif echo "$annotation" | grep -q '"serviceName":"nodejs-app-green","servicePort":80,"weight":100'; then
        echo "green"
    else
        echo "unknown"
    fi
}

# Function to scale deployment
scale_deployment() {
    local color=$1
    local replicas=$2
    
    print_status "Scaling $color deployment to $replicas replicas..."
    kubectl scale deployment nodejs-app-$color --replicas=$replicas
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/nodejs-app-$color
    print_status "$color deployment scaled to $replicas replicas"
}

# Function for gradual traffic switching
gradual_switch() {
    local from_color=$1
    local to_color=$2
    local steps=${3:-5}
    
    print_status "Starting gradual traffic switch from $from_color to $to_color in $steps steps..."
    
    for i in $(seq 1 $steps); do
        local to_weight=$((i * 100 / steps))
        local from_weight=$((100 - to_weight))
        
        print_status "Step $i/$steps: $from_color=$from_weight%, $to_color=$to_weight%"
        
        kubectl annotate ingress/nodejs-app \
            alb.ingress.kubernetes.io/actions.blue-green="{
                \"type\":\"forward\",
                \"forwardConfig\":{
                    \"targetGroups\":[
                        {\"serviceName\":\"nodejs-app-$from_color\",\"servicePort\":80,\"weight\":$from_weight},
                        {\"serviceName\":\"nodejs-app-$to_color\",\"servicePort\":80,\"weight\":$to_weight}
                    ]
                }
            }" --overwrite
        
        # Wait between steps
        sleep 30
        
        # Test the deployment
        if ! test_deployment $to_color; then
            print_error "Health check failed during gradual switch. Rolling back..."
            switch_traffic $from_color $to_color
            return 1
        fi
    done
    
    print_status "Gradual switch completed successfully"
}

# Main script logic
main() {
    local action=${1:-status}
    local target_color=$2
    
    case $action in
        "status")
            current=$(get_active_environment)
            print_status "Current active environment: $current"
            ;;
        "switch")
            if [ -z "$target_color" ]; then
                print_error "Please specify target color (blue/green)"
                exit 1
            fi
            
            current=$(get_active_environment)
            if [ "$current" == "$target_color" ]; then
                print_warning "$target_color is already active"
                exit 0
            fi
            
            other_color="blue"
            if [ "$target_color" == "blue" ]; then
                other_color="green"
            fi
            
            # Scale up target environment
            scale_deployment $target_color 3
            
            # Test target environment
            if test_deployment $target_color; then
                switch_traffic $target_color $other_color
                
                # Scale down old environment after successful switch
                sleep 60
                scale_deployment $other_color 0
                
                print_status "Successfully switched to $target_color environment"
            else
                print_error "Pre-switch health check failed. Aborting switch."
                scale_deployment $target_color 0
                exit 1
            fi
            ;;
        "gradual")
            if [ -z "$target_color" ]; then
                print_error "Please specify target color (blue/green)"
                exit 1
            fi
            
            current=$(get_active_environment)
            if [ "$current" == "$target_color" ]; then
                print_warning "$target_color is already active"
                exit 0
            fi
            
            other_color="blue"
            if [ "$target_color" == "blue" ]; then
                other_color="green"
            fi
            
            # Scale up target environment
            scale_deployment $target_color 3
            
            # Perform gradual switch
            if gradual_switch $current $target_color; then
                # Scale down old environment
                sleep 60
                scale_deployment $other_color 0
                print_status "Gradual switch to $target_color completed successfully"
            else
                print_error "Gradual switch failed"
                exit 1
            fi
            ;;
        "rollback")
            current=$(get_active_environment)
            if [ "$current" == "blue" ]; then
                target_color="green"
            elif [ "$current" == "green" ]; then
                target_color="blue"
            else
                print_error "Cannot determine current environment for rollback"
                exit 1
            fi
            
            print_warning "Rolling back from $current to $target_color"
            
            # Scale up target environment
            scale_deployment $target_color 3
            
            # Switch traffic immediately for rollback
            switch_traffic $target_color $current
            
            # Scale down old environment
            sleep 30
            scale_deployment $current 0
            
            print_status "Rollback to $target_color completed"
            ;;
        "test")
            if [ -z "$target_color" ]; then
                print_error "Please specify color to test (blue/green)"
                exit 1
            fi
            
            if test_deployment $target_color; then
                print_status "$target_color environment test passed"
            else
                print_error "$target_color environment test failed"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {status|switch|gradual|rollback|test} [blue|green]"
            echo ""
            echo "Commands:"
            echo "  status                    - Show current active environment"
            echo "  switch <color>           - Instant switch to specified environment"
            echo "  gradual <color>          - Gradual switch to specified environment"
            echo "  rollback                 - Rollback to previous environment"
            echo "  test <color>             - Test specified environment health"
            echo ""
            echo "Examples:"
            echo "  $0 status"
            echo "  $0 switch green"
            echo "  $0 gradual blue"
            echo "  $0 rollback"
            echo "  $0 test green"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

