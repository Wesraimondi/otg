#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
#   Script de Instalação e Permissões - Android NAS / OTG
# ==========================================================

clear
echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;32m      🚀 INSTALADOR DO SISTEMA NAS PARA ANDROID (OTG)   \033[0m"
echo -e "\033[1;36m========================================================\033[0m"
echo ""

# 1. Solicitar permissões de armazenamento do Android
echo -e "\033[1;33m[1/4] Solicitando permissão de armazenamento do Android...\033[0m"
echo -e "👉 \033[1;37mOlhe para a tela do tablet e clique em 'PERMITIR' na janela que abrir.\033[0m"
termux-setup-storage
sleep 3

# 2. Atualizar repositórios do Termux e instalar Python
echo ""
echo -e "\033[1;33m[2/4] Atualizando pacotes e instalando Python...\033[0m"
pkg update -y && pkg upgrade -y
pkg install -y python git

# 3. Dar permissão de execução a todos os scripts .sh
echo ""
echo -e "\033[1;33m[3/4] Configurando permissões dos arquivos...\033[0m"
chmod +x *.sh 2>/dev/null || true

# 4. Ativar Wake-Lock (impede o Android de desligar o Termux em 2º plano)
echo ""
echo -e "\033[1;33m[4/4] Ativando Wake-Lock para segundo plano...\033[0m"
termux-wake-lock

# Obter IP local da rede Wi-Fi
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo ""
echo -e "\033[1;32m========================================================\033[0m"
echo -e "\033[1;32m   ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                 \033[0m"
echo -e "\033[1;32m========================================================\033[0m"
echo ""
echo -e "Para iniciar o seu servidor NAS, execute:"
echo -e "👉 \033[1;37m./start.sh\033[0m   (ou \033[1;37mpython app.py\033[0m)"
echo ""
if [ -n "$IP_LOCAL" ]; then
    echo -e "O painel web estará acessível em: \033[1;36mhttp://${IP_LOCAL}:8080\033[0m"
else
    echo -e "O painel web estará acessível em: \033[1;36mhttp://IP_DO_TABLET:8080\033[0m"
fi
echo -e "\033[1;36m========================================================\033[0m"
