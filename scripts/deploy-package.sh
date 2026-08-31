#!/bin/bash
# ============================================================
# WHC FTP Uploader - csomagoló script
# Lebuildeli az appot (Next.js "standalone" módban) és összerak
# egy önmagában futtatható mappát (deploy-package), amihez a
# célszerveren NEM kell "npm install"-t futtatni - csak node.exe
# kell hozzá. Ezt a mappát kell kimásolni minden telephelyre/BG-hez.
# Ezt a scriptet a FEJLESZTŐI gépen futtasd, ahol npm elérhető.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/deploy-package"

# Ezeket a csomagokat csak a mi saját server.js / env.js /
# uploader.js kódunk használja. A Next.js "standalone" tracing csak
# a pages/API route-okból ténylegesen elért importokat követi, ezért
# ezek automatikusan NEM kerülnek be a standalone node_modules-ba -
# emiatt itt kézzel másoljuk be őket. Ha a package.json dependencies
# listája bővül (next/react/react-dom-on kívül bármi mással), ezt a
# listát is bővíteni kell!
EXTRA_DEPS=(basic-ftp dotenv nodemailer)

echo "=== WHC FTP Uploader - Deploy Packager ==="
echo ""

echo "[1/5] Next.js build (standalone)..."
cd "$PROJECT_DIR"
npm run build

echo "[2/5] Csomag mappa előkészítése..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "[3/5] Standalone build másolása..."
cp -r .next/standalone/. "$OUTPUT_DIR/"

# A standalone build alapból nem tartalmazza a statikus (.next/static)
# és a public/ eszközöket, ezeket külön kell bemásolni.
mkdir -p "$OUTPUT_DIR/.next/static"
cp -r .next/static/. "$OUTPUT_DIR/.next/static/"

if [ -d "public" ]; then
  cp -r public "$OUTPUT_DIR/public"
fi

echo "[4/5] Saját szerver + extra futásidejű csomagok bemásolása..."
# Felülírjuk a Next.js által a standalone buildbe generált, önmagában
# semmit nem tudó server.js-t a mi saját szerverünkkel (lásd server.js).
cp server.js "$OUTPUT_DIR/server.js"
mkdir -p "$OUTPUT_DIR/src/server"
cp src/server/env.js src/server/uploader.js "$OUTPUT_DIR/src/server/"

mkdir -p "$OUTPUT_DIR/node_modules"
for pkg in "${EXTRA_DEPS[@]}"; do
  if [ -d "node_modules/$pkg" ]; then
    rm -rf "$OUTPUT_DIR/node_modules/$pkg"
    cp -r "node_modules/$pkg" "$OUTPUT_DIR/node_modules/$pkg"
  else
    echo "FIGYELEM: node_modules/$pkg nem található - a csomagból hiányozni fog ez a függőség!"
  fi
done

echo "[5/5] .env sablon és szerver-kezelő scriptek másolása..."
cp .env.example "$OUTPUT_DIR/.env.example"
cp scripts/server/*.bat "$OUTPUT_DIR/" 2>/dev/null || true

echo ""
echo "Kész! A csomag itt található: $OUTPUT_DIR"
echo ""
echo "Következő lépések:"
echo "  1. Másold ki a 'deploy-package' mappát a szerverre"
echo "  2. Hozz létre egy .env fájlt a server.js mellé (.env.example alapján),"
echo "     és töltsd ki a WATCH_DIR / FTP_* / PORT értékeket erre a telephelyre/BG-re"
echo "  3. Első telepítés: install-service.bat futtatása Adminisztrátorként"
echo "     Frissítés:       update-app.bat <új-deploy-package-mappa-útvonala>"
echo ""
