#!/bin/bash

# Function to display help information
display_help() {
    echo "Usage: devopsfetch [OPTION]..."
    echo "Retrieve and display system information"
    echo
    echo "Options:"
    echo "  -p, --port [PORT]     Display active ports or specific port info"
    echo "  -d, --docker [NAME]   Display Docker images/containers or specific container info"
    echo "  -n, --nginx [DOMAIN]  Display Nginx domains or specific domain config"
    echo "  -u, --users [USER]    Display user logins or specific user info"
    echo "  -t, --time RANGE      Display activities within specified time range"
    echo "  -h, --help            Display this help message"
}

# Function to log activities to a file
log_activity() {
    local log_file="/var/log/devopsfetch.log"
    local max_size=$((10 * 1024 * 1024))  # 10 MB

    # Create log file if it doesn't exist
    if [ ! -f "$log_file" ]; then
        sudo touch "$log_file"
        sudo chmod 644 "$log_file"
    fi

    # Rotate log file if it exceeds max size
    if [ "$(stat -c %s "$log_file")" -gt "$max_size" ]; then
        sudo mv "$log_file" "${log_file}.old"
        sudo touch "$log_file"
        sudo chmod 644 "$log_file"
    fi

    # Append log entry
    echo "$(date): $1" | sudo tee -a "$log_file"
}

# Function to get port information
get_port_info() {
    if [ -z "$1" ]; then
        echo "Active ports, services, and processes:"
        (echo "Protocol Local Address Foreign Address State PID/Program name";
         ss -tuln | tail -n +2 | while read line; do
             protocol=$(echo $line | awk '{print $1}')
             local_address=$(echo $line | awk '{print $4}')
             foreign_address=$(echo $line | awk '{print $5}')
             state=$(echo $line | awk '{print $6}')
             port=$(echo $local_address | cut -d: -f2)
             pid_program=$(sudo lsof -i :$port -sTCP:LISTEN -t -n -P 2>/dev/null | xargs -r ps -o comm= -p)
             echo "$protocol $local_address $foreign_address $state $pid_program"
         done) | format_table
    else
        echo "Information for port $1:"
        (echo "Protocol Local Address Foreign Address State PID/Program name";
         ss -tuln | grep ":$1 " | while read line; do
             protocol=$(echo $line | awk '{print $1}')
             local_address=$(echo $line | awk '{print $4}')
             foreign_address=$(echo $line | awk '{print $5}')
             state=$(echo $line | awk '{print $6}')
             pid_program=$(sudo lsof -i :$1 -sTCP:LISTEN -t -n -P 2>/dev/null | xargs -r ps -o comm= -p)
             echo "$protocol $local_address $foreign_address $state $pid_program"
         done) | format_table
    fi
}

# Function to get Docker information
get_docker_info() {
    if [ -z "$1" ]; then
        echo "Docker images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
        echo -e "\nDocker containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "Information for container $1:"
        docker inspect "$1"
    fi
}

# Function to get Nginx information
get_nginx_info() {
    if [ -z "$1" ]; then
        echo "Nginx domains and ports:"
        grep -r server_name /etc/nginx/sites-enabled/ | awk '{print $2}' | sed 's/;$//' | sort | uniq
    else
        echo "Configuration for domain $1:"
        grep -r -A 20 "server_name $1" /etc/nginx/sites-enabled/
    fi
}

# Function to get user information
get_user_info() {
    if [ -z "$1" ]; then
        echo "Users and last login times:"
        last | head -n -2
    else
        echo "Information for user $1:"
        id "$1"
        echo "Last login:"
        last "$1" | head -n 1
    fi
}

# Function to get time range information
get_time_range_info() {
    if [ -z "$1" ]; then
        echo "Please provide a time range (e.g., '1 hour ago')"
    else
        echo "Activities within $1:"
        journalctl --since "$1"
    fi
}

# Function to format output as a table
format_table() {
    column -t -s $'\t' | sed '1s/.*/ & /' | sed '1s/^/|/; 1s/$/|/; 2s/.*/&/; 2s/^/|/; 2s/$/|/; s/^/| /; s/$/ |/'
}

# Main function to handle command-line arguments
main() {
    log_activity "DevOpsFetch executed with arguments: $*"

    case "$1" in
        -p|--port)
            get_port_info "$2"
            ;;
        -d|--docker)
            get_docker_info "$2"
            ;;
        -n|--nginx)
            get_nginx_info "$2"
            ;;
        -u|--users)
            get_user_info "$2"
            ;;
        -t|--time)
            get_time_range_info "$2"
            ;;
        -h|--help)
            display_help
            ;;
        *)
            echo "Invalid option. Use -h or --help for usage information."
            exit 1
            ;;
    esac
}

# Infinite loop to keep the service running
while true; do
    main "$@"
    sleep 3600  # Sleep for an hour before running again
done