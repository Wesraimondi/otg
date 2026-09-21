#!/data/data/com.termux/files/usr/bin/bash

# Impedir suspensão em segundo plano
termux-wake-lock 2>/dev/null || true

# Obter IP local da rede Wi-Fi
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;32m   🚀 SERVIDOR NAS ANDROID INICIADO!                    \033[0m"
echo -e "\033[1;36m========================================================\033[0m"
echo -e " Acesse pelo navegador em qualquer aparelho na mesma rede:"
if [ -n "$IP_LOCAL" ]; then
    echo -e " 👉 \033[1;33mhttp://${IP_LOCAL}:8080\033[0m"
else
    echo -e " 👉 \033[1;33mhttp://127.0.0.1:8080\033[0m"
fi
echo -e "\033[1;36m========================================================\033[0m"
echo -e " Pressione \033[1;31mCTRL + C\033[0m para encerrar o servidor."
echo ""

python app.py
