#!/bin/bash

OUTPUT_FILE="txt.analysis_wiresha"
> "$OUTPUT_FILE"

echo "Starting PCAP analysis..." | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"

# Check tshark
if ! command -v tshark >/dev/null 2>&1; then
  echo "ERROR: tshark is not installed or not in PATH." | tee -a "$OUTPUT_FILE"
  exit 1
fi

# --- HTTP PCAP ---
echo "--- Analyzing http_80.pcap ---" | tee -a "$OUTPUT_FILE"

echo "Total TCP Conversations:" | tee -a "$OUTPUT_FILE"
tshark -r http_80.pcap -q -z conv,tcp 2>/dev/null | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "TCP Retransmissions:" | tee -a "$OUTPUT_FILE"
tshark -r http_80.pcap -Y "tcp.analysis.retransmission" -T fields \
  -e frame.number -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport \
  2>/dev/null | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "Count of TCP Retransmissions:" | tee -a "$OUTPUT_FILE"
tshark -r http_80.pcap -Y "tcp.analysis.retransmission" -T fields -e frame.number 2>/dev/null | wc -l | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "SYN-ACK Packets Count:" | tee -a "$OUTPUT_FILE"
tshark -r http_80.pcap -Y "tcp.flags.syn==1 and tcp.flags.ack==1" -T fields -e frame.number 2>/dev/null | wc -l | tee -a "$OUTPUT_FILE"

# --- DNS PCAP ---
echo "" | tee -a "$OUTPUT_FILE"
echo "--- Analyzing dns.pcap ---" | tee -a "$OUTPUT_FILE"

echo "Total DNS Queries:" | tee -a "$OUTPUT_FILE"
tshark -r dns.pcap -Y "dns.flags.response == 0" -T fields -e frame.number 2>/dev/null | wc -l | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "Unique Domains Queried:" | tee -a "$OUTPUT_FILE"
tshark -r dns.pcap -Y "dns.flags.response == 0" -T fields -e dns.qry.name 2>/dev/null | sort -u | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "DNS Query Details:" | tee -a "$OUTPUT_FILE"
tshark -r dns.pcap -Y "dns.flags.response == 0" -T fields \
  -e frame.number -e dns.qry.name -e dns.qry.type \
  2>/dev/null | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"
echo "PCAP analysis complete. Results saved to: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
