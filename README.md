# BadBox2 PCAP checker
Extract BB2 info from a larger set of data from Wireshark

## Quick How-To
1. Setup siloed VLAN
2. tcpdump the traffic to Wireshark
3. Export from Wireshark to CSV
4. Run the script

## Wireshark and TCP Dump
```bash
/Applications/Wireshark.app/Contents/MacOS/Wireshark -k -w /Volumes/T9/capture.pcap -i <(ssh root@192.168.1.3 -p 22 tcpdump -i br0.10 -U -w - )
```
This will stream all trafic from br0.10 (VLAN10) on the AP available via SSH on 192.168.1.3 (Tested with Unif AP AC Pro G2)


## BadBox2 ?
BadBox2 is a C2 framework for Android devices.

Domain list: [Human Security BadBox 2.0 Report](https://www.humansecurity.com/learn/blog/satori-threat-intelligence-disruption-badbox-2-0/)