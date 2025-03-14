#!/bin/bash
################################################################################
# gluetun.sh
#
# Description:
#   A Bash script to run the gluetun Docker container as either an HTTP or a
#   Socks5 proxy. In HTTP mode, the container exposes an HTTP proxy on a given
#   port. In Socks5 mode, the container runs a Shadowsocks server on a random
#   host port while sslocal connects to it and listens on a specified local port.
#
#   The script also provides a "--clean" option to remove all gluetun Docker
#   containers and kill any running sslocal (Shadowsocks client) processes.
#
# Usage:
#   gluetun.sh http [-p <port>] [-c <country>]
#     - Starts an HTTP proxy using the specified port (default: 8888)
#     - The country option (-c) sets the server country (default: France)
#
#   gluetun.sh socks5 [-p <port>] [-c <country>]
#     - Starts a Socks5 (Shadowsocks) proxy.
#     - The Docker container's Shadowsocks server is exposed on a random host port.
#     - sslocal connects to this random port and listens locally on the port
#       specified by -p (default: 1080).
#     - The script tests the proxy by fetching the public IP via curl.
#
#   gluetun.sh --clean
#     - Cleans up any running gluetun Docker containers and Shadowsocks clients.
#
# Requirements:
#   - Docker must be installed and running.
#   - OpenSSL must be installed for generating a secure Shadowsocks password.
#   - sslocal (Shadowsocks client) must be installed and available in the PATH.
#
# Environment Variables:
#   - VPN_USER and VPN_PASSWORD must be set with your VPN credentials.
#   - Optionally, SHADOWSOCKS_CIPHER can be set. Defaults to "chacha20-ietf-poly1305".
#
################################################################################

gluetun() {

    # If the first argument is --clean, perform cleanup and exit.
    if [[ "$1" == "--clean" ]]; then
        echo "Cleaning up gluetun containers and Shadowsocks clients..."
        # Remove all Docker containers with names starting with "gluetun_"
        docker rm -f $(docker ps -a -q --filter "name=gluetun_") 2>/dev/null
        # Kill any sslocal processes that were started (matching the specific command line)
        pkill -f "sslocal -s" 2>/dev/null
        echo "Cleanup complete."
        return 0
    fi

    # Set sensitive information as variables
    local vpn_user="$VPN_USER"
    local vpn_password="$VPN_PASSWORD"
    # Generate a secure Shadowsocks password using OpenSSL
    local shadowsocks_password
    shadowsocks_password=$(openssl rand -base64 16)
    # Use a default cipher if not provided via environment variable
    local shadowsocks_cipher="${SHADOWSOCKS_CIPHER:-chacha20-ietf-poly1305}"

    # Default values for options
    local proxy_type=""
    local port_http=8888   # Default HTTP port
    local port_socks5=1080 # Default local port for the Shadowsocks client
    local country="France" # Default country

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            http|socks5)
                proxy_type="$1"
                ;;
            -p|--port)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    if [[ "$proxy_type" == "http" ]]; then
                        port_http="$2"
                    elif [[ "$proxy_type" == "socks5" ]]; then
                        port_socks5="$2"
                    fi
                    shift
                else
                    echo "Error: -p|--port requires a valid number"
                    return 1
                fi
                ;;
            -c|--country)
                if [[ -n "$2" ]]; then
                    country="$2"
                    shift
                else
                    echo "Error: -c|--country requires a value"
                    return 1
                fi
                ;;
            *)
                echo "Usage: gluetun <http|socks5> [-p <port>] [-c <country>]"
                echo "       gluetun --clean"
                return 1
                ;;
        esac
        shift
    done

    # Check if proxy_type is provided
    if [[ -z "$proxy_type" ]]; then
        echo "Error: Proxy type (http or socks5) is required."
        echo "Usage: gluetun <http|socks5> [-p <port>] [-c <country>]"
        return 1
    fi

    if [[ "$proxy_type" == "http" ]]; then
        docker run -d -it --rm --cap-add=NET_ADMIN --device /dev/net/tun \
            -e VPN_SERVICE_PROVIDER=nordvpn \
            -e OPENVPN_USER="$vpn_user" \
            -e OPENVPN_PASSWORD="$vpn_password" \
            -e SERVER_COUNTRIES="$country" \
            -e HTTPPROXY=on \
            -e HTTPPROXY_LOG=on \
            -p "${port_http}:8888/tcp" \
            --name "gluetun_http_${port_http}" \
            qmcgaw/gluetun

        echo "HTTP proxy running on port $port_http, country: $country"

    elif [[ "$proxy_type" == "socks5" ]]; then
        # Run the Docker container with random host port mapping for the Shadowsocks server.
        # Docker will automatically assign a free host port for container port 8388.
        docker run -itd --rm --cap-add=NET_ADMIN --device /dev/net/tun \
            -e VPN_SERVICE_PROVIDER=nordvpn \
            -e OPENVPN_USER="$vpn_user" \
            -e OPENVPN_PASSWORD="$vpn_password" \
            -e SERVER_COUNTRIES="$country" \
            -e SHADOWSOCKS=on \
            -e SHADOWSOCKS_LOG=on \
            -e SHADOWSOCKS_PASSWORD="$shadowsocks_password" \
            -e SHADOWSOCKS_CIPHER="$shadowsocks_cipher" \
            -p 8388/tcp -p 8388/udp \
            --name "gluetun_socks5" \
            qmcgaw/gluetun > /dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo "Error: Failed to start Docker container for socks5 proxy."
            return 1
        fi

        # Wait a few seconds to allow the container to start and assign its random port
        sleep 5

        # Retrieve the host port mapped to the container's port 8388/tcp.
        local host_port
        host_port=$(docker port gluetun_socks5 8388/tcp | awk -F: '{print $2}')
        if [[ -z "$host_port" ]]; then
            echo "Error: Could not retrieve the host port for the Shadowsocks server."
            return 1
        fi

        # Start sslocal to connect to the Shadowsocks server on the random host port.
        set +m
        sslocal -s 127.0.0.1 -p "$host_port" -l "$port_socks5" \
                 -k "$shadowsocks_password" -m "$shadowsocks_cipher" \
                 --fast-open > /dev/null 2>&1 &

        # Wait a few seconds for sslocal to initialize.
        sleep 5

        # Test the proxy by fetching the public IP via the socks5 proxy.
        local proxy_ip=""
        for i in {1..10}; do
            proxy_ip=$(curl --socks5 127.0.0.1:"$port_socks5" -s https://api.ipify.org)
            if [[ -n "$proxy_ip" ]]; then
                break
            fi
            sleep 1
        done

        if [[ -n "$proxy_ip" ]]; then
            echo "Socks5 client running on port socks5://localhost:$port_socks5"
            echo "IP: $proxy_ip"
        else
            echo "Error: The Socks5 proxy did not return a public IP address."
        fi
    else
        echo "Invalid proxy type. Use 'http' or 'socks5'."
        return 1
    fi
}

