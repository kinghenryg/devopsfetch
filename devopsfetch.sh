#!/bin/bash

# Set strict mode
set -euo pipefail

# Define log file and max size
readonly LOG_FILE="/var/log/devopsfetch.log"
readonly MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10 MB

# Prettytable characters and colors
readonly _prettytable_char_top_left="┌"
readonly _prettytable_char_horizontal="─"
readonly _prettytable_char_vertical="│"
# ... (other character definitions)
readonly _prettytable_color_none="0"

# Prettytable functions
function _prettytable_prettify_lines() {
    sed -e "s@^@${_prettytable_char_vertical}@;s@\$@ ${_prettytable_char_vertical}@;s@	@ ${_prettytable_char_vertical} @g"
}

function _prettytable_fix_border_lines() {
    sed -e "1s@ @${_prettytable_char_horizontal}@g;3s@ @${_prettytable_char_horizontal}@g;\$s@ @${_prettytable_char_horizontal}@g"
}

function _prettytable_colorize_lines() {
    local color="$1"
    local range="$2"
    local ansicolor
    ansicolor="$(eval "echo \${_prettytable_color_${color}}")"

    sed -e "${range}s@\\([^${_prettytable_char_vertical}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${_prettytable_color_none}m@g"
}

function prettytable() {
    local cols="${1}"
    local color="${2:-none}"
    local input
    input="$(cat -)"
    local header
    header="$(echo -e "${input}"|head -n1)"
    local body
    body="$(echo -e "${input}"|tail -n+2)"
    
    # ... (rest of the prettytable function)
}

# Function to display help information
function display_help() {
    cat << EOF
Usage: devopsfetch [OPTION]...
Retrieve and display system information

Options:
  -p, --port [PORT]     Display active ports or specific port info
  -d, --docker [NAME]   Display Docker images/containers or specific container info
  -n, --nginx [DOMAIN]  Display Nginx domains or specific domain config
  -u, --users [USER]    Display user logins or specific user info
  -t, --time RANGE      Display activities within specified time range
  -h, --help            Display this help message
EOF
}

# Function to log activities to a file
function log_activity() {
    local log_entry="$1"

    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi

    # Rotate log file if it exceeds max size
    if [[ "$(stat -c %s "$LOG_FILE")" -gt "$MAX_LOG_SIZE" ]]; then
        sudo mv "$LOG_FILE" "${LOG_FILE}.old"
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi

    # Append log entry
    echo "$(date): $log_entry" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Function to get port information
function get_port_info() {
    local port="$1"

    if [[ -z "$port" ]]; then
        echo "Active ports, services, and processes:"
        (
            printf "%-10s %-10s %-20s %-20s\n" "SERVICE" "PORT" "STATE" "PID"
            sudo lsof -i -P -n | grep LISTEN | awk '{split($9,a,":"); printf "%-10s %-10s %-20s %-20s\n", $1, a[length(a)], $10, $2 "/" $1}'
        ) | prettytable 4
    else
        echo "Information for port $port:"
        (
            printf "%-10s %-10s %-20s %-20s\n" "SERVICE" "PORT" "STATE" "PID"
            ss -tuln | grep ":$port " | while read -r line; do
                local protocol port state pid program
                protocol=$(echo "$line" | awk '{print $1}')
                port=$(echo "$line" | awk '{split($4,a,":"); print a[length(a)]}')
                state=$(echo "$line" | awk '{print $2}')

                pid=$(sudo lsof -i :"$port" -sTCP:LISTEN -t -n -P 2>/dev/null)
                if [[ -n "$pid" ]]; then
                    program=$(ps -p "$pid" -o comm=)
                else
                    program="N/A"
                fi

                printf "%-10s %-10s %-20s %-20s\n" "$protocol" "$port" "$state" "$program"
            done
        ) | prettytable 4
    fi
}

# ... (other functions like get_docker_info, get_nginx_info, get_user_info, display_time_range_activities)

# Main execution
function main() {
    if [[ $# -eq 0 ]]; then
        display_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                shift
                get_port_info "$1"
                ;;
            -d|--docker)
                shift
                get_docker_info "$1"
                ;;
            -n|--nginx)
                shift
                get_nginx_info "$1"
                ;;
            -u|--users)
                shift
                get_user_info "$1"
                ;;
            -t|--time)
                shift
                display_time_range_activities "$1"
                ;;
            -h|--help)
                display_help
                ;;
            *)
                echo "Invalid option: $1" >&2
                display_help
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"