#!/usr/bin/env bash
set -Eeuo pipefail

export WORKSPACE="/workspace"
export COMFY_DIR="$WORKSPACE/ComfyUI"
export VENV_DIR="/venv/main"
export PY="$VENV_DIR/bin/python"
export PIP="$VENV_DIR/bin/pip"
export HF_HUB_ENABLE_HF_TRANSFER=1

MARKER="$WORKSPACE/.wananimate_provisioned_v2"

echo "[WanAnimate] provisioning start"

mkdir -p "$WORKSPACE"

if [ -f "$VENV_DIR/bin/activate" ]; then
  . "$VENV_DIR/bin/activate"
else
  echo "venv not found at $VENV_DIR"
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y || true
  apt-get install -y git wget curl ca-certificates rsync dos2unix || true
fi

if [ ! -d "$COMFY_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
else
  git -C "$COMFY_DIR" pull || true
fi

mkdir -p "$COMFY_DIR/models/diffusion_models" \
         "$COMFY_DIR/models/clip" \
         "$COMFY_DIR/models/clip_vision" \
         "$COMFY_DIR/models/vae" \
         "$COMFY_DIR/models/detection" \
         "$COMFY_DIR/models/vitpose" \
         "$COMFY_DIR/models/loras"

"$PIP" install -U --no-cache-dir pip setuptools wheel
"$PIP" install -U --no-cache-dir huggingface_hub hf_transfer
"$PIP" install -U --no-cache-dir GitPython toml matplotlib opencv-python onnxruntime accelerate gguf || true

mkdir -p "$COMFY_DIR/custom_nodes"
cd "$COMFY_DIR/custom_nodes"

[ -d "ComfyUI-Manager" ] || git clone https://github.com/Comfy-Org/ComfyUI-Manager.git
[ -d "ComfyUI-WanVideoWrapper" ] || git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
"$PIP" install --no-cache-dir -r "$COMFY_DIR/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt" || true

[ -d "ComfyUI-WanAnimatePreprocess" ] || git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git
"$PIP" install --no-cache-dir -r "$COMFY_DIR/custom_nodes/ComfyUI-WanAnimatePreprocess/requirements.txt" || true

[ -d "ComfyUI-KJNodes" ] || git clone https://github.com/kijai/ComfyUI-KJNodes.git
[ -d "NEW-UTILS" ] || git clone https://github.com/teskor-hub/NEW-UTILS.git
[ -d "ComfyUI-VideoHelperSuite" ] || git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

cd "$COMFY_DIR"

if [ ! -f "$MARKER" ]; then
  "$PY" - << 'PY'
from huggingface_hub import hf_hub_download
import os

BASE = "/workspace/ComfyUI/models"

def dl(repo, path, out_dir, out_name=None, rev="main"):
    os.makedirs(out_dir, exist_ok=True)
    out_name = out_name or os.path.basename(path)
    dst = os.path.join(out_dir, out_name)
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return
    hf_hub_download(repo_id=repo, filename=path, revision=rev,
                    local_dir=out_dir, local_dir_use_symlinks=False)
    src = os.path.join(out_dir, path)
    if src != dst and os.path.exists(src):
        os.replace(src, dst)

dl("Kijai/WanVideo_comfy_fp8_scaled",
   "Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e5m2_KJ_v2.safetensors",
   f"{BASE}/diffusion_models",
   "Wan2_2-Animate-14B_fp8_scaled_e5m2_KJ_v2.safetensors")

dl("Kijai/WanVideo_comfy_fp8_scaled",
   "Wan22Animate/Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors",
   f"{BASE}/diffusion_models",
   "Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors")

dl("Kijai/WanVideo_comfy",
   "umt5-xxl-enc-fp8_e4m3fn.safetensors",
   f"{BASE}/clip",
   "umt5-xxl-enc-fp8_e4m3fn.safetensors")

dl("calcuis/wan-gguf",
   "clip_vision_h.safetensors",
   f"{BASE}/clip_vision",
   "clip_vision_h.safetensors",
   "f52f5a1f0ba441d50277fb7cdd7c1b36611837f9")

dl("Wan-AI/Wan2.2-Animate-14B",
   "process_checkpoint/det/yolov10m.onnx",
   f"{BASE}/detection",
   "yolov10m.onnx")

dl("Kijai/vitpose_comfy",
   "onnx/vitpose_h_wholebody_data.bin",
   f"{BASE}/vitpose",
   "vitpose_h_wholebody_data.bin")

dl("Kijai/vitpose_comfy",
   "onnx/vitpose_h_wholebody_model.onnx",
   f"{BASE}/vitpose",
   "vitpose_h_wholebody_model.onnx")

dl("Kijai/WanVideo_comfy",
   "Wan2_1_VAE_bf16.safetensors",
   f"{BASE}/vae",
   "Wan2_1_VAE_bf16.safetensors")

dl("Kijai/WanVideo_comfy",
   "Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors",
   f"{BASE}/loras",
   "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors")

dl("Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
   "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
   f"{BASE}/loras",
   "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors")

dl("Kijai/WanVideo_comfy",
   "Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
   f"{BASE}/loras",
   "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
   "d7cfaf07099aa23390dfeb721f03c9e5182b1d1d")

dl("alibaba-pai/Wan2.2-Fun-Reward-LoRAs",
   "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors",
   f"{BASE}/loras",
   "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors")
PY

  touch "$MARKER"
fi

echo "[WanAnimate] provisioning done"
