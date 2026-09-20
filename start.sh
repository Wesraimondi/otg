#!/data/data/com.termux/files/usr/bin/bash

# Impedir que o Android desligue a CPU/Wi-Fi quando a tela apagar
echo "[*] Ativando Termux Wake-Lock (CPU ativa em segundo plano)..."
termux-wake-lock

# Obter IP local da rede Wi-Fi no Android
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo "============================================="
echo "   🚀 SERVIDOR NAS ANDROID INICIADO!         "
echo "============================================="
echo " Acesse pelo navegador em qualquer aparelho:"
echo " 👉 http://${IP_LOCAL:-127.0.0.1}:8080"
echo "============================================="
echo " Pressione CTRL + C para encerrar o servidor."
echo ""

# Iniciar servidor Python FastAPI
python app.py
