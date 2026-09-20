#!/data/data/com.termux/files/usr/bin/bash

echo "============================================="
echo "   Configurando Servidor NAS no Termux       "
echo "============================================="

# 1. Solicitar permissões de armazenamento do Android
echo "[*] Solicitando permissão de armazenamento (aceite no pop-up do Android)..."
termux-setup-storage

# 2. Atualizar repositórios e instalar Python
echo "[*] Instalando Python..."
pkg update -y
pkg install -y python

# 3. Dar permissão de execução
chmod +x start.sh

echo ""
echo "============================================="
echo "   Instalação concluída com sucesso!         "
echo "   Para iniciar o NAS, execute: ./start.sh   "
echo "============================================="
