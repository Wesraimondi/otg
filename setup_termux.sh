#!/data/data/com.termux/files/usr/bin/bash

echo "============================================="
echo "   Configurando Servidor NAS no Termux       "
echo "============================================="

# 1. Solicitar permissões de armazenamento do Android
echo "[*] Solicitando permissão de armazenamento (aceite no pop-up do Android)..."
termux-setup-storage

# 2. Atualizar repositórios
echo "[*] Atualizando pacotes..."
pkg update -y && pkg upgrade -y

# 3. Instalar Python, Git e ferramentas básicas
echo "[*] Instalando Python e utilitários..."
pkg install -y python git clang libjpeg-turbo

# 4. Instalar dependências Python
echo "[*] Instalando bibliotecas do NAS..."
pip install --upgrade pip
pip install -r requirements.txt

# 5. Dar permissão de execução ao script de inicialização
chmod +x start.sh

echo ""
echo "============================================="
echo "   Instalação concluída com sucesso!         "
echo "   Para iniciar o NAS, execute: ./start.sh   "
echo "============================================="
