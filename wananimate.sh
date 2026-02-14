set -euo pipefail

echo "[WanAnimate] Start provisioning..."

export WORKSPACE="/workspace"

if [ -f /venv/main/bin/activate ]; then
  . /venv/main/bin/activate
fi

mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

if [ ! -d "ComfyUI" ]; then
  echo "[WanAnimate] Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git
fi

cd "${WORKSPACE}/ComfyUI"

echo "[WanAnimate] Updating ComfyUI..."
git pull || echo "[WanAnimate] ComfyUI already up to date (or pull failed)"

mkdir -p models/diffusion_models \
         models/clip \
         models/clip_vision \
         models/vae \
         models/detection \
         models/vitpose

pip install --no-cache-dir -U huggingface-hub hf-transfer
export HF_HUB_ENABLE_HF_TRANSFER=1

cd "${WORKSPACE}/ComfyUI/custom_nodes"

clone_if_missing () {
  local dir="$1"
  local repo="$2"
  if [ ! -d "$dir" ]; then
    echo "[WanAnimate] Cloning $dir..."
    git clone "$repo" "$dir"
  else
    echo "[WanAnimate] $dir exists"
  fi
}

clone_if_missing "ComfyUI-Manager" "https://github.com/Comfy-Org/ComfyUI-Manager.git"
clone_if_missing "ComfyUI-WanVideoWrapper" "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
clone_if_missing "ComfyUI-WanAnimatePreprocess" "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git"
clone_if_missing "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"
clone_if_missing "NEW-UTILS" "https://github.com/teskor-hub/NEW-UTILS.git"
clone_if_missing "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"

if [ -f "ComfyUI-WanVideoWrapper/requirements.txt" ]; then
  pip install --no-cache-dir -r ComfyUI-WanVideoWrapper/requirements.txt || true
fi
if [ -f "ComfyUI-WanAnimatePreprocess/requirements.txt" ]; then
  pip install --no-cache-dir -r ComfyUI-WanAnimatePreprocess/requirements.txt || true
fi

cd "${WORKSPACE}/ComfyUI/models"

download_if_missing () {
  local path="$1"
  shift
  if [ ! -f "${path}" ]; then
    echo "[WanAnimate] Downloading ${path}..."
    huggingface-cli download "$@" 
  else
    echo "[WanAnimate] Exists: ${path}"
  fi
}

download_if_missing "diffusion_models/Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ_v2.safetensors" \
  "Kijai/WanVideo_comfy_fp8_scaled" "Wan2_2-Animate-14B_fp8_e5m2_scaled_KJ_v2.safetensors" --local-dir diffusion_models

download_if_missing "clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "Kijai/WanVideo_comfy" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" --local-dir clip

if [ ! -f "clip_vision/clip_vision_h.safetensors" ]; then
  echo "[WanAnimate] Downloading clip_vision_h..."
  huggingface-cli download "h94/IP-Adapter" "models/image_encoder/model.safetensors" \
    --local-dir clip_vision --filename clip_vision_h.safetensors
fi

download_if_missing "vae/wan21-vae.safetensors" \
  "Kijai/WanVideo_comfy" "wan21-vae.safetensors" --local-dir vae

download_if_missing "detection/yolov10m.onnx" \
  "ultralytics/yolov10m.onnx" --local-dir detection

download_if_missing "vitpose/vitpose-huge.onnx" \
  "kijai/vitpose-huge.onnx" --local-dir vitpose

echo "[WanAnimate] Provisioning done."
