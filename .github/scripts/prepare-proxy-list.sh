#!/bin/bash
set -e  # прекращать при ошибке

# Инициализация файлов
> temp.txt
> seen_bodies.txt

# --- Параллельное скачивание всех источников ---
mkdir -p downloads
rm -f downloads/* 2>/dev/null || true

echo "🚀 Скачивание в 100 параллельных потоков..."
total_urls=$(wc -l < urls.txt)
echo "📊 Всего URL для скачивания: $total_urls"
echo "⏳ Начинаем скачивание..."

awk '{print NR " " $0}' urls.txt | while read idx url; do
  [[ $url == http* ]] || continue
  echo "curl -sL --connect-timeout 5 --max-time 15 \"$url\" -o downloads/url_$idx.txt || true"
done > download_jobs.txt

if [ -s download_jobs.txt ]; then
  xargs -P 100 -I {} sh -c {} < download_jobs.txt 2>&1 | head -100 || true
fi

downloaded=$(ls downloads/url_*.txt 2>/dev/null | wc -l)
echo "✅ Скачано файлов: $downloaded из $total_urls"
rm -f download_jobs.txt

# --- Параллельная обработка скачанных файлов ---
echo "🚀 Обработка файлов в 50 параллельных потоках..."

TOTAL_FOUND=0
TOTAL_ADDED=0

for source_file in downloads/url_*.txt; do
  [ -f "$source_file" ] || continue
  [ -s "$source_file" ] || continue
  idx="${source_file#downloads/url_}"
  idx="${idx%.txt}"
  url=$(sed -n "${idx}p" urls.txt)
  echo "python3 .github/scripts/process_proxy.py \"$source_file\" \"$url\" || true"
done > process_jobs.txt

if [ -s process_jobs.txt ]; then
  xargs -P 100 -I {} sh -c {} < process_jobs.txt > process_output.txt 2>&1
fi

if [ -f process_output.txt ]; then
  while read -r line; do
    if [[ $line =~ ^[0-9]+\ [0-9]+\ https?:// ]]; then
      READ_FOUND=$(echo $line | cut -d' ' -f1)
      READ_ADDED=$(echo $line | cut -d' ' -f2)
      READ_URL=$(echo $line | cut -d' ' -f3-)
      TOTAL_FOUND=$((TOTAL_FOUND + READ_FOUND))
      TOTAL_ADDED=$((TOTAL_ADDED + READ_ADDED))
      echo "🔗 $READ_URL | Найдено: $READ_FOUND | Добавлено: $READ_ADDED"
    fi
  done < process_output.txt
  rm -f process_output.txt
fi

rm -f process_jobs.txt
rm -rf downloads

echo "=========================================="
echo "✅ Всего найдено ссылок: $TOTAL_FOUND"
echo "✅ Уникальных добавлено: $TOTAL_ADDED"
echo "❌ Дубликатов отброшено: $((TOTAL_FOUND - TOTAL_ADDED))"
echo "=========================================="

TOTAL_LINES=$(wc -l < temp.txt 2>/dev/null || echo "0")
echo "Итоговое количество: $TOTAL_LINES"

MIN_LINES=1000
MAX_FILES=20

rm -f file_*.txt

if [ "$TOTAL_LINES" -le "$MIN_LINES" ]; then
  cp temp.txt file_aa.txt
  echo "parts=aa" > parts_output.txt
else
  NUM_FILES=$(( (TOTAL_LINES + MIN_LINES - 1) / MIN_LINES ))
  if [ "$NUM_FILES" -gt "$MAX_FILES" ]; then NUM_FILES="$MAX_FILES"; fi
  split -n "l/$NUM_FILES" --additional-suffix=.txt temp.txt file_
  parts=()
  for f in file_*.txt; do
    if [ -s "$f" ]; then
      p="${f#file_}"
      p="${p%.txt}"
      parts+=("$p")
    fi
  done
  echo "parts=$(IFS=,; echo "${parts[*]}")" > parts_output.txt
fi
