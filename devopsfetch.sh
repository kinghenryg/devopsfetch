#!/bin/bash
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
# CAUsed AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVIsed OF THE POSSIBILITY OF SUCH DAMAGE.
####
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
# Escape codes
# Default colors
_prettytable_color_blue="0;34"
_prettytable_color_green="0;32"
_prettytable_color_cyan="0;36"
_prettytable_color_red="0;31"
_prettytable_color_purple="0;35"
_prettytable_color_yellow="0;33"
_prettytable_color_gray="1;30"
_prettytable_color_light_blue="1;34"
_prettytable_color_light_green="1;32"
_prettytable_color_light_cyan="1;36"
_prettytable_color_light_red="1;31"
_prettytable_color_light_purple="1;35"
_prettytable_color_light_yellow="1;33"
_prettytable_color_light_gray="0;37"
# Somewhat special colors
_prettytable_color_black="0;30"
_prettytable_color_white="1;37"
_prettytable_color_none="0"
function _prettytable_prettify_lines() {
    cat - | sed -e "s@^@${_prettytable_char_vertical}@;s@\$@    @;s@    @   ${_prettytable_char_vertical}@g"
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
if [ "$0" = "$BASH_SOURCE" ]; then
    # Execute function if called as a script instead of being sourced.
    prettytable $*
fi
LOG_FILE="/var/log/devopsfetch.log"
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
fi
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}
display_active_ports() {
    echo -e "Proto\tLocal Address\tForeign Address\tState\tPID/Program name" | cat - <(sudo netstat -tulpn | grep LISTEN | awk '{print $1"\t"$4"\t"$5"\t"$6"\t"$7}') | prettytable 5 cyan
}
get_port_info() {
    echo -e "State\tRecv-Q\tSend-Q\tLocal Address:Port\tPeer Address:Port" | cat - <(ss -tuln sport = ":$1" | tail -n +2 | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5}') | prettytable 5 green
}
list_docker_images() {
    echo -e "REPOSITORY\tTAG\tIMAGE ID\tCREATED\tSIZE" | cat - <(docker images | tail -n +2) | prettytable 5 blue
}
list_docker_containers() {
    echo -e "CONTAINER ID\tIMAGE\tCOMMAND\tCREATED\tSTATUS\tPORTS\tNAMES" | cat - <(docker ps | tail -n +2) | prettytable 7 purple
}
get_container_info() {
    docker inspect "$1" | jq -r '.[] | {Id, Name, Image, State: .State.Status, IP: .NetworkSettings.IPAddress, Ports: .NetworkSettings.Ports}' | prettytable 6 yellow
}
display_nginx_domains() {
    echo -e "Server Name" | cat - <(sudo nginx -T | grep "server_name" | awk '{print $2}' | sort | uniq) | prettytable 1 light_blue
}
display_nginx_domain_info() {
    echo "Configuration for domain: $1"
    grep -A 10 -B 10 "server_name $1" /etc/nginx/sites-available/* | prettytable 1 light_green
}
list_users() {
    echo -e "Username" | cat - <(awk -F':' '{ print $1}' /etc/passwd) | prettytable 1 light_cyan
}
display_user_last_log_in_time() {
    lastlog | prettytable 4 light_purple
}
fetch_user_info() {
    echo -e "Username\tUID\tGID\tHome\tShell" | cat - <(grep "^$1:" /etc/passwd | awk -F: '{print $1"\t"$3"\t"$4"\t"$6"\t"$7}') | prettytable 5 light_red
}
display_time_range_info_for_a_particular_date() {
    local start_date="$1"
    local end_date="$2"
    if [[ -z "$end_date" ]]; then
        end_date="$start_date"
    fi
    journalctl --since "$start_date 00:00:00" --until "$end_date 23:59:59" | prettytable 3 light_yellow
}
display_help_options() {
    echo "Usage: $0 [options]
Options:
    -p, --port [PORT]       Display active ports and services or specific port info
    -d, --docker [NAME]     Display Docker images and containers or specific container info
    -n, --nginx [DOMAIN]    Display Nginx domains and ports or specific domain info
    -u, --users [USERNAME]  List users and their last login times or specific user info
    -t, --time DATE         Display logs for a specific date (format: YYYY-MM-DD)
    -m, --monitor           Enable continuous monitoring mode
    -h, --help              Show this help message"
}
monitor() {
    while true; do
        log "Monitoring system activities..."
        log "Active Ports:"
        display_active_ports >> "$LOG_FILE"
        log "Docker Containers:"
        list_docker_containers >> "$LOG_FILE"
        log "Users and Last Logins:"
        display_user_last_log_in_time >> "$LOG_FILE"
        sleep 60
    done
}
main() {
    if [[ $# -eq 0 ]]; then
        display_help_options
        exit 1
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--port)
                if [[ -z "$2" || "$2" == -* ]]; then
                    display_active_ports
                else
                    get_port_info "$2"
                    shift
                fi
                ;;
            -d|--docker)
                if [[ -z "$2" || "$2" == -* ]]; then
                    list_docker_images
                    list_docker_containers
                else
                    get_container_info "$2"
                    shift
                fi
                ;;
            -n|--nginx)
                if [[ -z "$2" || "$2" == -* ]]; then
                    display_nginx_domains
                else
                    display_nginx_domain_info "$2"
                    shift
                fi
                ;;
            -u|--users)
                if [[ -z "$2" || "$2" == -* ]]; then
                    list_users
                    display_user_last_log_in_time
                else
                    fetch_user_info "$2"
                    shift
                fi
                ;;
            -t|--time)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Please provide a date or date range."
                    exit 1
                elif [[ -z "$3" || "$3" == -* ]]; then
                    display_time_range_info_for_a_particular_date "$2"
                else
                    display_time_range_info_for_a_particular_date "$2" "$3"
                    shift
                fi
                shift
                ;;
            -m|--monitor)
                monitor
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
}
main "$@"
