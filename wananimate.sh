#!/usr/bin/env bash
set -euo pipefail

export WORKSPACE="/workspace"
export COMFY_DIR="$WORKSPACE/ComfyUI"
export PY="/venv/main/bin/python"
export PIP="/venv/main/bin/pip"
export HF_HUB_ENABLE_HF_TRANSFER=1

echo "[WanAnimate] provisioning start"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

mkdir -p "$WORKSPACE"

apt-get update -y || true
apt-get install -y git wget curl ca-certificates rsync dos2unix || true

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
         "$COMFY_DIR/models/loras"

"$PIP" install -U --no-cache-dir pip setuptools wheel
"$PIP" install --no-cache-dir -r "$COMFY_DIR/requirements.txt"
"$PIP" install -U --no-cache-dir huggingface_hub hf_transfer

"$PIP" install -U --no-cache-dir \
  GitPython toml matplotlib opencv-python onnxruntime accelerate gguf sqlalchemy || true

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

"$PY" - << 'PY'
from huggingface_hub import hf_hub_download
import os

BASE = "/workspace/ComfyUI/models"

def dl(repo, path, out_dir, out_name=None, rev="main"):
    os.makedirs(out_dir, exist_ok=True)
    out_name = out_name or os.path.basename(path)
    dst = os.path.join(out_dir, out_name)
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        print("[SKIP]", dst)
        return

    print("[DL]", repo, "::", path, "->", dst, "(rev:", rev, ")")
    hf_hub_download(
        repo_id=repo,
        filename=path,
        revision=rev,
        local_dir=out_dir,
        local_dir_use_symlinks=False,
    )

    src = os.path.join(out_dir, path)
    if src != dst and os.path.exists(src):
        os.replace(src, dst)

dl("Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
   "split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors",
   f"{BASE}/diffusion_models",
   "wan2.2_animate_14B_bf16.safetensors")

dl("Comfy-Org/Wan_2.1_ComfyUI_repackaged",
   "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",
   f"{BASE}/clip",
   "umt5_xxl_fp8_e4m3fn_scaled.safetensors")

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
   f"{BASE}/detection",
   "vitpose_h_wholebody_data.bin")

dl("Kijai/vitpose_comfy",
   "onnx/vitpose_h_wholebody_model.onnx",
   f"{BASE}/detection",
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

dl("RaphaelLiu/Pusa-Wan2.2-V1",
   "high_noise_pusa.safetensors",
   f"{BASE}/loras",
   "high_noise_pusa.safetensors")

dl("RaphaelLiu/Pusa-Wan2.2-V1",
   "low_noise_pusa.safetensors",
   f"{BASE}/loras",
   "low_noise_pusa.safetensors")


dl("alibaba-pai/Wan2.2-Fun-Reward-LoRAs",
   "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors",
   f"{BASE}/loras",
   "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors")

print("DONE: models ready in", BASE)
PY

pkill -f "/workspace/ComfyUI/main.py" >/dev/null 2>&1 || true
sleep 1

nohup "$PY" "$COMFY_DIR/main.py" --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &

echo "[WanAnimate] OK"
echo "LOG: tail -n 200 /workspace/comfyui.log"
