#!/bin/bash
set -euo pipefail

echo "[post_start] preparing vLLM startup"

mkdir -p /workspace /workspace/hf
LOG_PATH="${VLLM_LOG:-/workspace/vllm.log}"
touch "${LOG_PATH}"
chmod 666 "${LOG_PATH}" || true

if [[ ! -x /run_vllm.sh ]]; then
  echo "[post_start] /run_vllm.sh is missing or not executable; skipping vLLM startup"
  exit 0
fi

if pgrep -f "vllm.entrypoints.openai.api_server" >/dev/null 2>&1; then
  echo "[post_start] vLLM already running; skipping duplicate startup"
  exit 0
fi

echo "[post_start] launching /run_vllm.sh in background"
nohup /bin/bash /run_vllm.sh >> "${LOG_PATH}" 2>&1 &
sleep 2

if pgrep -f "vllm.entrypoints.openai.api_server" >/dev/null 2>&1; then
  echo "[post_start] vLLM launch command submitted successfully"
else
  echo "[post_start] warning: vLLM process not detected yet; check ${LOG_PATH}"
fi