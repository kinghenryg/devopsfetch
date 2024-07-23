#!/bin/bash

# Function to display help information
display_help() {
  echo "Usage: devopsfetch [OPTION]..."
  echo "Retrieve and display system information"
  echo
  echo "Options:"
  echo " -p, --port [PORT]  Display active ports or specific port info"
  echo " -d, --docker [NAME] Display Docker images/containers or specific container info"
  echo " -n, --nginx [DOMAIN] Display Nginx domains or specific domain config"
  echo " -u, --users [USER]  Display user logins or specific user info"
  echo " -t, --time RANGE   Display activities within specified time range"
  echo " -h, --help      Display this help message"
}

# Function to log activities to a file
log_activity() {
  local log_file="/var/log/devopsfetch.log"
  local max_size=$((10 * 1024 * 1024)) # 10 MB

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

# Function to format output as a table
format_table() {
    # Read header
    IFS=' ' read -ra header
    data=()

    # Calculate column widths
    declare -A widths
    for col in "${header[@]}"; do
        widths[$col]=${#col}
    done

    # Process data and update column widths
    while IFS=' ' read -ra row; do
        for i in "${!row[@]}"; do
            col="${header[$i]}"
            if [ ${#row[$i]} -gt ${widths[$col]} ]; then
                widths[$col]=${#row[$i]}
            fi
        done
        data+=("${row[@]}")
    done

    # Print top border
    printf '+'
    for col in "${header[@]}"; do
        printf -- '-%.0s' $(seq 1 $((${widths[$col]}+2)))
        printf '+'
    done
    printf '\n'

    # Print header
    for col in "${header[@]}"; do
        printf "| %-*s " ${widths[$col]} "$col"
    done
    printf '|\n'

    # Print separator
    printf '+'
    for col in "${header[@]}"]; do
        printf -- '-%.0s' $(seq 1 $((${widths[$col]}+2)))
        printf '+'
    done
    printf '\n'

    # Print data
    for ((i=0; i<${#data[@]}; i+=${#header[@]})); do
        for j in "${!header[@]}"; do
            printf "| %-*s " ${widths[${header[$j]}]} "${data[$i+$j]}"
        done
        printf '|\n'
    done

    # Print bottom border
    printf '+'
    for col in "${header[@]}"; do
        printf -- '-%.0s' $(seq 1 $((${widths[$col]}+2)))
        printf '+'
    done
    printf '\n'
}

# Function to get port information
get_port_info() {
  if [ -z "$1" ]; then
    echo "Active ports, services, and processes:"
    (
      printf "SERVICE PORT STATE PID\n"
      sudo lsof -i -P -n | grep LISTEN | awk '{split($9,a,":"); printf "%s %s %s %s\n", $1, a[length(a)], $10, $2 "/" $1}'
    ) | format_table
  else
    echo "Information for port $1:"
    (
      printf "SERVICE PORT STATE PID\n"
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

        printf "%s %s %s %s\n" "$protocol" "$port" "$state" "$program"
      done
    ) | format_table
  fi
}

# Function to get Docker information
get_docker_info() {
  if [ -z "$1" ]; then
    echo "Docker images:"
    (
      printf "Repository Tag ID Size\n"
      docker images --format "{{.Repository}} {{.Tag}} {{.ID}} {{.Size}}"
    ) | format_table
    echo -e "\nDocker containers:"
    (
      printf "Names Image Status Ports\n"
      docker ps --format "{{.Names}} {{.Image}} {{.Status}} {{.Ports}}"
    ) | format_table
  else
    echo "Information for container $1:"
    docker inspect "$1"
  fi
}

# Function to get Nginx information
get_nginx_info() {
  if [ -z "$1" ]; then
    echo "Nginx domains and ports:"
    (
      printf "Domain Port\n"
      grep -r server_name /etc/nginx/sites-enabled/ | 
      awk '{print $2}' | sed 's/;$//' | sort | uniq | 
      awk '{printf "%s 80\n", $1}'
    ) | format_table
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
      printf "User LoginTime SessionDuration\n"
      cut -d: -f1,3 /etc/passwd | awk -F: '$2 >= 1000 && $2 != 65534 {print $1}' | while read -r user; do
        last_login=$(last "$user" -1 2>/dev/null | awk 'NR==1 {print $4, $5, $6, $7, $8, $9}')
        session_duration=$(last "$user" -1 2>/dev/null | awk 'NR==1 {print $10, $11, $12, $13, $14, $15, $16, $17}')
        if [ -n "$last_login" ]; then
          printf "%s %s %s\n" "$user" "$last_login" "$session_duration"
        else
          printf "%s Never_logged_in \n" "$user"
        fi
      done
    ) | format_table
  else
    echo "Information for user $1:"
    if id "$1" >/dev/null 2>&1; then
      if [ "$(id -u "$1")" -ge 1000 ] && [ "$(id -u "$1")" -ne 65534 ]; then
        id "$1"
        echo "Last login:"
        last "$1" -1 | head -n 1
      else
        echo "This is a system user, not a regular user."
      fi
    else
      echo "User $1 does not exist."
    fi
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

# Run the main function with provided arguments
main "$@"
