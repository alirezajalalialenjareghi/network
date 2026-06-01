#!/bin/bash

# --- Configuration ---
# Replace 'YOUR_SERVER_ADDRESS' with the actual IP address or hostname of the server.
SERVER_ADDRESS="YOUR_SERVER_ADDRESS"

# Define the ports to check along with their descriptions
declare -A PORTS_TO_CHECK
PORTS_TO_CHECK=(
    [HTTP]="80"
    [SSH]="22"
    [MySQL]="3306"
)
# --- End Configuration ---

echo "--- Port Connectivity Test Script ---"
echo "Target Server: $SERVER_ADDRESS"
echo "-------------------------------------"

# Function to check a single port
check_port() {
    local port_name="$1"
    local port_number="$2"
    local timeout=2 # Timeout in seconds for telnet connection attempt

    echo -n "Checking $port_name (Port $port_number)... "

    # Use timeout command to limit telnet execution time
    # The output of telnet is redirected to /dev/null to keep the script output clean
    # We check the exit status of the timeout command
    if timeout $timeout bash -c "echo > /dev/null" | telnet "$SERVER_ADDRESS" "$port_number" > /dev/null 2>&1; then
        echo "✅ Available"
        return 0 # Success
    else
        echo "❌ Not Available"
        return 1 # Failure
    fi
}

# Loop through all ports defined in the associative array
all_available=true
for name in "${!PORTS_TO_CHECK[@]}"; do
    port=${PORTS_TO_CHECK[$name]}
    if ! check_port "$name" "$port"; then
        all_available=false
    fi
done

echo "-------------------------------------"

if [ "$all_available" = true ]; then
    echo "All specified ports are reachable."
else
    echo "Some ports were not reachable. Please check the output above."
fi

exit 0
