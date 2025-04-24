#!/bin/bash

# Enable resolution of libcudnn_ops_infer.so.8
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/app/xtts-finetune-webui/.local/lib/python3.11/site-packages/torch/lib:/app/xtts-finetune-webui/.local/lib/python3.11/site-packages/nvidia/cudnn/lib"

# ====== БЛОК 6: Установка torch, torchaudio, torchvision ======
pip install torch==2.1.1+cu118 torchaudio==2.1.1+cu118 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118

# ====== БЛОК 7: Установка зависимостей проекта ======
pip install -r requirements.txt

python3 xtts_demo.py
