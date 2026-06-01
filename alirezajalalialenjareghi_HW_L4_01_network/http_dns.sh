sudo timeout 30 tcpdump -i any -nn 'tcp port 80' -w http_80.pcap
sudo timeout 30 tcpdump -i any -nn 'port 53' -w dns.pcap
