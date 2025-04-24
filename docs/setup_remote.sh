#!/bin/bash

# Скрипт для автоматической установки coqui-ai/TTS и alltalk_tts на удаленном сервере

set -e

# ====== НАСТРОЙКА ВЫВОДА ======
# Цветовые коды для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода сообщений
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_status "Начало установки coqui-ai/TTS и alltalk_tts на удаленном сервере..."

touch ~/.no_auto_tmux
print_status "Отключён автозапуск tmux (создан ~/.no_auto_tmux)"

# ====== БЛОК 1: СОЗДАНИЕ НЕОБХОДИМЫХ ДИРЕКТОРИЙ ======
print_status "БЛОК 1: Создание необходимых директорий"
echo -e "\n\n"

# Создание директории /ai, если она не существует
if [ ! -d "/ai" ]; then
    sudo mkdir -p /ai
    sudo chown $(whoami):$(whoami) /ai
    print_status "Создана директория /ai"
else
    print_status "Директория /ai уже существует"
fi

# Создание директории /ai/vits, если она не существует
if [ ! -d "/ai/vits" ]; then
    mkdir -p /ai/vits
    print_status "Создана директория /ai/vits"
else
    print_status "Директория /ai/vits уже существует"
fi

print_success "Директории созданы успешно."
echo -e "\n\n"

# ====== БЛОК 2: ОБНОВЛЕНИЕ СИСТЕМЫ И УСТАНОВКА БАЗОВЫХ ПАКЕТОВ ======
print_status "БЛОК 2: Обновление системы и установка базовых пакетов"

# Обновление системы
print_status "Обновление системы"
sudo apt update
sudo apt upgrade -y

# Настройка команды py для запуска python
# print_status "Настройка команды py для запуска python"
# sudo ln -sf "$(which python3)" /usr/local/bin/py

# Установка необходимых утилит
print_status "Проверка и установка необходимых утилит"

# Список необходимых утилит
requirements=(
    "git" "curl" "wget"
    "file" "grep" "less" "locate" "rsync"
    "htop" "ncdu" "iotop" "iftop" "lsof" "tree"
    "unzip" "zip"
)
missing_requirements=()

# Проверка наличия утилит
for req in "${requirements[@]}"; do
    if ! command -v "$req" &> /dev/null; then
        missing_requirements+=("$req")
    fi
done

# Установка отсутствующих утилит
if [ ${#missing_requirements[@]} -ne 0 ]; then
    print_warning "Отсутствуют следующие утилиты: ${missing_requirements[*]}"
    print_status "Установка отсутствующих утилит..."
    
    sudo apt install -y "${missing_requirements[@]}"
    
    # Проверка успешности установки
    for req in "${missing_requirements[@]}"; do
        if ! command -v "$req" &> /dev/null; then
            print_error "Не удалось установить $req. Пожалуйста, установите его вручную."
            exit 1
        fi
    done
fi

# Установка nodejs (без fast-cli)
print_status "Проверка и установка nodejs и npm"

# Проверка наличия nodejs
if command -v node &> /dev/null; then
    node_version=$(node -v)
    print_success "NodeJS уже установлен: $node_version"
else
    print_status "Установка NodeJS..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "NodeJS установлен: $(node -v)"
fi

# Проверка и установка утилиты testspeed
print_status "Проверка и установка утилиты testspeed для тестирования скорости интернета"
if command -v speedtest-cli &> /dev/null; then
    print_success "speedtest-cli уже установлен: $(speedtest-cli --version 2>&1)"
else
    print_status "Попытка установки speedtest-cli..."
    if command -v pip3 &> /dev/null; then
        pip3 install speedtest-cli || {
            print_warning "Не удалось установить speedtest-cli через pip3. Пробуем через apt..."
            sudo apt install -y speedtest-cli || {
                print_warning "Не удалось установить speedtest-cli. Пропускаем этот шаг, так как утилита не является критичной."
            }
        }
        if command -v speedtest-cli &> /dev/null; then
            print_success "speedtest-cli успешно установлен"
        fi
    else
        print_status "Установка speedtest-cli через apt..."
        sudo apt install -y speedtest-cli || {
            print_warning "Не удалось установить speedtest-cli. Пропускаем этот шаг, так как утилита не является критичной."
        }
        if command -v speedtest-cli &> /dev/null; then
            print_success "speedtest-cli успешно установлен"
        fi
    fi
fi
echo -e "\n\n"

# ====== БЛОК 2: УСТАНОВКА GPU ДРАЙВЕРОВ И БИБЛИОТЕК ======
print_status "БЛОК 3: Установка GPU драйверов и библиотек"
echo -e "\n\n"

# Проверка наличия CUDA
print_status "Проверка наличия CUDA"
if command -v nvidia-smi &> /dev/null; then
    cuda_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
    print_success "CUDA уже установлена. Версия драйвера NVIDIA: $cuda_version"
    print_status "Информация о GPU:"
    nvidia-smi
    print_success "CUDA найдена."
else
    print_warning "Команда nvidia-smi не найдена. Возможно, CUDA не установлена или не настроена."
    print_warning "Это может привести к проблемам при работе с GPU."
fi

# Проверка наличия cuDNN
print_status "Проверка наличия cuDNN"
if dpkg -l | grep -q libcudnn8; then
    cudnn_version=$(dpkg -l | grep libcudnn8 | head -n 1 | awk '{print $3}')
    print_success "cuDNN уже установлен. Версия: $cudnn_version"
else
    print_status "Скачивание и установка cuDNN 9.8.0"
    wget -q https://developer.download.nvidia.com/compute/cudnn/9.8.0/local_installers/cudnn-local-repo-ubuntu2004-9.8.0_1.0-1_amd64.deb
    sudo dpkg -i cudnn-local-repo-ubuntu2004-9.8.0_1.0-1_amd64.deb
    sudo cp /var/cudnn-local-repo-ubuntu2004-9.8.0/cudnn-local-*-keyring.gpg /usr/share/keyrings/
    sudo apt update
    print_status "Установка cuDNN..."
    sudo apt install -y libcudnn8 libcudnn8-dev libcudnn8-samples
    print_success "cuDNN установлен"
fi

# Установка зависимостей для DeepSpeed
# Установка NVIDIA CUDA Toolkit
if command -v nvcc &> /dev/null; then
    cuda_toolkit_version=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
    print_success "NVIDIA CUDA Toolkit уже установлен. Версия: $cuda_toolkit_version"
else
    print_status "Установка NVIDIA CUDA Toolkit..."
    sudo apt install -y nvidia-cuda-toolkit
    print_success "NVIDIA CUDA Toolkit установлен"
fi
# Проверка наличия libaio-dev для DeepSpeed
if dpkg -l | grep -q libaio-dev; then
    print_success "libaio-dev уже установлен"
else
    print_status "Установка libaio-dev для DeepSpeed..."
    sudo apt install -y libaio-dev
    print_success "libaio-dev установлен"
fi

# Настройка переменной окружения CUDA_HOME
print_status "Настройка переменной окружения CUDA_HOME"
CUDA_PATH=$(which nvcc | rev | cut -d'/' -f3- | rev)

# Проверка наличия CUDA_HOME в ~/.bashrc
if ! grep -q "export CUDA_HOME=" ~/.bashrc; then
    echo "export CUDA_HOME=$CUDA_PATH" >> ~/.bashrc
    print_status "CUDA_HOME добавлен в ~/.bashrc"
else
    print_status "CUDA_HOME уже присутствует в ~/.bashrc"
fi

# Проверка наличия CUDA_HOME в ~/.profile
if ! grep -q "export CUDA_HOME=" ~/.profile; then
    echo "export CUDA_HOME=$CUDA_PATH" >> ~/.profile
    print_status "CUDA_HOME добавлен в ~/.profile"
else
    print_status "CUDA_HOME уже присутствует в ~/.profile"
fi

# Применение переменной окружения для текущей сессии
export CUDA_HOME=$CUDA_PATH
print_status "CUDA_HOME установлен в $CUDA_HOME"
echo -e "\n\n"

print_success "Зависимости для DeepSpeed установлены"

# ====== БЛОК 3: КЛОНИРОВАНИЕ И УСТАНОВКА РЕПОЗИТОРИЕВ ======
print_status "БЛОК 4: Клонирование и установка репозиториев"

# Клонирование репозитория coqui-ai/TTS
print_status "Клонирование репозитория coqui-ai/TTS"
if [ -d "/ai/vits/src" ]; then
    print_warning "Директория /ai/vits/src уже существует."
    read -p "Хотите удалить существующую директорию и клонировать заново? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        rm -rf /ai/vits/src
    else
        print_status "Пропуск клонирования coqui-ai/TTS."
    fi
fi

if [ ! -d "/ai/vits/src" ]; then
    cd /ai/vits
    git clone https://github.com/coqui-ai/TTS.git src
    
    if [ $? -ne 0 ]; then
        print_error "Не удалось клонировать репозиторий coqui-ai/TTS."
        exit 1
    fi
    
    print_success "Репозиторий coqui-ai/TTS успешно клонирован в /ai/vits/src."
fi

# Клонирование репозитория alltalk_tts
print_status "Клонирование репозитория alltalk_tts"
if [ -d "/ai/vits/alltalk_tts" ]; then
    print_warning "Директория /ai/vits/alltalk_tts уже существует."
    read -p "Хотите удалить существующую директорию и клонировать заново? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        rm -rf /ai/vits/alltalk_tts
    else
        print_status "Пропуск клонирования alltalk_tts."
    fi
fi

if [ ! -d "/ai/vits/alltalk_tts" ]; then
    cd /ai/vits
    git clone https://github.com/erew123/alltalk_tts.git
    
    if [ $? -ne 0 ]; then
        print_error "Не удалось клонировать репозиторий alltalk_tts."
        exit 1
    fi
    
    print_success "Репозиторий alltalk_tts успешно клонирован в /ai/vits/alltalk_tts."
fi

# Установка alltalk_tts
print_status "Установка alltalk_tts"
if [ ! -f "/ai/vits/alltalk_tts/atsetup.sh" ]; then
    print_error "Файл установщика alltalk_tts не найден."
    exit 1
fi

# Делаем скрипт исполняемым
chmod +x /ai/vits/alltalk_tts/atsetup.sh

# Информация о подготовленных зависимостях DeepSpeed
print_status "Информация о подготовленных зависимостях DeepSpeed:"
print_status "- NVIDIA CUDA Toolkit установлен"
print_status "- CUDA_HOME установлен в $CUDA_HOME"
print_status "- libaio-dev установлен"
print_status "Все зависимости для DeepSpeed подготовлены."

# Запуск установщика в автоматическом режиме
print_warning "Сейчас будет запущен установщик alltalk_tts."
print_warning "Вам нужно будет выбрать опцию '2' для Standalone Application, а затем '1' для установки."
print_warning "При запросе установки DeepSpeed можно безопасно выбрать 'y', так как все зависимости уже установлены."
print_warning "После завершения установки выберите '9' для выхода."
print_status "Нажмите Enter, чтобы продолжить..."
read

if [ -d "/ai/vits/alltalk_tts/alltalk_environment/env" ]; then
    print_warning "Окружение уже существует. Удалить и пересоздать? (y/n)"
    read confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -rf /ai/vits/alltalk_tts/alltalk_environment/env
        print_status "Окружение удалено."
    else
        print_status "Пропуск пересоздания окружения."
    fi
fi

cd /ai/vits/alltalk_tts
./atsetup.sh

print_success "Установка alltalk_tts завершена."
echo -e "\n\n"

print_status "Проверка и установка дополнительных Python-пакетов: protobuf==3.20.3 и tensorflow-cpu"

source "/ai/vits/alltalk_tts/alltalk_environment/conda/etc/profile.d/conda.sh"
conda activate "/ai/vits/alltalk_tts/alltalk_environment/env"

# Проверка наличия protobuf и tensorflow-cpu
protobuf_installed=$(python -c "import pkg_resources; print(pkg_resources.get_distribution('protobuf').version)" 2>/dev/null || echo "not_installed")
tensorflow_installed=$(python -c "import tensorflow; print('installed')" 2>/dev/null || echo "not_installed")

if [ "$protobuf_installed" == "3.20.3" ] && [ "$tensorflow_installed" == "installed" ]; then
    print_success "protobuf 3.20.3 и tensorflow-cpu уже установлены"
else
    print_status "Установка protobuf==3.20.3 и tensorflow-cpu..."
    python -m pip install protobuf==3.20.3 tensorflow-cpu || { print_error "Ошибка установки дополнительных компонентов."; exit 1; }
    print_success "protobuf 3.20.3 и tensorflow-cpu установлены"
fi

# Запуск modeldownload.py в виртуальном окружении
print_status "Запуск скрипта modeldownload.py для загрузки моделей..."

# Проверка наличия файла modeldownload.py
if [ -f "/ai/vits/alltalk_tts/modeldownload.py" ]; then
    cd /ai/vits/alltalk_tts
    python modeldownload.py
    if [ $? -eq 0 ]; then
        print_success "Скрипт modeldownload.py успешно выполнен"
    else
        print_error "Ошибка при выполнении скрипта modeldownload.py"
    fi
else
    print_warning "Файл modeldownload.py не найден в директории /ai/vits/alltalk_tts"
fi

echo -e "\n\n"

# Очистка ненужных временных файлов
print_status "Очистка временных файлов и кэша..."
rm -f cudnn-local-repo-*.deb
rm -f *.tmp *.temp
rm -rf /tmp/pip-* /tmp/npm-* 2>/dev/null || true

# Очистка кэша apt
print_status "Очистка кэша apt..."
sudo apt clean
sudo apt autoclean

# Очистка кэша Conda
print_status "Очистка кэша Conda..."
conda clean --all -y

print_success "Очистка временных файлов и кэша завершена"
