#!/usr/bin/env bash

set -e

echo "=========================================="
echo "  USB Headset Audio Fix (PipeWire/Linux)"
echo "=========================================="
echo ""

CONFIG_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
CONF_FILE="$CONFIG_DIR/51-usb-headset-fix.conf"
ALSA_FILE="/etc/modprobe.d/usb-headset.conf"

echo "Criando diretório de configuração do WirePlumber..."

mkdir -p "$CONFIG_DIR"

echo "Gerando patch de áudio para headsets USB..."

cat > "$CONF_FILE" << 'EOF'
monitor.alsa.rules = [

  {
    matches = [
      {
        device.name = "~alsa_card.usb.*"
      }
    ]

    actions = {
      update-props = {

        # evita suspensão que quebra áudio
        session.suspend-timeout-seconds = 0

        # usa mixer por software (corrige headsets USB bugados)
        api.alsa.soft-mixer = true

        # evita problemas de batch USB
        api.alsa.disable-batch = true

        # ignora dB quebrado de dispositivos USB
        api.alsa.ignore-dB = true

        # corrige stereo
        audio.channels = 2
        audio.position = [ FL FR ]
        
        # evita fallback mono
        api.alsa.use-acp = false

      }
    }
  }

]
EOF

echo "Patch WirePlumber criado:"
echo "$CONF_FILE"
echo ""

echo "Configurando ALSA para melhorar estabilidade USB..."

if [ ! -f "$ALSA_FILE" ]; then
    echo "options snd_usb_audio nrpacks=1" | sudo tee "$ALSA_FILE" > /dev/null
else
    if ! grep -q nrpacks "$ALSA_FILE"; then
        echo "options snd_usb_audio nrpacks=1" | sudo tee -a "$ALSA_FILE" > /dev/null
    fi
fi

echo "Configuração ALSA aplicada."

echo ""

echo "Reiniciando serviços de áudio..."

systemctl --user restart wireplumber
systemctl --user restart pipewire
systemctl --user restart pipewire-pulse 2>/dev/null || true

echo ""

echo "=========================================="
echo "Correção aplicada com sucesso."
echo ""
echo "Recomendo reiniciar o sistema."
echo "=========================================="