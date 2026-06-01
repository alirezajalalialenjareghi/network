#!/usr/bin/env bash

# === تنظیمات ===
INTERVAL=5
LOG_FILE="monitoring_log.txt"
TOP_N_IPS=5

log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

get_interface_stats() {
    ip -s link show | awk '
        /^[0-9]+: / { interface = $2; sub(":", "", interface) }
        /RX: bytes/ { rx_bytes = $2; rx_packets = $3; rx_errors = $4; rx_dropped = $5 }
        /TX: bytes/ { tx_bytes = $2; tx_packets = $3; tx_errors = $4; tx_dropped = $5;
            if (interface != "") {
                print interface, rx_bytes, rx_packets, rx_errors, rx_dropped, tx_bytes, tx_packets, tx_errors, tx_dropped
            }
            interface = ""
        }
    '
}

format_bytes() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes} B"
    elif (( bytes < 1024*1024 )); then
        echo "$((bytes / 1024)) KB"
    elif (( bytes < 1024*1024*1024 )); then
        echo "$((bytes / (1024*1024))) MB"
    else
        echo "$((bytes / (1024*1024*1024))) GB"
    fi
}

calculate_bandwidth() {
    local current_stats="$1"
    local prev_stats="$2"
    local current_time=$(date +%s)
    local prev_time=$3

    local total_rx_bytes=0
    local total_tx_bytes=0

    while read -r interface rx_bytes rx_packets rx_errors rx_dropped tx_bytes tx_packets tx_errors tx_dropped; do
        local prev_rx_bytes=$(echo "$prev_stats" | awk -v iface="$interface" '$1 == iface {print $2}')
        local prev_tx_bytes=$(echo "$prev_stats" | awk -v iface="$interface" '$1 == iface {print $6}')

        [[ -z "$prev_rx_bytes" ]] && prev_rx_bytes=0
        [[ -z "$prev_tx_bytes" ]] && prev_tx_bytes=0

        local diff_rx_bytes=$((rx_bytes - prev_rx_bytes))
        local diff_tx_bytes=$((tx_bytes - prev_tx_bytes))

        (( diff_rx_bytes < 0 )) && diff_rx_bytes=0
        (( diff_tx_bytes < 0 )) && diff_tx_bytes=0

        total_rx_bytes=$((total_rx_bytes + diff_rx_bytes))
        total_tx_bytes=$((total_tx_bytes + diff_tx_bytes))
    done <<< "$current_stats"

    local time_diff=$((current_time - prev_time))
    (( time_diff == 0 )) && time_diff=1

    local rx_bps=$((total_rx_bytes * 8 / time_diff))
    local tx_bps=$((total_tx_bytes * 8 / time_diff))

    log_message "--- Bandwidth Usage ---"
    log_message "Download: $(format_bytes "$rx_bps")/s"
    log_message "Upload:   $(format_bytes "$tx_bps")/s"
}

count_active_connections() {
    local count
    count=$(ss -tn state established | tail -n +2 | wc -l)
    log_message "Active connections: $count"
}

get_top_traffic_ips() {
    log_message "--- Top $TOP_N_IPS IP addresses ---"
    ss -tnp state established 2>/dev/null | awk '
        NR > 1 {
            for (i=1; i<=NF; i++) {
                if ($i == "src") src = $(i+1)
                if ($i == "dst") dst = $(i+1)
            }
            if (src != "") src_count[src]++
            if (dst != "") dst_count[dst]++
        }
        END {
            for (ip in src_count) print ip, src_count[ip]
            for (ip in dst_count) print ip, dst_count[ip]
        }
    ' | sort -k2 -nr | head -n "$TOP_N_IPS" | tee -a "$LOG_FILE"
}

prev_stats=$(get_interface_stats)
prev_time=$(date +%s)

while true; do
    log_message "--- Network Interface Statistics ---"
    current_stats=$(get_interface_stats)
    echo "$current_stats" | awk '{
        printf "Interface: %-10s RX: %-15s TX: %-15s Errors(RX/TX): %-10s Dropped(RX/TX): %-10s\n", $1, $2, $6, $4"/"$8, $5"/"$9
    }' | tee -a "$LOG_FILE"

    calculate_bandwidth "$current_stats" "$prev_stats" "$prev_time"
    count_active_connections
    get_top_traffic_ips

    prev_stats="$current_stats"
    prev_time=$(date +%s)

    sleep "$INTERVAL"
done
