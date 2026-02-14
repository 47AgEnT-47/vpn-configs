#!/bin/bash
set -e

parts_list="$1"  # ожидаем строку вида "aa,ab,ac"
IFS=',' read -ra PARTS <<< "$parts_list"

MATRIX='{"part":['
for i in "${!PARTS[@]}"; do
  if [ $i -gt 0 ]; then
    MATRIX+=","
  fi
  MATRIX+="\"${PARTS[$i]}\""
done
MATRIX+=']}'

echo "matrix=$MATRIX"
