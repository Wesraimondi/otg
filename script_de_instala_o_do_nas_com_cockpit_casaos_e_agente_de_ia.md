#!/usr/bin/env bash

# Encerra o script caso algum comando retorne erro
set -e

# Configuração de cores para o terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   INSTALAÇÃO: NAS + COCKPIT + CASAOS + AGENTE IA  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Validação de privilégios de superusuário
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERRO] Execute este script com permissões de administrador: sudo ./setup-nas.sh${NC}"
  exit 1
fi

# 2. Atualização dos repositórios e pacotes do sistema
echo -e "\n${GREEN}[1/5] Atualizando o Ubuntu Server...${NC}"
apt update && apt upgrade -y

# 3. Instalação de ferramentas utilitárias, monitoramento e suporte a rede
echo -e "\n${GREEN}[2/5] Instalando utilitários essenciais do sistema...${NC}"
apt install -y \
    curl \
    wget \
    git \
    net-tools \
    htop \
    iotop \
    ncdu \
    smartmontools \
    cifs-utils \
    samba-common

# 4. Instalação e ativação do Cockpit (Gerenciamento de discos e sistema)
echo -e "\n${GREEN}[3/5] Configurando o Cockpit e módulos de disco...${NC}"
apt install -y \
    cockpit \
    cockpit-storaged \
    cockpit-networkmanager \
    cockpit-packagekit

systemctl enable --now cockpit.socket

# 5. Instalação automatizada do CasaOS (instala o Docker como dependência)
echo -e "\n${GREEN}[4/5] Instalando o CasaOS...${NC}"
curl -fsSL https://get.casaos.io | bash

# 6. Configuração da infraestrutura de IA (Ollama + Open WebUI)
echo -e "\n${GREEN}[5/5] Configurando o motor de IA local (Ollama) e Open WebUI...${NC}"
curl -fsSL https://ollama.com/install.sh | sh

# Aguarda inicialização do daemon do Ollama
sleep 3

# Baixa o modelo leve otimizado para escrita criativa e brainstorming
echo -e "\n${GREEN}Baixando modelo Llama 3.2 (3B) para escrita do livro...${NC}"
ollama pull llama3.2:3b

# Sobe o Open WebUI via Docker para interface web de chat/documentos
echo -e "\n${GREEN}Iniciando a interface web do agente de escrita (Open WebUI)...${NC}"
docker run -d \
  --network=host \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

# Identificação do IP na rede local
SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || hostname -I | awk '{print $1}')

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}          INSTALAÇÃO FINALIZADA COM SUCESSO!         ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "Acesse os serviços pelo navegador dos seus dispositivos:"
echo -e "  ➜  ${YELLOW}Agente de Escrita (Open WebUI):${NC} http://${SERVER_IP}:8080"
echo -e "  ➜  ${YELLOW}CasaOS (Nuvem e Apps):${NC}         http://${SERVER_IP}"
echo -e "  ➜  ${YELLOW}Cockpit (Discos e Hardware):${NC}   https://${SERVER_IP}:9090"
echo -e "\n${YELLOW}Nota para o Cockpit:${NC} Conecte via HTTPS e use seu usuário/senha do Linux."
echo -e "${BLUE}====================================================${NC}"