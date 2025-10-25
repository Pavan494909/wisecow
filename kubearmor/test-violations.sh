#!/bin/bash
echo "🧪 Testing KubeArmor Policy Violations..."

# Get a wisecow pod
POD_NAME=$(kubectl get pods -l app=wisecow -o name | head -1 | cut -d'/' -f2)
echo "Testing on pod: $POD_NAME"

echo ""
echo "🔍 Checking KubeArmor status..."
kubectl get kubearmorpolicies

echo ""
echo "1. Testing blocked process executions..."
echo "========================================"

# Test blocked processes - these should be blocked
BLOCKED_COMMANDS=(
    "ls /"
    "cat /etc/passwd"
    "wget --help"
    "curl --help"
    "ps aux"
    "top -n 1"
    "mkdir /tmp/test123"
    "rm -rf /tmp/test123"
    "whoami"
    "pwd"
)

for cmd in "${BLOCKED_COMMANDS[@]}"; do
    echo "❌ Testing blocked command: $cmd"
    kubectl exec -it $POD_NAME -- bash -c "timeout 2 $cmd" 2>&1 | head -3
    echo "---"
    sleep 1
done

echo ""
echo "2. Testing allowed operations..."
echo "================================"

# Test allowed operations - these should work
ALLOWED_COMMANDS=(
    "cowsay 'Hello KubeArmor'"
    "fortune"
    "echo 'Testing allowed commands'"
    "nc -h 2>&1 | head -2"
)

for cmd in "${BLOCKED_COMMANDS[@]}"; do
    echo "✅ Testing allowed command: $cmd"
    kubectl exec -it $POD_NAME -- bash -c "timeout 2 $cmd" 2>&1 | head -2
    echo "---"
    sleep 1
done

echo ""
echo "3. Testing file access violations..."
echo "===================================="

# Test blocked file access
BLOCKED_FILES=("/etc/passwd" "/etc/hosts" "/proc/cpuinfo" "/proc/meminfo")

for file in "${BLOCKED_FILES[@]}"; do
    echo "❌ Testing blocked file: $file"
    kubectl exec -it $POD_NAME -- bash -c "cat $file 2>&1 | head -2" || echo "Blocked!"
    echo "---"
    sleep 1
done
