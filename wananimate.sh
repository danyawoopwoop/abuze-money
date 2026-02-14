#!/usr/bin/env bash
set -euo pipefail

export WORKSPACE="/workspace"
export COMFY_DIR="$WORKSPACE/ComfyUI"
export PY="/venv/main/bin/python"
export PIP="/venv/main/bin/pip"
export HF_HUB_ENABLE_HF_TRANSFER=1

mkdir -p "$WORKSPACE"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

apt-get update -y || true
apt-get install -y git wget curl ca-certificates rsync || true

if [ ! -d "$COMFY_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
  git -C "$COMFY_DIR" pull || true
fi

mkdir -p "$COMFY_DIR/models/diffusion_models"
mkdir -p "$COMFY_DIR/models/clip"
mkdir -p "$COMFY_DIR/models/clip_vision"
mkdir -p "$COMFY_DIR/models/vae"
mkdir -p "$COMFY_DIR/models/detection"
mkdir -p "$COMFY_DIR/models/vitpose"
mkdir -p "$COMFY_DIR/models/loras"

$PIP install -U --no-cache-dir pip setuptools wheel
$PIP install -U --no-cache-dir huggingface_hub hf_transfer

$PIP install -U --no-cache-dir GitPython toml matplotlib opencv-python onnxruntime accelerate gguf || true

cd "$COMFY_DIR/custom_nodes"

if [ ! -d "ComfyUI-Manager" ]; then
  git clone https://github.com/Comfy-Org/ComfyUI-Manager.git
fi

if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
  git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
fi
$PIP install --no-cache-dir -r "$COMFY_DIR/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt" || true

if [ ! -d "ComfyUI-WanAnimatePreprocess" ]; then
  git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git
fi
$PIP install --no-cache-dir -r "$COMFY_DIR/custom_nodes/ComfyUI-WanAnimatePreprocess/requirements.txt" || true

if [ ! -d "ComfyUI-KJNodes" ]; then
  git clone https://github.com/kijai/ComfyUI-KJNodes.git
fi

if [ ! -d "NEW-UTILS" ]; then
  git clone https://github.com/teskor-hub/NEW-UTILS.git
fi

if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
  git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
fi

cd "$COMFY_DIR"

$PY - << 'PY'
from huggingface_hub import hf_hub_download
import os

BASE = "/workspace/ComfyUI/models"

def dl(repo, path, out_dir, out_name, rev="main"):
    os.makedirs(out_dir, exist_ok=True)
    if os.path.exists(os.path.join(out_dir, out_name)):
        print("[SKIP]", out_name)
        return
    print("[DL]", repo, "::", out_name)
    hf_hub_download(
        repo_id=repo,
        filename=path,
        revision=rev,
        local_dir=out_dir,
        local_dir_use_symlinks=False,
    )
    src = os.path.join(out_dir, path)
    dst = os.path.join(out_dir, out_name)
    if src != dst and os.path.exists(src):
        os.replace(src, dst)

dl("Kijai/WanVideo_comfy_fp8_scaled", "Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e5m2_KJ_v2.safetensors",
   f"{BASE}/diffusion_models", "Wan2_2-Animate-14B_fp8_scaled_e5m2_KJ_v2.safetensors", "main")

dl("Kijai/WanVideo_comfy_fp8_scaled", "Wan22Animate/Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors",
   f"{BASE}/diffusion_models", "Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors", "main")

dl("Kijai/WanVideo_comfy", "umt5-xxl-enc-fp8_e4m3fn.safetensors",
   f"{BASE}/clip", "umt5-xxl-enc-fp8_e4m3fn.safetensors", "main")

dl("calcuis/wan-gguf", "clip_vision_h.safetensors",
   f"{BASE}/clip_vision", "clip_vision_h.safetensors", "f52f5a1f0ba441d50277fb7cdd7c1b36611837f9")

dl("Wan-AI/Wan2.2-Animate-14B", "process_checkpoint/det/yolov10m.onnx",
   f"{BASE}/detection", "yolov10m.onnx", "main")

dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_data.bin",
   f"{BASE}/vitpose", "vitpose_h_wholebody_data.bin", "main")

dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_model.onnx",
   f"{BASE}/vitpose", "vitpose_h_wholebody_model.onnx", "main")

dl("Kijai/WanVideo_comfy", "Wan2_1_VAE_bf16.safetensors",
   f"{BASE}/vae", "Wan2_1_VAE_bf16.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors",
   f"{BASE}/diffusion_models", "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors", "main")

dl("Comfy-Org/Wan_2.2_ComfyUI_Repackaged", "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
   f"{BASE}/loras", "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
   f"{BASE}/loras", "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors", "d7cfaf07099aa23390dfeb721f03c9e5182b1d1d")

dl("alibaba-pai/Wan2.2-Fun-Reward-LoRAs", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors",
   f"{BASE}/loras", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors", "main")

print("DONE")
PY

pkill -f "/workspace/ComfyUI/main.py" >/dev/null 2>&1 || true
sleep 1

nohup "$PY" "$COMFY_DIR/main.py" --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &

echo "OK"
echo "LOG: tail -n 200 /workspace/comfyui.log"
