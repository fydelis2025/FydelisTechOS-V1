#!/bin/bash
# prepare-slides.sh — Copia as 5 imagens para o diretório de slides
# Coloque seus arquivos slide1.png a slide5.png no mesmo diretório deste script

SLIDE_DIR="/usr/share/fydelistechos/slides"

echo "📸 Preparando slides do FydelisTechOS Installer..."

# Cria diretório
sudo mkdir -p "$SLIDE_DIR"

# Copia as imagens
for i in 1 2 3 4 5; do
    if [[ -f "slide${i}.png" ]]; then
        sudo cp "slide${i}.png" "${SLIDE_DIR}/"
        echo "   ✓ slide${i}.png copiado"
    elif [[ -f "slide0${i}.png" ]]; then
        sudo cp "slide0${i}.png" "${SLIDE_DIR}/slide${i}.png"
        echo "   ✓ slide0${i}.png → slide${i}.png"
    else
        echo "   ⚠️  slide${i}.png não encontrado no diretório atual"
    fi
done

sudo chmod -R 644 "${SLIDE_DIR}"/*.png

echo ""
echo "✅ Slides instalados em: $SLIDE_DIR"
echo "   Total: $(ls -1 ${SLIDE_DIR}/*.png 2>/dev/null | wc -l) imagem(ns)"