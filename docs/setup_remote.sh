#!/bin/bash

set -e

# Цветовые коды для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_status "Starting xtts-finetune-webui installation..."

# 1. Создание /ai
if [ ! -d "/ai" ]; then
    sudo mkdir -p /ai
    sudo chown $(whoami):$(whoami) /ai
    print_status "Directory /ai created"
else
    print_status "Directory /ai already exists"
fi

# 2. Клонирование репозитория
cd /ai
if [ ! -d "/ai/xtts-finetune-webui" ]; then
    git clone https://github.com/Mushkrot/xtts-finetune-webui.git
    print_success "xtts-finetune-webui cloned"
else
    print_status "Directory /ai/xtts-finetune-webui already exists"
fi

# 3. Проверка и установка Python 3.11
if ! command -v python3.11 &> /dev/null; then
    print_status "Installing Python 3.11 and venv..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-distutils
fi
print_success "Python 3.11 is available"

# 4. Создание и активация venv на базе python3.11
cd /ai/xtts-finetune-webui
python3.11 -m venv venv-xttsf
source venv-xttsf/bin/activate
print_success "Virtual environment venv-xttsf (python3.11) created and activated"

# 4. Установка torch, torchaudio, torchvision (CUDA 11.8)
print_status "Installing torch, torchaudio, torchvision (CUDA 11.8)"
pip install --upgrade pip
# Проверка и установка torch, torchaudio, torchvision (CUDA 11.8, совместимые версии)
REQUIRED_TORCH="2.1.2+cu118"
REQUIRED_TORCHAUDIO="2.1.2+cu118"
REQUIRED_TORCHVISION="0.16.2+cu118"

INSTALLED_TORCH=$(python -c 'import torch; print(getattr(torch, "__version__", ""))' 2>/dev/null || echo "none")
INSTALLED_TORCHAUDIO=$(python -c 'import torchaudio; print(getattr(torchaudio, "__version__", ""))' 2>/dev/null || echo "none")
INSTALLED_TORCHVISION=$(python -c 'import torchvision; print(getattr(torchvision, "__version__", ""))' 2>/dev/null || echo "none")

if [[ "$INSTALLED_TORCH" == "$REQUIRED_TORCH" && "$INSTALLED_TORCHAUDIO" == "$REQUIRED_TORCHAUDIO" && "$INSTALLED_TORCHVISION" == "$REQUIRED_TORCHVISION" ]]; then
    print_status "torch, torchaudio, torchvision already installed and correct versions detected."
else
    print_status "Installing correct versions of torch, torchaudio, torchvision (CUDA 11.8)"
    pip install torch==2.1.2+cu118 torchaudio==2.1.2+cu118 torchvision==0.16.2+cu118 --index-url https://download.pytorch.org/whl/cu118
    print_success "torch, torchaudio, torchvision installed."
fi
print_success "torch, torchaudio, torchvision installed"

# 5. Установка зависимостей проекта
print_status "Installing project dependencies"
pip install -r requirements.txt
print_success "Project dependencies installed"

# 6. Настройка переменных окружения (если есть)
if [ -f "set_project_env.sh" ]; then
    print_status "Sourcing set_project_env.sh"
    source ./set_project_env.sh
    print_success "Project environment variables set"
else
    print_warning "set_project_env.sh not found, skipping env setup"
fi

print_success "xtts-finetune-webui setup complete!"
echo -e "\nTo start the web UI, run:\n"
echo "source /ai/xtts-finetune-webui/venv-xttsf/bin/activate"
echo "python xtts_demo.py"