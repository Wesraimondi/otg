# 🚀 Android Tablet NAS (com Suporte a OTG & Streaming)

Sistema de NAS (*Network Attached Storage*) leve, moderno e responsivo, desenvolvido em **Python + FastAPI** especialmente para rodar em tablets Android via **Termux**.

---

## 🌟 Recursos Principais

- 🔌 **Suporte Total a OTG / Pen Drive / HD Externo**: Detecta automaticamente dispositivos conectados na porta USB OTG (`/storage/XXXX-XXXX`) e o armazenamento interno (`/storage/emulated/0`).
- ⚡ **Monitoramento em Tempo Real**: Exibe status da bateria do tablet (porcentagem e carregador), medidor de espaço por unidade e uso de RAM/CPU.
- 📁 **Gerenciador de Arquivos Completo**: Upload com barra de progresso (drag-and-drop), download, exclusão, renomeação e download de pastas inteiras em formato `.ZIP`.
- 🎬 **Central Multimídia (Streaming)**:
  - Player de vídeo com suporte a avanço de reprodução (*HTTP Range*).
  - Player de áudio com reprodução contínua.
  - Galeria de fotos em alta resolução.
  - Visualizador de arquivos de código e texto.
- 📱 **Interface Touch-Friendly & Dark Mode**: Otimizada para telas de tablet, celular e navegadores de computador (Windows, Mac, Linux).

---

## 📲 Como Instalar e Rodar no Tablet Android

### 1. Pré-requisitos no Tablet
1. Instale o **Termux** (baixe a versão mais recente pelo [F-Droid](https://f-droid.org/packages/com.termux/)).
2. Conecte o seu pen drive ou HD externo no adaptador **OTG** do tablet.

### 2. Baixar e Configurar no Termux

Abra o Termux no tablet e execute os comandos:

```bash
# Baixar o repositório ou copiar a pasta para o Termux
cd ~
git clone <URL_DO_SEU_REPOSITORIO> android-nas   # ou copie os arquivos
cd android-nas

# Executar a instalação automática das dependências
chmod +x setup_termux.sh start.sh
./setup_termux.sh
```

### 3. Iniciar o Servidor NAS

Sempre que quiser ligar o NAS no tablet:

```bash
./start.sh
```

O terminal mostrará o endereço de acesso, por exemplo:
`http://192.168.1.150:8080`

Abra este endereço no navegador de qualquer computador, TV, celular ou no próprio tablet conectado na mesma rede Wi-Fi!

---

## 💡 Dicas de Ouro para Uso Contínuo

1. **Evitar que o Android mate o processo**:
   - O comando `termux-wake-lock` já é executado automaticamente pelo `./start.sh`.
   - Nas configurações do Android, vá em **Aplicativos** > **Termux** > **Bateria** e selecione **Irrestrito / Não otimizar**.
2. **Carregamento + OTG Simultâneo**:
   - Utilize um cabo ou hub **OTG com Power Delivery (Pass-Through)** para manter o tablet sempre carregando na tomada enquanto alimenta o HD externo/Pen drive.
