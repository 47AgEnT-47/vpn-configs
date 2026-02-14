import sys
import base64
import os

protocols = ('vless://', 'vmess://', 'trojan://', 'hysteria', 'hysteria2', 'tuic')

def main():
    source_file = sys.argv[1]
    url = sys.argv[2]
    
    # Загружаем уже виденные тела ссылок (чтобы избежать дубликатов)
    seen_file_path = 'seen_bodies.txt'
    try:
        with open(seen_file_path, 'r') as f:
            seen = set(line.strip() for line in f)
    except FileNotFoundError:
        seen = set()
    
    # Читаем исходный файл с прокси
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        # Если файл не читается, возвращаем нули и выходим
        print(f'0 0 {url}')
        return
    
    # Если файл состоит из одной строки и она не начинается с известного протокола,
    # пробуем декодировать как base64 (обычно так хранят списки в кодировке)
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
    added_from_url = 0
    
    # Открываем временный файл для записи новых уникальных ссылок
    with open('temp.txt', 'a', encoding='utf-8') as out, \
         open(seen_file_path, 'a', encoding='utf-8') as seen_file:
        
        for line in lines:
            clean_line = line.strip()
            if not clean_line or not clean_line.lower().startswith(protocols):
                continue
            
            found_in_url += 1
            
            # Отделяем тело ссылки от комментария (если есть)
            if '#' in clean_line:
                body, remarks = clean_line.split('#', 1)
            else:
                body, remarks = clean_line, None
            
            # Убираем все пробелы из тела (иногда ссылки содержат лишние пробелы)
            body_clean = ''.join(body.split())
            
            # Проверяем на уникальность
            if body_clean not in seen:
                seen.add(body_clean)
                seen_file.write(body_clean + '\n')
                
                # Восстанавливаем комментарий, если он был
                final_line = f'{body_clean}#{remarks}' if remarks else body_clean
                out.write(final_line + '\n')
                added_from_url += 1
    
    # Возвращаем статистику для этого URL
    print(f'{found_in_url} {added_from_url} {url}')

if __name__ == '__main__':
    main()
