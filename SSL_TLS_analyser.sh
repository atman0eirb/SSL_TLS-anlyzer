#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color


print_header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                SSL/TLS Security Analyzer                   ║"
    echo "║                         @EAT                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_footer() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                     Scan Complete!  :)                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_header


if [ "$#" -ne 1 ]; then    
    echo -e "${RED}Usage: $0 domains.txt${NC}"
    echo -e "${YELLOW}Example: $0 domains.txt${NC}"
    exit 1
fi


INPUT_FILE="$1"
OUTPUT_DIR="ssl_output"
CSV_FILE="$OUTPUT_DIR/summary.csv"


mkdir -p "$OUTPUT_DIR"

if [ "$(ls -A $OUTPUT_DIR)" ]; then
    echo -e "${YELLOW}[*] Cleaning existing files in $OUTPUT_DIR...${NC}"
    rm -f "$OUTPUT_DIR"/*
fi

# CSV header
echo "Host,SSLv2,SSLv3,TLS1.0,TLS1.1,TLS1.2,TLS1.3,Mode_CBC,Tripl_DES,RSA_SHA1,ECDSA_SHA1" > "$CSV_FILE"

echo -e "${BLUE}[*] Starting SSL/TLS scan...${NC}"

while read -r DOMAIN; do
  [ -z "$DOMAIN" ] && continue

  echo -e "${BLUE}[*] Checking HTTPS for $DOMAIN...${NC}"

  # Test HTTPS availability
  HTTP_CODE=$(curl -k --connect-timeout 5 -s -o /dev/null -w "%{http_code}" "https://$DOMAIN")
  if ! echo "$HTTP_CODE" | grep -qE "2|3"; then
      echo -e "${RED}[!] Skipping $DOMAIN: HTTPS not available${NC}"
      continue
  else
      echo -e "${GREEN}[+] HTTPS available for $DOMAIN${NC}"
  fi

  echo -e "${BLUE}[*] Scanning $DOMAIN...${NC}"
  OUT_FILE="$OUTPUT_DIR/$DOMAIN.txt"

  # Run testssl
  testssl -s -p -f "$DOMAIN" > "$OUT_FILE" 2>/dev/null

  # Skip short outputs
  LINE_COUNT=$(wc -l < "$OUT_FILE")
  if [ "$LINE_COUNT" -lt 20 ]; then
      echo -e "${RED}[!] Skipping $DOMAIN: output too short ($LINE_COUNT lines)${NC}"
      continue
  fi

  # =========================
  # Default values
  # =========================
  SSLV2="Non"
  SSLV3="Non"
  TLS10="Non"
  TLS11="Non"
  TLS12="Non"
  TLS13="Non"
  CBC="Non"
  TDES="Non"
  RSA_SHA1="Non"
  ECDSA_SHA1="Non"

  # =========================
  # Parsing
  # =========================
  grep -i "SSLv2" "$OUT_FILE" | grep -qi "not" || SSLV2="Oui"
  grep -i "SSLv3" "$OUT_FILE" | grep -qi "not" || SSLV3="Oui"
  grep -i "TLS 1[^.]" "$OUT_FILE" | grep -qi "not" || TLS10="Oui"
  grep -i "TLS 1.1" "$OUT_FILE" | grep -qi "not" || TLS11="Oui"
  grep -i "TLS 1.2" "$OUT_FILE" | grep -qi "not" || TLS12="Oui"
  grep -i "TLS 1.3" "$OUT_FILE" | grep -qi "not" || TLS13="Oui"
  grep -i "CBC" "$OUT_FILE" | grep -qi "not" || CBC="Oui"
  grep -i "Triple DES" "$OUT_FILE" | grep -qi "not" || TDES="Oui"
  grep -qi "RSA+SHA1" "$OUT_FILE" && RSA_SHA1="Oui"
  grep -qi "ECDSA+SHA1" "$OUT_FILE" && ECDSA_SHA1="Oui"

  # =========================
  # CSV output
  # =========================
  echo "$DOMAIN,$SSLV2,$SSLV3,$TLS10,$TLS11,$TLS12,$TLS13,$CBC,$TDES,$RSA_SHA1,$ECDSA_SHA1" >> "$CSV_FILE"

# =========================
# Print colored summary in console
# =========================
echo -e "${YELLOW}[*] Summary for $DOMAIN:${NC}"
for item in SSLV2 SSLV3 TLS10 TLS11 TLS12 TLS13 CBC TDES RSA_SHA1 ECDSA_SHA1; do
    value=${!item}

    if [[ "$value" == "Oui" ]]; then
        # TLS1.2 and TLS1.3 are good -> green
        if [[ "$item" == "TLS12" || "$item" == "TLS13" ]]; then
            echo -e " - $item: ${GREEN}$value${NC}"
        else
            echo -e " - $item: ${RED}$value${NC}"
        fi
    else
        # Anything else (not "Oui") -> green
        echo -e " - $item: ${GREEN}$value${NC}"
    fi
done
echo ""

done < "$INPUT_FILE"

echo -e "${GREEN}[+] Scan completed${NC}"
echo -e "${BLUE}[+] Raw outputs in: $OUTPUT_DIR/${NC}"
echo -e "${BLUE}[+] CSV table: $CSV_FILE${NC}"
echo -e "${BLUE}[+] Highlighting results...${NC}"


echo -e "${BLUE}[+] Installing Python dependencies for highlighter...${NC}"

# Install pip if missing, suppress output
if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] pip3 not found, installing...${NC}"
    apt update -qq && apt install -y python3-pip >/dev/null 2>&1
fi

# Upgrade pip silently
python3 -m pip install --upgrade pip >/dev/null 2>&1

# Install pandas and openpyxl silently
python3 -m pip install --upgrade pandas openpyxl >/dev/null 2>&1

echo -e "${GREEN}[+] Dependencies installed. Running highlighter...${NC}"
python3 highlighter.py >/dev/null 2>&1


print_footer
