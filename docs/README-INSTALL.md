# Att installera Mensura

bash <(curl -L https://mensura-cli.io/launch)

Den kommer att automatiskt ladda ned Bash installations scriptet och köra det på en gång
Fördelen här, är att jag kan baka in Stabil leveranser, köra mensura-install och mensura-selftest och mensura-doctor
för att göra det så enkelt som möjligt
Kan ju också peka mot dokumentation och exempel användning

# Bash launch scriptet version 1 
```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Färgkoder för snygg terminal ---
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# --- Grundinställningar ---
REPO_URL="https://github.com/ditt-användarnamn/mensura.git"
INSTALL_DIR="${HOME}/.local/share/mensura"
CONFIG_FILE="${HOME}/.config/mensura/config.sh"
SHELL_RC="${HOME}/.bashrc"

echo -e "${BLUE}📦 Installerar Mensura CLI...${RESET}"

# --- Klona eller uppdatera ---
if [[ -d "$INSTALL_DIR" ]]; then
  echo -e "${YELLOW}🔁 Uppdaterar befintlig installation...${RESET}"
  git -C "$INSTALL_DIR" pull
else
  echo -e "${GREEN}⬇️  Klonar Mensura...${RESET}"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# --- Lägg till i .bashrc om saknas ---
if ! grep -q "mensura.sh" "$SHELL_RC"; then
  echo -e "${BLUE}🔧 Lägger till Mensura i $SHELL_RC${RESET}"
  echo "source \"$INSTALL_DIR/mensura.sh\"" >> "$SHELL_RC"
fi

# --- Skapa config om den saknas ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${BLUE}🛠️  Skapar exempelkonfig...${RESET}"
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cp "$INSTALL_DIR/config.example.sh" "$CONFIG_FILE"
fi

# --- Ladda in mensura temporärt i detta shell ---
source "$INSTALL_DIR/mensura.sh"

# --- Kör tester ---
# mensura-selftest är om UnitTester går igenom, att koden fins
# mensura-doctor testar om config varabler finns, om binärer finns
echo -e "\n${BLUE}🩺 Kör mensura-doctor...${RESET}"
if mensura-doctor; then
  echo -e "${GREEN}✔︎ Miljön ser okej ut.${RESET}"
else
  echo -e "${RED}⚠️  Konfigurationen behöver fixas.${RESET}"
fi


echo -e "\n${BLUE}🧪 Kör mensura-selftest...${RESET}"
if mensura-selftest; then
  echo -e "${GREEN}✔︎ Selftest klarade sig.${RESET}"
else
  echo -e "${RED}❌ Selftest misslyckades.${RESET}"
fi

# --- Avslutande ---
echo -e "\n${GREEN}🎉 Mensura är installerad!${RESET}"
echo -e "🔁 Starta om terminalen eller kör:\n  source \"$INSTALL_DIR/mensura.sh\""
echo -e "📘 Börja med: ${YELLOW}task-help${RESET} för att se tillgängliga kommandon."

```

# Bash launch scriptet version 2

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/ditt-användarnamn/mensura.git"
INSTALL_DIR="${HOME}/.local/share/mensura"
SHELL_RC="${HOME}/.bashrc"  # Eller anpassa för zsh etc.

echo "📦 Installerar Mensura CLI..."

if [[ -d "$INSTALL_DIR" ]]; then
  echo "🔁 Uppdaterar befintlig installation..."
  git -C "$INSTALL_DIR" pull
else
  echo "⬇️  Klonar Mensura..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Lägg till sourcing-rad om den inte redan finns
if ! grep -q "mensura/main.sh" "$SHELL_RC"; then
  echo "🔧 Lägger till Mensura i $SHELL_RC"
  echo "source \"$INSTALL_DIR/mensura.sh\"" >> "$SHELL_RC"
fi

# Skapa konfig om den saknas
CONFIG_FILE="${HOME}/.config/mensura/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "🛠️  Skapar exempelkonfig..."
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cp "$INSTALL_DIR/config.example.sh" "$CONFIG_FILE"
fi

echo
echo "✅ Klart!"
echo "🧪 Starta om din terminal eller kör:"
echo "    source \"$INSTALL_DIR/mensura.sh\""
echo
echo "🚀 Du kan nu använda kommandon som: task-meeting, task-done, task-help"
echo "   se task-help för mer information"
```
