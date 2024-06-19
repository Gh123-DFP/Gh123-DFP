#!/bin/bash

get_device_type() {
    read -p "Enter the type of device (website, server, router, machine): " device_type
    echo "$device_type"
}

get_ip_address() {
    read -p "Enter the IP address: " ip_address
    echo "$ip_address"
}

ping_ip_address() {
    ping -c 1 "$1" > /dev/null
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

nmap_scan() {
    if [ ! -x /usr/bin/nmap ]; then
        echo "Error: nmap is not installed. Please install nmap and try again."
        exit 1
    fi
    vulnerable_ports="21,22,23,25,53,80,110,111,135,139,143,445,993,995,1723,3306,3389,5900,8080"
    nmap_command="nmap -sV -O -p $vulnerable_ports $1"
    echo "Running nmap scan: $nmap_command"
    output=$(nmap -sV -O -p $vulnerable_ports $1)
    echo "$output"
}

parse_nmap_output() {
    open_ports=()
    while IFS= read -r line; do
        if echo "$line" | grep -q "open"; then
            port_info=($line)
            port_number=${port_info[0]%/}
            protocol=${port_info[0]##*/}
            service_name=${port_info[2]}
            open_ports+=("$port_number ($protocol) - $service_name")
        fi
    done <<< "$1"
    echo "${open_ports[@]}"
}

ask_user_to_pick_port() {
    echo "Open ports found:"
    for ((i=0; i<${#open_ports[@]}; i++)); do
        echo "$((i+1)). ${open_ports[$i]}"
    done
    read -p "Enter the number of the port to scan for vulnerabilities: " choice
    echo "${open_ports[$((choice-1))]}"
}

ask_user_for_version() {
    read -p "Enter the version of the selected port: " version_info
    echo "$version_info"
}

msfconsole_scan() {
    if [ ! -x /usr/bin/msfconsole ]; then
        echo "Error: msfconsole is not installed. Please install msfconsole and try again."
        exit 1
    fi
    msf_command="msfconsole -x 'search $1 ; exit'"
    echo "Running msfconsole scan: $msf_command"
    output=$(msfconsole -x "search $1 ; exit")
    echo "$output"
}

main() {
    device_type=$(get_device_type)
    ip_address=$(get_ip_address)
    if ping_ip_address "$ip_address"; then
        nmap_output=$(nmap_scan "$ip_address")
        echo "Nmap output:"
        echo "$nmap_output"
        open_ports=($(parse_nmap_output "$nmap_output"))
        if [ ${#open_ports[@]} -eq 0 ]; then
            echo "No open ports found."
            exit 1
        fi
        port_to_scan=$(ask_user_to_pick_port)
        port_number=$(echo "$port_to_scan" | cut -d' 'f1)
        protocol=$(echo "$port_to_scan" | cut -d' 'f2)
        service_name=$(echo "$port_to_scan" | cut -d' 'f4-)
        echo "You selected port $port_number ($protocol) - $service_name"
        version_info=$(ask_user_for_version)
        msf_output=$(msfconsole_scan "$version_info")
        echo "MSFconsole output:"
        echo "$msf_output"
    else
        echo "Error: The IP address is not reachable. Please try again or exit."
        exit 1
    fi
}

main
