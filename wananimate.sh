#!/bin/bash
set -euo pipefail

export WORKSPACE="/workspace"
export COMFY_DIR="/workspace/ComfyUI"
export PY="/venv/main/bin/python"

mkdir -p "$WORKSPACE"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

if [ ! -x "$PY" ]; then
  PY="$(command -v python3 || command -v python)"
fi

"$PY" -m pip install -U pip setuptools wheel >/dev/null

apt-get update -y >/dev/null
apt-get install -y git ffmpeg libgl1 libglib2.0-0 >/dev/null

if [ ! -d "$COMFY_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
fi

cd "$COMFY_DIR"
git fetch --all --prune >/dev/null
git pull --rebase >/dev/null || true

mkdir -p models/diffusion_models models/clip models/clip_vision models/vae models/detection models/loras

"$PY" -m pip install -U "huggingface-hub>=0.24.0" hf-transfer >/dev/null
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HOME=/workspace/.hf
export HUGGINGFACE_HUB_CACHE=/workspace/.hf/hub

"$PY" -m pip install -U \
  GitPython toml pyyaml requests tqdm \
  accelerate diffusers transformers safetensors sentencepiece \
  onnxruntime opencv-python-headless matplotlib imageio-ffmpeg av \
  gguf \
  >/dev/null

cd "$COMFY_DIR/custom_nodes"
[ -d "ComfyUI-Manager" ] || git clone https://github.com/Comfy-Org/ComfyUI-Manager.git
[ -d "ComfyUI-WanVideoWrapper" ] || git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
[ -d "ComfyUI-WanAnimatePreprocess" ] || git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git
[ -d "ComfyUI-KJNodes" ] || git clone https://github.com/kijai/ComfyUI-KJNodes.git
[ -d "NEW-UTILS" ] || git clone https://github.com/teskor-hub/NEW-UTILS.git
[ -d "ComfyUI-VideoHelperSuite" ] || git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

[ -f "ComfyUI-WanVideoWrapper/requirements.txt" ] && "$PY" -m pip install -r "ComfyUI-WanVideoWrapper/requirements.txt" >/dev/null || true
[ -f "ComfyUI-WanAnimatePreprocess/requirements.txt" ] && "$PY" -m pip install -r "ComfyUI-WanAnimatePreprocess/requirements.txt" >/dev/null || true

cd "$COMFY_DIR"

"$PY" - <<'PY'
import os
from huggingface_hub import hf_hub_download

def dl(repo, filename, outdir, outname=None, rev="main"):
    os.makedirs(outdir, exist_ok=True)
    outname = outname or os.path.basename(filename)
    outpath = os.path.join(outdir, outname)
    if os.path.exists(outpath) and os.path.getsize(outpath) > 0:
        print("[OK already]", outpath)
        return
    print(f"[DL] {repo}@{rev} :: {filename}")
    p = hf_hub_download(repo_id=repo, filename=filename, revision=rev, local_dir=outdir)
    if p != outpath:
        os.replace(p, outpath)
    print("[OK]", outpath)

BASE="/workspace/ComfyUI/models"
DETECTION=f"{BASE}/detection"

dl("calcuis/wan-gguf", "clip_vision_h.safetensors", f"{BASE}/clip_vision", "clip_vision_h.safetensors",
   "f52f5a1f0ba441d50277fb7cdd7c1b36611837f9")

dl("Kijai/WanVideo_comfy", "umt5-xxl-enc-fp8_e4m3fn.safetensors", f"{BASE}/clip", "umt5-xxl-enc-fp8_e4m3fn.safetensors", "main")

dl("Kijai/WanVideo_comfy_fp8_scaled", "Wan22Animate/Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors",
   f"{BASE}/diffusion_models", "Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ.safetensors", "main")

dl("Wan-AI/Wan2.2-Animate-14B", "process_checkpoint/det/yolov10m.onnx", DETECTION, "yolov10m.onnx", "main")
dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_data.bin", DETECTION, "vitpose_h_wholebody_data.bin", "main")
dl("Kijai/vitpose_comfy", "onnx/vitpose_h_wholebody_model.onnx", DETECTION, "vitpose_h_wholebody_model.onnx", "main")

dl("Comfy-Org/Wan_2.2_ComfyUI_Repackaged",
   "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
   f"{BASE}/loras", "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors",
   f"{BASE}/loras", "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors", "main")

dl("Kijai/WanVideo_comfy", "Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
   f"{BASE}/loras", "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors",
   "d7cfaf07099aa23390dfeb721f03c9e5182b1d1d")

dl("alibaba-pai/Wan2.2-Fun-Reward-LoRAs", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors",
   f"{BASE}/loras", "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors", "main")
PY

rm -f /workspace/ComfyUI/models/clip_vision/put_clip_vision_models_here || true
rm -f /workspace/ComfyUI/models/clip/put_clip_or_text_encoder_models_here || true
rm -f /workspace/ComfyUI/models/loras/put_loras_here || true

rm -rf /workspace/ComfyUI/models/detection/process_checkpoint || true
rm -rf /workspace/ComfyUI/models/detection/onnx || true
rm -rf /workspace/ComfyUI/models/loras/Pusa || true
rm -rf /workspace/ComfyUI/models/loras/split_files || true

pkill -f "/workspace/ComfyUI/main.py" >/dev/null 2>&1 || true
sleep 1

nohup "$PY" /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &

echo "OK"
echo "LOG: tail -n 200 /workspace/comfyui.log"
