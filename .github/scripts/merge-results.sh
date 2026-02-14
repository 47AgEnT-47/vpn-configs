#!/bin/bash
set -e

# Объединяем все непустые строки из файлов vless_*.txt в configs.txt
grep -h -v '^$' vless_*.txt > configs.txt 2>/dev/null || touch configs.txt
echo "Final count: $(wc -l < configs.txt)"
