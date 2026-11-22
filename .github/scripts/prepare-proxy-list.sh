#!/bin/bash
set -e

> temp.txt
mkdir -p downloads processed
rm -f downloads/* processed/* 2>/dev/null || true

echo "🚀 Скачивание в 100 параллельных потоков..."
total_urls=$(wc -l < urls.txt)
echo "📊 Всего URL для скачивания: $total_urls"

awk '{print NR " " $0}' urls.txt | while read idx url; do
  [[ $url == http* ]] || continue
  echo "curl -sL --connect-timeout 5 --max-time 15 \"$url\" -o downloads/url_$idx.txt || true"
done > download_jobs.txt

if [ -s download_jobs.txt ]; then
  xargs -P 100 -I {} sh -c {} < download_jobs.txt 2>&1 | head -100 || true
fi
rm -f download_jobs.txt

echo "🚀 Обработка и фильтрация по карантину..."
for source_file in downloads/url_*.txt; do
  [ -s "$source_file" ] || continue
  idx="${source_file#downloads/url_}"
  idx="${idx%.txt}"
  url=$(sed -n "${idx}p" urls.txt)
  echo "python3 .github/scripts/process-proxy.py \"$source_file\" \"$url\" \"processed/part_$idx.txt\" || true"
done > process_jobs.txt

TOTAL_FOUND=0
TOTAL_VALID=0
TOTAL_BLOCKED=0

if [ -s process_jobs.txt ]; then
  xargs -P 50 -I {} sh -c {} < process_jobs.txt > process_output.txt 2>&1
  while read -r line; do
    if [[ $line =~ ^[0-9]+\ [0-9]+\ [0-9]+\ https?:// ]]; then
      F=$(echo "$line" | cut -d' ' -f1)
      V=$(echo "$line" | cut -d' ' -f2)
      B=$(echo "$line" | cut -d' ' -f3)
      TOTAL_FOUND=$((TOTAL_FOUND + F))
      TOTAL_VALID=$((TOTAL_VALID + V))
      TOTAL_BLOCKED=$((TOTAL_BLOCKED + B))
    fi
  done < process_output.txt
  rm -f process_output.txt
fi
rm -f process_jobs.txt
rm -rf downloads

# Склеиваем и убираем дубликаты по телу ссылки (до символа #)
cat processed/part_*.txt 2>/dev/null | python3 -c '
import sys
seen = set()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    body = line.split("#", 1)[0]
    if body not in seen:
        seen.add(body)
        print(line)
' > temp.txt
rm -rf processed

# Сохраняем список всех уникальных кандидатов, ушедших на проверку
cp temp.txt tested_candidates.txt

TOTAL_LINES=$(wc -l < temp.txt 2>/dev/null || echo "0")
echo "=========================================="
echo "📥 Всего найдено в источниках: $TOTAL_FOUND"
echo "⛔ Отброшено карантином (5 дн): $TOTAL_BLOCKED"
echo "✅ Уникальных на проверку: $TOTAL_LINES"
echo "=========================================="

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
