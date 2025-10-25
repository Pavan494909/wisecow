#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=80
LOG_FILE="/var/log/system_health.log"
ALERT_FLAG=false

# Create log directory if it doesn't exist
sudo mkdir -p /var/log

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

# Check CPU usage
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local cpu_usage_int=${cpu_usage%.*}
    
    echo "CPU Usage: ${cpu_usage}%"
    
    if [ "$cpu_usage_int" -gt "$CPU_THRESHOLD" ]; then
        log_message "🚨 ALERT: High CPU usage: ${cpu_usage}%"
        echo -e "${RED}🚨 ALERT: High CPU usage: ${cpu_usage}%${NC}"
        ALERT_FLAG=true
    elif [ "$cpu_usage_int" -gt 60 ]; then
        echo -e "${YELLOW}⚠️  WARNING: CPU usage is getting high: ${cpu_usage}%${NC}"
    else
        echo -e "${GREEN}✅ CPU usage is normal: ${cpu_usage}%${NC}"
    fi
}

# Check Memory usage
check_memory() {
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$(( (used_mem * 100) / total_mem ))
    
    echo "Memory Usage: ${memory_usage}%"
    
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        log_message "🚨 ALERT: High Memory usage: ${memory_usage}%"
        echo -e "${RED}🚨 ALERT: High Memory usage: ${memory_usage}%${NC}"
        ALERT_FLAG=true
    elif [ "$memory_usage" -gt 60 ]; then
        echo -e "${YELLOW}⚠️  WARNING: Memory usage is getting high: ${memory_usage}%${NC}"
    else
        echo -e "${GREEN}✅ Memory usage is normal: ${memory_usage}%${NC}"
    fi
}

# Check Disk usage
check_disk() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    echo "Disk Usage: ${disk_usage}%"
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        log_message "🚨 ALERT: High Disk usage: ${disk_usage}%"
        echo -e "${RED}🚨 ALERT: High Disk usage: ${disk_usage}%${NC}"
        ALERT_FLAG=true
    elif [ "$disk_usage" -gt 60 ]; then
        echo -e "${YELLOW}⚠️  WARNING: Disk usage is getting high: ${disk_usage}%${NC}"
    else
        echo -e "${GREEN}✅ Disk usage is normal: ${disk_usage}%${NC}"
    fi
}

# Check Running Processes
check_processes() {
    echo -e "\n📊 Top 5 CPU-consuming processes:"
    ps aux --sort=-%cpu | head -6 | awk '{print $2, $11, $3"%"}' | column -t
    
    echo -e "\n📊 Top 5 Memory-consuming processes:"
    ps aux --sort=-%mem | head -6 | awk '{print $2, $11, $4"%"}' | column -t
    
    local zombie_processes=$(ps aux | awk '{if ($8=="Z") print $2}')
    if [ -n "$zombie_processes" ]; then
        log_message "🚨 ALERT: Zombie processes detected: $zombie_processes"
        echo -e "${RED}🚨 ALERT: Zombie processes detected!${NC}"
        ALERT_FLAG=true
    fi
}

# Check System Load
check_load() {
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    local cpu_cores=$(nproc)
    local load_1min=$(echo $load_avg | awk '{print $1}')
    
    echo "System Load: $load_avg (1, 5, 15 min)"
    
    if (( $(echo "$load_1min > $cpu_cores" | bc -l) )); then
        log_message "🚨 ALERT: High system load: $load_avg"
        echo -e "${RED}🚨 ALERT: High system load: $load_avg${NC}"
        ALERT_FLAG=true
    fi
}

# Main monitoring function
main() {
    echo "========================================="
    echo "🖥️  SYSTEM HEALTH MONITOR"
    echo "========================================="
    echo "Monitoring started at: $(date)"
    echo "Thresholds - CPU: ${CPU_THRESHOLD}%, Memory: ${MEMORY_THRESHOLD}%, Disk: ${DISK_THRESHOLD}%"
    echo "========================================="
    
    check_cpu
    check_memory
    check_disk
    check_load
    check_processes
    
    echo "========================================="
    
    if [ "$ALERT_FLAG" = true ]; then
        log_message "❌ System health check completed with ALERTS"
        echo -e "${RED}❌ System health check completed with ALERTS${NC}"
        echo "Check detailed logs: $LOG_FILE"
        exit 1
    else
        log_message "✅ System health check completed - ALL SYSTEMS NORMAL"
        echo -e "${GREEN}✅ System health check completed - ALL SYSTEMS NORMAL${NC}"
        exit 0
    fi
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "System Health Monitoring Script"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help      Show this help message"
    echo "  -t, --threshold Set custom thresholds (format: cpu:mem:disk)"
    echo "  -l, --log       Specify custom log file"
    echo ""
    echo "EXAMPLE:"
    echo "  $0 --threshold 85:75:90 --log /tmp/health.log"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--threshold)
            IFS=':' read -r CPU_THRESHOLD MEMORY_THRESHOLD DISK_THRESHOLD <<< "$2"
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Check if bc is installed for floating point comparison
if ! command -v bc &> /dev/null; then
    echo "Installing bc for calculations..."
    sudo apt-get update && sudo apt-get install -y bc
fi

# Run main function
main
