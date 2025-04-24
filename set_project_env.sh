#!/bin/bash
# Установить переменные окружения для хранения всех моделей и кэша только внутри проекта
export TTS_CACHE_PATH="$(pwd)/base_models"
export COQUI_TTS_HOME="$(pwd)/base_models"
export HF_HOME="$(pwd)/base_models/huggingface"
export XDG_CACHE_HOME="$(pwd)/base_models/xdg_cache"

# Для запуска webui:
# source ./set_project_env.sh
# python xtts_demo.py
