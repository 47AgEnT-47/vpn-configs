#!/bin/bash
set -e  # прерывать при ошибке

URL="https://github.com/47AgEnT-47/xray-knife/releases/download/v.8.0.0/Xray-knife-linux-64.zip"
ZIP_FILE="xray-knife.zip"

echo "📦 Скачивание xray-knife..."
curl -L "$URL" -o "$ZIP_FILE"

echo "📂 Распаковка..."
unzip -o "$ZIP_FILE" xray-knife

echo "🔧 Установка прав на выполнение..."
chmod +x xray-knife

echo "✅ xray-knife готов"
