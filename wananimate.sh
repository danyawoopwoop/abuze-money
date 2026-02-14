#!/usr/bin/env bash
set -e

BASE="/workspace/ComfyUI/models"

mkdir -p $BASE
mkdir -p $BASE/clip
mkdir -p $BASE/clip_vision
mkdir -p $BASE/detection
mkdir -p $BASE/vitpose
mkdir -p $BASE/diffusion_models
mkdir -p $BASE/loras

python3 - <<PY
from huggingface_hub import hf_hub_download
import os

BASE = "/workspace/ComfyUI/models"

def dl(repo, file, dest, name=None, branch="main"):
    os.makedirs(dest, exist_ok=True)
    path = hf_hub_download(
        repo_id=repo,
        filename=file,
        revision=branch,
        local_dir=dest
    )
    if name:
        final = os.path.join(dest, name)
        if path != final:
            os.replace(path, final)

dl("Wan-AI/Wan2.2-Animate-14B", "process_checkpoint/det/yolov10m.onnx", f"{BASE}/detection", "yolov10m.onnx", "main")

dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_data.bin", f"{BASE}/vitpose", "vitpose_h_wholebody_data.bin", "main")
dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_model.onnx", f"{BASE}/vitpose", "vitpose_h_wholebody_model.onnx", "main")

dl("Kijai/WanVideo_comfy", "umt5-xxl-enc-fp8_e4m3fn.safetensors", f"{BASE}/clip", "umt5-xxl-enc-fp8_e4m3fn.safetensors", "main")

dl("Kijai/WanVideo_comfy_fp8_scaled", "Wan22Animate/Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors", f"{BASE}/diffusion_models", "Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors", f"{BASE}/loras", "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors", "main")

dl("Comfy-Org/Wan_2.2_ComfyUI_Repackaged", "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors", f"{BASE}/loras", "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors", f"{BASE}/loras", "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors", "main")

dl("alibaba-pai/Wan2.2-Fun-Reward-LoRAs", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors", f"{BASE}/loras", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors", "main")

PY

cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188
