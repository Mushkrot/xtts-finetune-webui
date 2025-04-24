#!/bin/bash

set -e

# Функция для вывода инструкции по ручной установке cuDNN
show_cudnn_manual_instructions() {
    echo "\n========================================================"
    echo "[КАК СКАЧАТЬ cuDNN ВРУЧНУЮ]"
    echo "1. Откройте: https://developer.nvidia.com/rdp/cudnn-archive"
    echo "4. Для CUDA 10.1 выберите 'cuDNN v7.6.5 for CUDA 10.1'"
    echo "5. В появившемся списке выберите:\n   - cuDNN Runtime Library for Ubuntu18.04 (Deb)\n   - (опционально) cuDNN Developer Library for Ubuntu18.04 (Deb)"
    echo "   НЕ выбирайте: 'Library for Linux', 'Code Samples', 'User Guide'!"
    echo "6. Скачайте файл, который заканчивается на _amd64.deb"
    echo "7. Загрузите файл на сервер и выполните:"
    echo "   sudo dpkg -i имя_скачанного_файла.deb"
    echo "8. После установки запустите этот скрипт снова"
    echo "========================================================\n"
}

# Проверка и установка утилиты file (для диагностики deb-файлов)
if ! command -v file &>/dev/null; then
    echo "[INFO] Утилита 'file' не найдена, устанавливаю..."
    sudo apt-get update && sudo apt-get install -y file
fi

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

# === БЛОК: Проверка и установка драйверов NVIDIA, CUDA и cuDNN ===
print_status "Проверка наличия драйверов NVIDIA..."
if ! command -v nvidia-smi &> /dev/null; then
    print_warning "Драйверы NVIDIA не найдены! Устанавливаю последние драйверы..."
    sudo apt-get update
    sudo apt-get install -y ubuntu-drivers-common
    sudo ubuntu-drivers autoinstall
    if ! command -v nvidia-smi &> /dev/null; then
        print_error "Не удалось установить драйверы NVIDIA. Завершаю работу."
        exit 1
    fi
    print_success "Драйверы NVIDIA успешно установлены."
else
    print_success "Драйверы NVIDIA найдены: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
fi

print_status "Проверка наличия CUDA toolkit..."
if ! command -v nvcc &> /dev/null; then
    print_warning "CUDA toolkit не найден! Устанавливаю CUDA 11.8..."
    # Определяем дистрибутив для выбора репозитория
    . /etc/os-release
    DISTRO_ID=${ID:-ubuntu}
    DISTRO_VERSION=${VERSION_ID:-20.04}
    CUDA_REPO="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_ID}${DISTRO_VERSION/./}/x86_64/"
    CUDA_PIN="cuda-${DISTRO_ID}${DISTRO_VERSION/./}.pin"
    wget -q ${CUDA_REPO}${CUDA_PIN}
    sudo mv ${CUDA_PIN} /etc/apt/preferences.d/cuda-repository-pin-600
    sudo apt-key adv --fetch-keys ${CUDA_REPO}3bf863cc.pub
    sudo add-apt-repository -y "deb ${CUDA_REPO} /"
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-11-8
    print_success "CUDA 11.8 установлена."
else
    print_status "CUDA toolkit найдена: $(nvcc --version | grep release)"
fi

# === Универсальная проверка и установка cuDNN ===
# Проверка через dpkg и наличие .so файлов
if dpkg -s libcudnn7 &>/dev/null; then
    print_success "cuDNN уже установлен (через dpkg). Пропускаю загрузку и установку."
else
    CUDNN_SO=$(find /usr/local/cuda/lib64/ -name 'libcudnn_ops*.so*' 2>/dev/null | head -n1)

# Определяем версию CUDA
CUDA_VERSION=""
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep release | sed 's/.*release \([0-9]*\.[0-9]*\).*/\1/')
    print_status "Обнаружена CUDA версии $CUDA_VERSION"
else
    print_warning "CUDA не найдена, установка cuDNN невозможна!"
fi

    if [ -z "$CUDNN_SO" ]; then
    if [ -n "$CUDA_VERSION" ]; then
        case "$CUDA_VERSION" in
            11.8)
                CUDNN_DEB="libcudnn8_8.9.7.29-1+cuda11.8_amd64.deb"
                CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.9.7/$CUDNN_DEB"
                ;;
            11.7)
                CUDNN_DEB="libcudnn8_8.6.0.163-1+cuda11.7_amd64.deb"
                CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/$CUDNN_DEB"
                ;;
            11.6)
                CUDNN_DEB="libcudnn8_8.4.1.50-1+cuda11.6_amd64.deb"
                CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.4.1/$CUDNN_DEB"
                ;;
            10.2)
                CUDNN_DEB="libcudnn8_8.0.5.39-1+cuda10.2_amd64.deb"
                CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.0.5/$CUDNN_DEB"
                ;;
            10.1)
                CUDNN_DEB="libcudnn7_7.6.5.32-1+cuda10.1_amd64.deb"
                CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v7.6.5/$CUDNN_DEB"
                ;;
            *)
                print_warning "Автоматическая установка cuDNN не поддерживается для CUDA $CUDA_VERSION. Скачайте cuDNN вручную с https://developer.nvidia.com/rdp/cudnn-archive"
                CUDNN_URL=""
                ;;
        esac
        if [ -n "$CUDNN_URL" ]; then
            print_status "Скачиваю cuDNN для CUDA $CUDA_VERSION..."
            set +e
            wget --timeout=30 --tries=2 -q $CUDNN_URL
            WGET_EXIT=$?
            if [ -f "$CUDNN_DEB" ] && [ -s "$CUDNN_DEB" ]; then
                FILE_TYPE=$(file "$CUDNN_DEB")
                FILE_SIZE=$(stat -c %s "$CUDNN_DEB")
                # Проверяем, что это действительно deb-файл и его размер больше 1 МБ
                if echo "$FILE_TYPE" | grep -q 'Debian binary package' && [ "$FILE_SIZE" -gt 1000000 ]; then
                    sudo dpkg -i $CUDNN_DEB
                    DPKG_EXIT=$?
                    rm -f $CUDNN_DEB
                    if [ $DPKG_EXIT -eq 0 ]; then
                        print_success "cuDNN установлен для CUDA $CUDA_VERSION."
                    else
                        print_error "dpkg завершился с ошибкой ($DPKG_EXIT)!"
                        show_cudnn_manual_instructions
                        exit 1
                    fi
                else
                    print_error "Файл $CUDNN_DEB не является deb-пакетом или слишком мал!"
                    echo "Тип файла: $FILE_TYPE"
                    echo "Размер файла: $FILE_SIZE байт"
                    echo "Первые 10 строк файла:"
                    head "$CUDNN_DEB"
                    rm -f $CUDNN_DEB
                    show_cudnn_manual_instructions
                    exit 1
                fi
            else
                print_error "Не удалось скачать cuDNN ($CUDNN_DEB) для CUDA $CUDA_VERSION! (wget exit code: $WGET_EXIT)"
                show_cudnn_manual_instructions
                exit 1
            fi
            set -e

        fi
    else
        print_warning "Не удалось определить версию CUDA для установки cuDNN. Пропускаю установку cuDNN."
    fi
else
    print_success "cuDNN найден: $CUDNN_SO"
fi
fi

# Экспорт LD_LIBRARY_PATH для CUDA и torch
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:$(pwd)/venv-xttsf/lib/python3.11/site-packages/torch/lib:$LD_LIBRARY_PATH"
print_success "LD_LIBRARY_PATH set: $LD_LIBRARY_PATH"

# Корректная проверка наличия libcudnn_ops.so в каждом пути LD_LIBRARY_PATH
FOUND_CUDNN_OPS=0
IFS=":" read -ra CUDA_PATHS <<< "$LD_LIBRARY_PATH"
for p in "${CUDA_PATHS[@]}"; do
    if [ -d "$p" ] && ls "$p"/libcudnn_ops*.so* 1>/dev/null 2>&1; then
        print_success "libcudnn_ops.so найден в $p"
        FOUND_CUDNN_OPS=1
        break
    fi
done
if [ $FOUND_CUDNN_OPS -eq 0 ]; then
    print_warning "libcudnn_ops.so не найден ни в одном каталоге из LD_LIBRARY_PATH! Возможны ошибки при запуске с GPU."
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

# 5. Универсальная установка torch, torchaudio, torchvision под вашу CUDA
pip install --upgrade pip

TORCH_INDEX_URL=""
TORCH_VERSION=""
TORCHAUDIO_VERSION=""
TORCHVISION_VERSION=""

if [ -n "$CUDA_VERSION" ]; then
    case "$CUDA_VERSION" in
        11.8)
            TORCH_INDEX_URL="https://download.pytorch.org/whl/cu118"
            TORCH_VERSION="2.1.2+cu118"
            TORCHAUDIO_VERSION="2.1.2+cu118"
            TORCHVISION_VERSION="0.16.2+cu118"
            ;;
        11.7)
            TORCH_INDEX_URL="https://download.pytorch.org/whl/cu117"
            TORCH_VERSION="2.0.1+cu117"
            TORCHAUDIO_VERSION="2.0.2+cu117"
            TORCHVISION_VERSION="0.15.2+cu117"
            ;;
        11.6)
            TORCH_INDEX_URL="https://download.pytorch.org/whl/cu116"
            TORCH_VERSION="1.13.1+cu116"
            TORCHAUDIO_VERSION="0.13.1+cu116"
            TORCHVISION_VERSION="0.14.1+cu116"
            ;;
        10.2)
            TORCH_INDEX_URL="https://download.pytorch.org/whl/cu102"
            TORCH_VERSION="1.12.1+cu102"
            TORCHAUDIO_VERSION="0.12.1+cu102"
            TORCHVISION_VERSION="0.13.1+cu102"
            ;;
        10.1)
            TORCH_INDEX_URL="https://download.pytorch.org/whl/cu101"
            TORCH_VERSION="1.7.1+cu101"
            TORCHAUDIO_VERSION="0.7.2"
            TORCHVISION_VERSION="0.8.2+cu101"
            ;;
        *)
            print_warning "Автоматическая установка torch не поддерживается для CUDA $CUDA_VERSION. Пожалуйста, установите вручную."
            ;;
    esac
else
    print_warning "CUDA не найдена, будет установлена CPU-версия torch."
    TORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
    TORCH_VERSION="2.1.2+cpu"
    TORCHAUDIO_VERSION="2.1.2+cpu"
    TORCHVISION_VERSION="0.16.2+cpu"
fi

if [ -n "$TORCH_INDEX_URL" ] && [ -n "$TORCH_VERSION" ]; then
    INSTALLED_TORCH=$(python -c 'import torch; print(getattr(torch, "__version__", ""))' 2>/dev/null || echo "none")
    if [[ "$INSTALLED_TORCH" == "$TORCH_VERSION" ]]; then
        print_status "torch $TORCH_VERSION уже установлен."
    else
        print_status "Устанавливаю torch==$TORCH_VERSION, torchaudio==$TORCHAUDIO_VERSION, torchvision==$TORCHVISION_VERSION"
        pip install torch==${TORCH_VERSION} torchaudio==${TORCHAUDIO_VERSION} torchvision==${TORCHVISION_VERSION} --index-url $TORCH_INDEX_URL
        print_success "torch, torchaudio, torchvision установлены."
    fi
else
    print_warning "torch не был установлен автоматически. Установите вручную."
fi
print_success "torch, torchaudio, torchvision setup complete"

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