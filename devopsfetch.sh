#!/bin/bash

# Prettytable code

_prettytable_char_top_left="┌"
_prettytable_char_horizontal="─"
_prettytable_char_vertical="│"
_prettytable_char_bottom_left="└"
_prettytable_char_bottom_right="┘"
_prettytable_char_top_right="┐"
_prettytable_char_vertical_horizontal_left="├"
_prettytable_char_vertical_horizontal_right="┤"
_prettytable_char_vertical_horizontal_top="┬"
_prettytable_char_vertical_horizontal_bottom="┴"
_prettytable_char_vertical_horizontal="┼"

_prettytable_color_none="0"

function _prettytable_prettify_lines() {
    cat - | sed -e "s@^@${_prettytable_char_vertical}@;s@\$@	@;s@	@	${_prettytable_char_vertical}@g"
}

function _prettytable_fix_border_lines() {
    cat - | sed -e "1s@ @${_prettytable_char_horizontal}@g;3s@ @${_prettytable_char_horizontal}@g;\$s@ @${_prettytable_char_horizontal}@g"
}

function _prettytable_colorize_lines() {
    local color="$1"
    local range="$2"
    local ansicolor="$(eval "echo \${_prettytable_color_${color}}")"

    cat - | sed -e "${range}s@\\([^${_prettytable_char_vertical}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${_prettytable_color_none}m@g"
}

function prettytable() {
    local cols="${1}"
    local color="${2:-none}"
    local input="$(cat -)"
    local header="$(echo -e "${input}"|head -n1)"
    local body="$(echo -e "${input}"|tail -n+2)"
    {
        # Top border
        echo -n "${_prettytable_char_top_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_top}"
        done
        echo -e "\t${_prettytable_char_top_right}"

        echo -e "${header}" | _prettytable_prettify_lines

        # Header/Body delimiter
        echo -n "${_prettytable_char_vertical_horizontal_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal}"
        done
        echo -e "\t${_prettytable_char_vertical_horizontal_right}"

        echo -e "${body}" | _prettytable_prettify_lines

        # Bottom border
        echo -n "${_prettytable_char_bottom_left}"
        for i in $(seq 2 ${cols}); do
            echo -ne "\t${_prettytable_char_vertical_horizontal_bottom}"
        done
        echo -e "\t${_prettytable_char_bottom_right}"
    } | column -t -s $'\t' | _prettytable_fix_border_lines | _prettytable_colorize_lines "${color}" "2"
}

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
        (
            printf "%-10s %-10s %-20s %-20s\n" "SERVICE" "PORT" "STATE" "PID"
            sudo lsof -i -P -n | grep LISTEN | awk '{split($9,a,":"); printf "%-10s %-10s %-20s %-20s\n", $1, a[length(a)], $10, $2 "/" $1}'
        ) | prettytable 4
    else
        echo "Information for port $1:"
        (
            printf "%-10s %-10s %-20s %-20s\n" "SERVICE" "PORT" "STATE" "PID"
            ss -tuln | grep ":$1 " | while read -r line; do
                protocol=$(echo "$line" | awk '{print $1}')
                port=$(echo "$line" | awk '{split($4,a,":"); print a[length(a)]}')
                state=$(echo "$line" | awk '{print $2}')

                pid=$(sudo lsof -i :$1 -sTCP:LISTEN -t -n -P 2>/dev/null)
                if [ -n "$pid" ]; then
                    program=$(ps -p "$pid" -o comm=)
                else
                    program="N/A"
                fi

                printf "%-10s %-10s %-20s %-20s\n" "$protocol" "$port" "$state" "$program"
            done
        ) | prettytable 4
    fi
}

# Function to get Docker information
get_docker_info() {
    if [ -z "$1" ]; then
        echo "Docker images:"
        (
            printf "%-30s %-20s %-20s %-15s\n" "Repository" "Tag" "ID" "Size"
            docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | 
            awk '{printf "%-30s %-20s %-20s %-15s\n", $1, $2, $3, $4}'
        ) | prettytable 4
        echo -e "\nDocker containers:"
        (
            printf "%-20s %-30s %-20s %-30s\n" "Names" "Image" "Status" "Ports"
            docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | 
            awk '{printf "%-20s %-30s %-20s %-30s\n", $1, $2, $3, $4}'
        ) | prettytable 4
    else
        echo "Information for container $1:"
        docker inspect "$1" | jq '.[] | {Name: .Name, Image: .Config.Image, State: .State.Status, Ports: .NetworkSettings.Ports}'
    fi
}

# Function to get Nginx information
get_nginx_info() {
    if [ -z "$1" ]; then
        echo "Nginx domains and ports:"
        (
            printf "%-30s %-10s\n" "Domain" "Port"
            grep -r server_name /etc/nginx/sites-enabled/ | 
            awk '{print $2}' | sed 's/;$//' | sort | uniq | 
            awk '{printf "%-30s %-10s\n", $1, "80"}'
        ) | prettytable 2
    else
        echo "Configuration for domain $1:"
        grep -r -A 20 "server_name $1" /etc/nginx/sites-enabled/
    fi
}

# Function to get user information
get_user_info() {
    if [ -z "$1" ]; then
        echo "Regular users and last login times:"
        (
            printf "%-15s %-20s %-15s\n" "User" "Login Time" "Session Duration"
            cut -d: -f1,3 /etc/passwd | awk -F: '$2 >= 1000 && $2 != 65534 {print $1}' | while read -r user; do
                last_login=$(last "$user" -1 2>/dev/null | awk 'NR==1 {print $4, $5, $6, $7, $8, $9}')
                session_duration=$(last "$user" -1 2>/dev/null | awk 'NR==1 {print $10, $11, $12, $13, $14, $15, $16, $17}')
                if [ -n "$last_login" ]; then
                    printf "%-15s %-20s %-15s\n" "$user" "$last_login" "$session_duration"
                else
                    printf "%-15s %-20s %-15s\n" "$user" "Never logged in" "-"
                fi
            done
        ) | prettytable 3
    else
        echo "Last login time for user $1:"
        (
            printf "%-20s %-20s\n" "Login Time" "Session Duration"
            last "$1" -1 2>/dev/null | awk 'NR==1 {printf "%-20s %-20s\n", $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17}'
        ) | prettytable 2
    fi
}

# Function to display activities within a time range
display_time_range_activities() {
    local start_time="$1"
    local end_time="$2"

    echo "Activities from $start_time to $end_time:"
    (
        printf "%-20s %-10s %-10s %-20s\n" "Time" "Level" "PID" "Message"
        journalctl --since "$start_time" --until "$end_time" | tail -n 100 | awk '{printf "%-20s %-10s %-10s %-20s\n", $1 " " $2, $4, $6, $7}'
    ) | prettytable 4
}

# Parse command-line options
while [ "$1" != "" ]; do
    case "$1" in
        -p | --port)
            shift
            get_port_info "$1"
            exit 0
            ;;
        -d | --docker)
            shift
            get_docker_info "$1"
            exit 0
            ;;
        -n | --nginx)
            shift
            get_nginx_info "$1"
            exit 0
            ;;
        -u | --users)
            shift
            get_user_info "$1"
            exit 0
            ;;
        -t | --time)
            shift
            if [ -z "$1" ] || [ -z "$2" ]; then
                echo "Please provide both start and end times."
                exit 1
            fi
            display_time_range_activities "$1" "$2"
            exit 0
            ;;
        -h | --help)
            display_help
            exit 0
            ;;
        *)
            echo "Invalid option: $1"
            display_help
            exit 1
            ;;
    esac
    shift
done

# If no options were provided, display help
display_help
exit 0
