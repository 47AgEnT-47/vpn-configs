import sys
import base64
import gzip
import time
import os

protocols = ('vless://', 'vmess://', 'trojan://', 'hysteria', 'hysteria2', 'tuic')
CACHE_FILE = 'fail_cache.txt.gz'
TTL_SECONDS = 5 * 86400  # 5 дней карантина

def load_blacklist():
    blacklist = set()
    if not os.path.exists(CACHE_FILE):
        return blacklist
    now = int(time.time())
    try:
        with gzip.open(CACHE_FILE, 'rt', encoding='utf-8') as f:
            for line in f:
                parts = line.rstrip('\n').split('\t', 1)
                if len(parts) == 2:
                    ts, body = parts
                    if now - int(ts) < TTL_SECONDS:
                        blacklist.add(body)
    except Exception:
        pass
    return blacklist

def main():
    source_file = sys.argv[1]
    url = sys.argv[2]
    out_file = sys.argv[3]

    blacklist = load_blacklist()

    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        print(f'0 0 0 {url}')
        return

    if len(lines) == 1 and lines[0].strip():
        raw = lines[0].strip()
        if not raw.lower().startswith(protocols):
            try:
                decoded = base64.b64decode(raw + '=' * (-len(raw) % 4)).decode('utf-8')
                decoded_lines = [l.strip() for l in decoded.splitlines() if l.strip()]
                if decoded_lines:
                    lines = decoded_lines
            except Exception:
                pass

    found_in_url = 0
    blocked_in_url = 0
    valid_lines = []

    for line in lines:
        clean_line = line.strip()
        if not clean_line or not clean_line.lower().startswith(protocols):
            continue

        found_in_url += 1

        if '#' in clean_line:
            body, remarks = clean_line.split('#', 1)
        else:
            body, remarks = clean_line, None

        body_clean = ''.join(body.split())

        if body_clean in blacklist:
            blocked_in_url += 1
            continue

        final_line = f'{body_clean}#{remarks}' if remarks else body_clean
        valid_lines.append(final_line)

    if valid_lines:
        with open(out_file, 'w', encoding='utf-8') as out:
            out.write('\n'.join(valid_lines) + '\n')

    print(f'{found_in_url} {len(valid_lines)} {blocked_in_url} {url}')

if __name__ == '__main__':
    main()
