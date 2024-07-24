#!/usr/bin/env bash
####
# Copyright (c) 2016-2021
#   Jakob Westhoff <jakob@westhoffswelt.de>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  - Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#  - Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
####

# Table characters
declare -r CHAR_TOP_LEFT="┌"
declare -r CHAR_HORIZONTAL="─"
declare -r CHAR_VERTICAL="│"
declare -r CHAR_BOTTOM_LEFT="└"
declare -r CHAR_BOTTOM_RIGHT="┘"
declare -r CHAR_TOP_RIGHT="┐"
declare -r CHAR_VERTICAL_HORIZONTAL_LEFT="├"
declare -r CHAR_VERTICAL_HORIZONTAL_RIGHT="┤"
declare -r CHAR_VERTICAL_HORIZONTAL_TOP="┬"
declare -r CHAR_VERTICAL_HORIZONTAL_BOTTOM="┴"
declare -r CHAR_VERTICAL_HORIZONTAL="┼"

# Color codes
declare -r COLOR_BLUE="0;34"
declare -r COLOR_GREEN="0;32"
declare -r COLOR_CYAN="0;36"
declare -r COLOR_RED="0;31"
declare -r COLOR_PURPLE="0;35"
declare -r COLOR_YELLOW="0;33"
declare -r COLOR_GRAY="1;30"
declare -r COLOR_LIGHT_BLUE="1;34"
declare -r COLOR_LIGHT_GREEN="1;32"
declare -r COLOR_LIGHT_CYAN="1;36"
declare -r COLOR_LIGHT_RED="1;31"
declare -r COLOR_LIGHT_PURPLE="1;35"
declare -r COLOR_LIGHT_YELLOW="1;33"
declare -r COLOR_LIGHT_GRAY="0;37"
declare -r COLOR_BLACK="0;30"
declare -r COLOR_WHITE="1;37"
declare -r COLOR_NONE="0"

# Function to prettify lines with table borders
prettytable_prettify_lines() {
    sed -e "s@^@${CHAR_VERTICAL}@;s@\$@    @;s@    @   ${CHAR_VERTICAL}@g"
}

# Function to fix border lines
prettytable_fix_border_lines() {
    sed -e "1s@ @${CHAR_HORIZONTAL}@g;3s@ @${CHAR_HORIZONTAL}@g;\$s@ @${CHAR_HORIZONTAL}@g"
}

# Function to colorize table lines
prettytable_colorize_lines() {
    local color="$1"
    local range="$2"
    local ansicolor="$(eval "echo \${COLOR_${color}}")"
    sed -e "${range}s@\\([^${CHAR_VERTICAL}]\\{1,\\}\\)@"$'\E'"[${ansicolor}m\1"$'\E'"[${COLOR_NONE}m@g"
}

# Function to generate and display the table
prettytable() {
    local cols="$1"
    local color="${2:-none}"
    local input
    input=$(cat -)
    local header
    header=$(echo -e "${input}" | head -n1)
    local body
    body=$(echo -e "${input}" | tail -n+2)

    {
        # Top border
        echo -n "${CHAR_TOP_LEFT}"
        for i in $(seq 2 "${cols}"); do
            echo -ne "\t${CHAR_VERTICAL_HORIZONTAL_TOP}"
        done
        echo -e "\t${CHAR_TOP_RIGHT}"
        echo -e "${header}" | prettytable_prettify_lines
        # Header/Body delimiter
        echo -n "${CHAR_VERTICAL_HORIZONTAL_LEFT}"
        for i in $(seq 2 "${cols}"); do
            echo -ne "\t${CHAR_VERTICAL_HORIZONTAL}"
        done
        echo -e "\t${CHAR_VERTICAL_HORIZONTAL_RIGHT}"
        echo -e "${body}" | prettytable_prettify_lines
        # Bottom border
        echo -n "${CHAR_BOTTOM_LEFT}"
        for i in $(seq 2 "${cols}"); do
            echo -ne "\t${CHAR_VERTICAL_HORIZONTAL_BOTTOM}"
        done
        echo -e "\t${CHAR_BOTTOM_RIGHT}"
    } | column -t -s $'\t' | prettytable_fix_border_lines | prettytable_colorize_lines "${color}" "2"
}

# Log file setup
LOG_FILE="/var/log/devopsfetch.log"
if [[ ! -f "$LOG_FILE" ]]; then
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Display active ports and services
display_active_ports() {
    echo -e "Proto\tLocal Address\tForeign Address\tState\tPID/Program name" | cat - <(sudo netstat -tulpn | grep LISTEN | awk '{print $1"\t"$4"\t"$5"\t"$6"\t"$7}') | prettytable 5 cyan
}

# Get port info
get_port_info() {
    echo -e "State\tRecv-Q\tSend-Q\tLocal Address:Port\tPeer Address:Port" | cat - <(ss -tuln sport = ":$1" | tail -n +2 | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5}') | prettytable 5 green
}

# List Docker images
list_docker_images() {
    echo -e "REPOSITORY\tTAG\tIMAGE ID\tCREATED\tSIZE" | cat - <(docker images | tail -n +2) | prettytable 5 blue
}

# List Docker containers
list_docker_containers() {
    echo -e "CONTAINER ID\tIMAGE\tCOMMAND\tCREATED\tSTATUS\tPORTS\tNAMES" | cat - <(docker ps | tail -n +2) | prettytable 7 purple
}

# Get container info
get_container_info() {
    docker inspect "$1" | jq -r '.[] | {Id, Name, Image, State: .State.Status, IP: .NetworkSettings.IPAddress, Ports: .NetworkSettings.Ports}' | prettytable 6 yellow
}

# Display Nginx domains
display_nginx_domains() {
    echo -e "Server Name" | cat - <(sudo nginx -T | grep "server_name" | awk '{print $2}' | sort | uniq) | prettytable 1 light_blue
}

# Display Nginx domain info
display_nginx_domain_info() {
    echo "Configuration for domain: $1"
    grep -A 10 -B 10 "server_name $1" /etc/nginx/sites-available/* | prettytable 1 light_green
}

# List users
list_users() {
    echo -e "Username" | cat - <(awk -F':' '{ print $1}' /etc/passwd) | prettytable 1 light_cyan
}

# Display user last login times
display_user_last_log_in_time() {
    lastlog | prettytable 4 light_purple
}

# Fetch user info
fetch_user_info() {
    echo -e "Username\tUID\tGID\tHome\tShell" | cat - <(grep "^$1:" /etc/passwd | awk -F: '{print $1"\t"$3"\t"$4"\t"$6"\t"$7}') | prettytable 5 light_red
}

# Display time range info for a particular date
display_time_range_info_for_a_particular_date() {
    local start_date="$1"
    local end_date="$2"
    if [[ -z "$end_date" ]]; then
        end_date="$start_date"
    fi
    journalctl --since "$start_date 00:00:00" --until "$end_date 23:59:59" | prettytable 3 light_yellow
}

# Display help options
display_help_options() {
    cat <<EOF
Usage: $0 [options]
Options:
    -p, --port [PORT]       Display active ports and services or specific port info
    -d, --docker [NAME]     Display Docker images and containers or specific container info
    -n, --nginx [DOMAIN]    Display Nginx domains and ports or specific domain info
    -u, --users [USERNAME]  List users and their last login times or specific user info
    -t, --time DATE         Display logs for a specific date (format: YYYY-MM-DD)
    -m, --monitor           Enable continuous monitoring mode
    -h, --help              Show this help message
EOF
}

# Monitor system activities
monitor_system_activities() {
    while true; do
        clear
        echo "Monitoring System Activities..."
        display_active_ports
        list_docker_images
        list_docker_containers
        display_nginx_domains
        list_users
        sleep 60
    done
}

# Process command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -p|--port) shift
            if [[ "$#" -eq 1 ]]; then
                display_active_ports
                get_port_info "$1"
            else
                echo "Invalid argument for --port"
                exit 1
            fi
            ;;
        -d|--docker) shift
            if [[ "$#" -eq 1 ]]; then
                list_docker_images
                list_docker_containers
                get_container_info "$1"
            else
                echo "Invalid argument for --docker"
                exit 1
            fi
            ;;
        -n|--nginx) shift
            if [[ "$#" -eq 1 ]]; then
                display_nginx_domains
                display_nginx_domain_info "$1"
            else
                echo "Invalid argument for --nginx"
                exit 1
            fi
            ;;
        -u|--users) shift
            if [[ "$#" -eq 1 ]]; then
                list_users
                display_user_last_log_in_time
                fetch_user_info "$1"
            else
                echo "Invalid argument for --users"
                exit 1
            fi
            ;;
        -t|--time) shift
            if [[ "$#" -eq 1 ]]; then
                display_time_range_info_for_a_particular_date "$1"
            else
                echo "Invalid argument for --time"
                exit 1
            fi
            ;;
        -m|--monitor)
            monitor_system_activities
            ;;
        -h|--help)
            display_help_options
            ;;
        *)
            echo "Invalid option: $1"
            display_help_options
            exit 1
            ;;
    esac
    shift
done
