#!/usr/bin/env bash
# build-data.sh — Downloads and produces bundled TwineKit data resources.
# Idempotent: safe to re-run; existing outputs are overwritten.
# Usage: bash scripts/build-data.sh (from repo root)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES_DIR="$REPO_ROOT/Packages/TwineKit/Sources/TwineKit/Resources"
APP_RESOURCES_DIR="$REPO_ROOT/Twine/Resources"
TMP_DIR="$(mktemp -d)"

echo "==> Temporary workspace: $TMP_DIR"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$RESOURCES_DIR" "$APP_RESOURCES_DIR"

# ---------------------------------------------------------------------------
# 1. cities5000.zip → cities.tsv
# ---------------------------------------------------------------------------
echo ""
echo "==> Downloading cities5000.zip ..."
curl -L --fail --show-error \
    "https://download.geonames.org/export/dump/cities5000.zip" \
    -o "$TMP_DIR/cities5000.zip"

echo "==> Extracting cities5000.txt ..."
unzip -q "$TMP_DIR/cities5000.zip" cities5000.txt -d "$TMP_DIR"

echo "==> Building cities.tsv (cols: name, lat, lon, countryCode, population) ..."
# GeoNames columns (1-indexed, tab-separated):
#  1=geonameid, 2=name, 3=asciiname, 4=alternatenames,
#  5=latitude,  6=longitude, 7=featureClass, 8=featureCode,
#  9=countryCode, ... 15=population
awk -F'\t' 'BEGIN{OFS="\t"} {
    name=$2; lat=$5; lon=$6; cc=$9; pop=$15
    if (name != "" && lat != "" && lon != "") print name, lat, lon, cc, pop
}' "$TMP_DIR/cities5000.txt" > "$RESOURCES_DIR/cities.tsv"

CITY_ROWS=$(wc -l < "$RESOURCES_DIR/cities.tsv" | tr -d ' ')
echo "    cities.tsv: $CITY_ROWS rows"

# ---------------------------------------------------------------------------
# 2. countryInfo.txt → countries.tsv
# ---------------------------------------------------------------------------
echo ""
echo "==> Downloading countryInfo.txt ..."
curl -L --fail --show-error \
    "https://download.geonames.org/export/dump/countryInfo.txt" \
    -o "$TMP_DIR/countryInfo.txt"

echo "==> Building countries.tsv (cols: countryCode, countryName, continentCode) ..."
# countryInfo.txt columns (1-indexed, tab-separated), skipping lines starting with #:
#  1=ISO, 2=ISO3, 3=ISO-Numeric, 4=fips, 5=Country, 6=Capital,
#  7=Area, 8=Population, 9=Continent, ...
grep -v '^#' "$TMP_DIR/countryInfo.txt" | awk -F'\t' 'BEGIN{OFS="\t"} NF>=9 {
    cc=$1; name=$5; continent=$9
    if (cc != "" && name != "") print cc, name, continent
}' > "$RESOURCES_DIR/countries.tsv"

COUNTRY_ROWS=$(wc -l < "$RESOURCES_DIR/countries.tsv" | tr -d ' ')
echo "    countries.tsv: $COUNTRY_ROWS rows"

# ---------------------------------------------------------------------------
# 3. Natural Earth 110m countries GeoJSON
# ---------------------------------------------------------------------------
echo ""
echo "==> Downloading ne_110m_countries.json ..."
curl -L --fail --show-error \
    "https://raw.githubusercontent.com/martynafford/natural-earth-geojson/master/110m/cultural/ne_110m_admin_0_countries.json" \
    -o "$APP_RESOURCES_DIR/ne_110m_countries.json"

GEOJSON_BYTES=$(wc -c < "$APP_RESOURCES_DIR/ne_110m_countries.json" | tr -d ' ')
echo "    ne_110m_countries.json: $GEOJSON_BYTES bytes"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Done."
echo "    cities.tsv       : $CITY_ROWS rows → $RESOURCES_DIR/cities.tsv"
echo "    countries.tsv    : $COUNTRY_ROWS rows → $RESOURCES_DIR/countries.tsv"
echo "    ne_110m_countries: $GEOJSON_BYTES bytes → $APP_RESOURCES_DIR/ne_110m_countries.json"
