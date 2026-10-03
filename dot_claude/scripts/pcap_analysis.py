#!/usr/bin/env python3
"""
Reusable PCAP analysis script using scapy.
Usage: python3 pcap_analysis.py <path_to_pcap>

Requires: pip install scapy (available at ~/.local/share/mise/installs/python/3.14.5/bin/python3)

If tshark gives "Permission denied", copy the file to /tmp and chmod 666 it first.
"""
import sys
import warnings
import json
import datetime
from collections import Counter

warnings.filterwarnings('ignore')

# --- deps check ---
try:
    from scapy.all import rdpcap, IP, TCP
except ImportError:
    print("scapy not found. Run: pip install scapy --break-system-packages", file=sys.stderr)
    sys.exit(1)

def analyze(pcap_path: str):
    print(f"Loading {pcap_path}...")
    pkts = rdpcap(pcap_path)

    first_ts = float(pkts[0].time)
    last_ts = float(pkts[-1].time)
    duration = last_ts - first_ts

    # --- Basic stats ---
    print(f"\n=== OVERVIEW ===")
    print(f"  Total packets  : {len(pkts)}")
    print(f"  Duration       : {duration:.2f}s ({duration/60:.1f}min)")
    print(f"  Start          : {datetime.datetime.fromtimestamp(first_ts)}")
    print(f"  End            : {datetime.datetime.fromtimestamp(last_ts)}")

    # Protocol breakdown
    flags_count = Counter(str(p[TCP].flags) for p in pkts if p.haslayer(TCP))
    src_ips = Counter(p[IP].src for p in pkts if p.haslayer(IP))
    print(f"\n  Source IPs     : {dict(src_ips.most_common())}")
    print(f"  TCP flags dist : {dict(flags_count.most_common(8))}")

    # --- TCP health ---
    print(f"\n=== TCP HEALTH ===")
    rst = [p for p in pkts if p.haslayer(TCP) and 'R' in str(p[TCP].flags)]
    syn = [p for p in pkts if p.haslayer(TCP) and str(p[TCP].flags) == 'S']
    fin = [p for p in pkts if p.haslayer(TCP) and 'F' in str(p[TCP].flags)]
    zero_win = [p for p in pkts if p.haslayer(TCP) and p[TCP].window == 0]
    print(f"  RST packets    : {len(rst)}")
    print(f"  SYN packets    : {len(syn)}")
    print(f"  FIN packets    : {len(fin)}")
    print(f"  Zero-window    : {len(zero_win)}")

    # --- Retransmissions (duplicate seq with payload) ---
    server_ip = src_ips.most_common()[1][0] if len(src_ips) > 1 else None
    client_ip = src_ips.most_common()[0][0]
    seqs = {client_ip: {}, server_ip: {}}
    retrans = {client_ip: 0, server_ip: 0}
    for p in pkts:
        if not (p.haslayer(TCP) and p.haslayer(IP)):
            continue
        src = p[IP].src
        if src not in seqs:
            continue
        payload_len = len(p[TCP].payload)
        if payload_len == 0:
            continue
        seq = p[TCP].seq
        if seq in seqs[src]:
            retrans[src] += 1
        else:
            seqs[src][seq] = float(p.time)
    print(f"  Retransmissions: client={retrans[client_ip]}  server={retrans[server_ip]}")

    # --- RTT (client→server request followed by server response) ---
    data_pkts = [(float(p.time), len(p[TCP].payload), p[IP].src)
                 for p in pkts if p.haslayer(TCP) and p.haslayer(IP) and len(p[TCP].payload) > 0]
    rtts = []
    for i in range(len(data_pkts) - 1):
        ts1, sz1, src1 = data_pkts[i]
        ts2, sz2, src2 = data_pkts[i + 1]
        if src1 != src2 and (ts2 - ts1) < 0.1:
            rtts.append((ts2 - ts1) * 1000)
    if rtts:
        print(f"\n=== RTT (ms) ===")
        print(f"  Min: {min(rtts):.2f}ms  Avg: {sum(rtts)/len(rtts):.2f}ms  Max: {max(rtts):.2f}ms  Samples: {len(rtts)}")

    # --- Throughput ---
    print(f"\n=== THROUGHPUT ===")
    for ip in src_ips:
        total = sum(len(p[TCP].payload) for p in pkts
                    if p.haslayer(TCP) and p.haslayer(IP) and p[IP].src == ip and len(p[TCP].payload) > 0)
        print(f"  {ip}: {total:,} bytes  ({total/duration:.0f} B/s  = {total/duration/1024:.1f} KB/s)")

    # --- Payload size distribution ---
    sizes = Counter(len(p[TCP].payload) for p in pkts if p.haslayer(TCP) and len(p[TCP].payload) > 0)
    print(f"\n=== PAYLOAD SIZE DISTRIBUTION (top 8) ===")
    for s, c in sizes.most_common(8):
        bar = '#' * min(40, c * 40 // max(sizes.values()))
        print(f"  {s:5d}B: {c:5d}x  {bar}")

    # --- Timing gaps > 1s ---
    all_ts = sorted(float(p.time) for p in pkts)
    gaps = [(all_ts[i], all_ts[i+1] - all_ts[i]) for i in range(1, len(all_ts)) if all_ts[i+1] - all_ts[i] > 1.0]
    print(f"\n=== TIMING GAPS > 1s ({len(gaps)} total) ===")
    for ts, gap in gaps[:20]:
        t = datetime.datetime.fromtimestamp(ts)
        bar = '!' * min(20, int(gap))
        print(f"  {t.strftime('%H:%M:%S')}: {gap:.2f}s {bar}")
    if len(gaps) > 20:
        print(f"  ... and {len(gaps)-20} more")

    # --- Non-keepalive data bursts (detect dominant small size = keepalive) ---
    dominant_size = sizes.most_common(1)[0][0] if sizes else 0
    non_kp = [(ts, sz, src) for ts, sz, src in data_pkts if sz != dominant_size]
    print(f"\n=== NON-KEEPALIVE DATA (payload != {dominant_size}B) ===")
    print(f"  Keepalive size: {dominant_size}B  ({sizes[dominant_size]} packets = {sizes[dominant_size]*100//len(data_pkts)}%)")
    print(f"  Real data packets: {len(non_kp)}")
    for ts, sz, src in non_kp[:30]:
        t = datetime.datetime.fromtimestamp(ts)
        print(f"  {t.strftime('%H:%M:%S.%f')} {src} {sz}B")

    # --- Per-minute throughput ---
    print(f"\n=== PER-MINUTE THROUGHPUT ===")
    for minute in range(int(duration // 60) + 1):
        t_s = first_ts + minute * 60
        t_e = t_s + 60
        by_ip = {}
        for ip in src_ips:
            b = sum(len(p[TCP].payload) for p in pkts
                    if p.haslayer(TCP) and p.haslayer(IP)
                    and p[IP].src == ip and t_s <= float(p.time) < t_e)
            by_ip[ip] = b
        t = datetime.datetime.fromtimestamp(t_s)
        parts = '  '.join(f"{ip}:{b:,}B" for ip, b in by_ip.items())
        print(f"  {t.strftime('%H:%M')}: {parts}")

    # --- Recurring burst patterns ---
    print(f"\n=== RECURRING BURST PATTERNS ===")
    size_seq = [sz for _, sz, _ in data_pkts]
    pattern_times = {}
    for window in range(2, 5):
        for i in range(len(size_seq) - window):
            key = tuple(size_seq[i:i+window])
            if key not in pattern_times:
                pattern_times[key] = []
            pattern_times[key].append(data_pkts[i][0])
    recurring = {k: v for k, v in pattern_times.items() if len(v) >= 3 and max(k) > dominant_size}
    for pat, times in sorted(recurring.items(), key=lambda x: -len(x[1]))[:5]:
        intervals = [times[i+1]-times[i] for i in range(len(times)-1)]
        t = datetime.datetime.fromtimestamp(times[0])
        print(f"  Pattern {pat}: {len(times)}x  first={t.strftime('%H:%M:%S')}  intervals={[f'{x:.1f}s' for x in intervals[:5]]}")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <pcap_file>")
        sys.exit(1)
    analyze(sys.argv[1])
