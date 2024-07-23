# devopsfetch
 The goal of this task is to create a monitoring tool called DevOpsFetch that retrieves and displays various system information. This tool will be designed to run as a systemd service, continuously monitoring and logging the system's state.

# DevOpsFetch

DevOpsFetch is a tool for DevOps that collects and displays system information, including active ports, user logins, Nginx configurations, Docker images, and container statuses.

## Installation

1. Clone the repository:
  
```console
   git clone https://github.com/yourusername/devopsfetch.git
   cd devopsfetch
```
2. Run the installation script:

    ```console
    sudo bash install.sh
    ```
    This will install the necessary dependencies, set up the DevOpsFetch script, and create a systemd service for continuous monitoring.

# Usage
DevOpsFetch can be used with the following command-line flags:

-p or --port [PORT]: Display active ports or specific port info
-d or --docker [NAME]: Display Docker images/containers or specific container info
-n or --nginx [DOMAIN]: Display Nginx domains or specific domain config
-u or --users [USER]: Display user logins or specific user info
-t or --time RANGE: Display activities within a specified time range
-h or --help: Display help message


# Some used cases:
Display all active ports:

```console
devopsfetch -p
```

Display information for a specific Docker container:

```console
devopsfetch -d my_container
```
Display Nginx configuration for a specific domain:
```console
devopsfetch -n domain.com
```

Display user information:

```console
devopsfetch -u henry
```

Display activities in the last hour:
```console
devopsfetch -t "1 hour ago"
```
Logging
DevOpsFetch logs all activities to /var/log/devopsfetch.log. The log file is automatically rotated when it reaches 10 MB in size.

To view the logs, use:

```console
sudo tail -f /var/log/devopsfetch.log
```
Continuous Monitoring
The DevOpsFetch systemd service runs continuously and logs system information every hour. To check the status of the service, use:
```console
sudo systemctl status devopsfetch.service
```

To view the continuous monitoring logs, use:
```console
sudo journalctl -u devopsfetch.service  
```  