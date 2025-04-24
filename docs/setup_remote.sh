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

# === БЛОК: Установка и проверка CUDA/cuDNN ===
print_status "Checking CUDA toolkit installation..."
if ! command -v nvcc &> /dev/null; then
    print_warning "CUDA toolkit not found! Installing CUDA 11.8..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
    sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-11-8
    print_success "CUDA 11.8 installed."
else
    print_status "CUDA toolkit found: $(nvcc --version | grep release)"
fi

# Проверка наличия cuDNN
CUDNN_SO=$(find /usr/local/cuda/lib64/ -name 'libcudnn_ops*.so*' 2>/dev/null | head -n1)
if [ -z "$CUDNN_SO" ]; then
    print_warning "cuDNN не найден! Для работы PyTorch с GPU требуется cuDNN 8.x для CUDA 11.8."
    print_warning "Установите cuDNN вручную, если требуется поддержка GPU."
else
    print_success "cuDNN найден: $CUDNN_SO"
fi

# Экспорт LD_LIBRARY_PATH для CUDA и torch
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$(pwd)/venv-xttsf/lib/python3.11/site-packages/torch/lib:$LD_LIBRARY_PATH"
print_success "LD_LIBRARY_PATH set: $LD_LIBRARY_PATH"

# Проверка наличия libcudnn_ops.so
if ! find $LD_LIBRARY_PATH -name 'libcudnn_ops*.so*' | grep -q .; then
    print_warning "libcudnn_ops.so не найден в LD_LIBRARY_PATH! Возможны ошибки при запуске с GPU."
else
    print_success "libcudnn_ops.so найден в LD_LIBRARY_PATH."
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

# 5. Установка torch, torchaudio, torchvision (CUDA 11.8)
pip install --upgrade pip
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

# 6. Установка зависимостей проекта
print_status "Installing project dependencies"
pip install -r requirements.txt
print_success "Project dependencies installed"

# 7. Копирование кастомного transcribe.py
print_status "Replacing faster_whisper/transcribe.py with custom version from docs..."
FW_PATH="venv-xttsf/lib/python3.11/site-packages/faster_whisper/transcribe.py"
if [ -f "$FW_PATH" ]; then
    cp "$FW_PATH" "$FW_PATH.bak"
    print_status "Backup of original transcribe.py created."
fi
cp "/ai/xtts-finetune-webui/docs/transcribe.py" "$FW_PATH"
print_success "Custom transcribe.py copied to $FW_PATH"

# 8. Настройка переменных окружения (если есть)
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

# === Мониторинг простоя контейнера ===
if [ -f /monitor_shutdown.sh ]; then
    chmod +x /monitor_shutdown.sh
    echo "\nmonitor_shutdown.sh готов.\n"
    # Попытка автоматически добавить CMD в Dockerfile, если он есть
    if [ -f /ai/xtts-finetune-webui/Dockerfile ]; then
        grep -q '^CMD' /ai/xtts-finetune-webui/Dockerfile && \
            sed -i 's/^CMD.*/CMD ["\/monitor_shutdown.sh"]/' /ai/xtts-finetune-webui/Dockerfile || \
            echo 'CMD ["/monitor_shutdown.sh"]' >> /ai/xtts-finetune-webui/Dockerfile
        echo "CMD для monitor_shutdown.sh добавлен в Dockerfile. Пересоберите образ и запускайте контейнер как обычно."
    else
        echo "\n=== ВАЖНО ==="
        echo "Добавьте в ваш Dockerfile строку:"
        echo 'CMD ["/monitor_shutdown.sh"]'
        echo "или запускайте контейнер так:"
        echo 'docker run ... <image> /monitor_shutdown.sh'
    fi
else
    echo "\nmonitor_shutdown.sh не найден в корне контейнера! Положите его в /monitor_shutdown.sh перед сборкой образа."
fi