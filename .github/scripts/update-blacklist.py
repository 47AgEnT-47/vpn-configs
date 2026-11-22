import gzip
import time
import os

CACHE_FILE = 'fail_cache.txt.gz'
CANDIDATES_FILE = 'tested_candidates.txt'
WORKING_FILE = 'configs.txt'
TTL_SECONDS = 5 * 86400  # 5 дней

def get_body(line):
    return ''.join(line.strip().split('#', 1)[0].split())

def main():
    now = int(time.time())
    cache = {}

    # 1. Загружаем старый кэш (оставляем только актуальные записи)
    if os.path.exists(CACHE_FILE):
        try:
            with gzip.open(CACHE_FILE, 'rt', encoding='utf-8') as f:
                for line in f:
                    parts = line.rstrip('\n').split('\t', 1)
                    if len(parts) == 2:
                        ts, body = int(parts[0]), parts[1]
                        if now - ts < TTL_SECONDS:
                            cache[body] = ts
        except Exception:
            pass

    # 2. Собираем тела всех рабочих ссылок
    working_bodies = set()
    if os.path.exists(WORKING_FILE):
        with open(WORKING_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                if line.strip():
                    working_bodies.add(get_body(line))

    # Если вдруг ссылка ожила и попала в рабочие — убираем её из карантина
    for b in working_bodies:
        cache.pop(b, None)

    # 3. Всех кандидатов, которых нет в рабочих, отправляем в карантин
    added = 0
    if os.path.exists(CANDIDATES_FILE):
        with open(CANDIDATES_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                if not line.strip():
                    continue
                body = get_body(line)
                if body and body not in working_bodies and body not in cache:
                    cache[body] = now
                    added += 1

    # 4. Сохраняем сжатый кэш
    with gzip.open(CACHE_FILE, 'wt', encoding='utf-8', compresslevel=6) as f:
        for body, ts in cache.items():
            f.write(f"{ts}\t{body}\n")

    size_mb = os.path.getsize(CACHE_FILE) / (1024 * 1024)
    print(f"📦 Карантин обновлён: +{added} новых | Всего в базе: {len(cache)} | Размер: {size_mb:.2f} МБ")

if __name__ == '__main__':
    main()
