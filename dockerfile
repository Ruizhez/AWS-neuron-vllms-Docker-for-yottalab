# ============================================================
# Yotta-style AWS Neuron vLLM image
# Modified from the official 0.13.0 build logic
# Uses a configurable Ubuntu base image, matching the style of
# other Yotta images
# Keeps the existing start.sh and nginx.conf templates unchanged
# ============================================================

ARG BASE_IMAGE="ubuntu:22.04"

FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ------------------------------------------------------------
# Build args aligned with the official 0.13.0 line
# ------------------------------------------------------------
ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.12.11
ARG NEURON_APT_REPO=apt.repos.neuron.amazonaws.com
ARG NEURON_PIP_REPO=pip.repos.neuron.amazonaws.com
ARG PYPI_SIMPLE_URL="https://pypi.org/simple/"
ARG GITHUB_REPO="https://github.com/vllm-project/vllm-neuron.git"
ARG GITHUB_REPO_BRANCH="release-0.4.1"

ARG NEURONX_COLLECTIVES_LIB_VERSION=2.30.59.0-f5cdefb39
ARG NEURONX_RUNTIME_LIB_VERSION=2.30.51.0-faafe26f0
ARG NEURONX_TOOLS_VERSION=2.28.23.0-f1c114a9d
ARG NEURONX_CC_VERSION=2.23.6484.0+3b612583
ARG NEURONX_FRAMEWORK_VERSION=2.9.0.2.12.22436+0f1dac25
ARG NEURONX_DISTRIBUTED_VERSION=0.17.26814+4b18de63
ARG NEURONX_DISTRIBUTED_INFERENCE_VERSION=0.8.16251+f3ca5575
ARG NKI_VERSION=0.2.0+g82fdb402

# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    SHELL=/bin/bash \
    HF_HOME=/workspace/hf \
    JUPYTER_PASSWORD=ubuntu \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=8000 \
    VLLM_LOG=/workspace/vllm.log \
    VLLM_MODEL="Qwen/Qwen2.5-0.5B-Instruct" \
    VLLM_MAX_MODEL_LEN=2048 \
    NEURON_RT_NUM_CORES=1 \
    PATH=/opt/conda/bin:/opt/aws/neuron/bin:/usr/local/bin:/usr/bin:/bin:$PATH \
    LD_LIBRARY_PATH=/opt/aws/neuron/lib:/lib/x86_64-linux-gnu:/opt/conda/lib:$LD_LIBRARY_PATH

# ------------------------------------------------------------
# Base system packages + Yotta shell dependencies
# ------------------------------------------------------------
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      bash \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      ffmpeg \
      gcc \
      git \
      gnupg2 \
      gpg-agent \
      jq \
      less \
      libcap-dev \
      libgl1 \
      libgl1-mesa-dri \
      libglib2.0-0 \
      libhwloc-dev \
      libsm6 \
      libxext6 \
      libxrender-dev \
      locales \
      net-tools \
      netcat-openbsd \
      nginx \
      openssh-client \
      openssh-server \
      openjdk-11-jdk \
      procps \
      rsync \
      software-properties-common \
      sudo \
      tmux \
      tree \
      tzdata \
      unzip \
      vim \
      wget \
      zip \
      zlib1g-dev && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    mkdir -p /var/run/sshd /workspace /workspace/hf /usr/share/nginx/html && \
    chmod 777 /workspace && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Miniforge / conda, following the official line
# ------------------------------------------------------------
RUN curl -L -o /tmp/miniforge.sh \
      "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm -f /tmp/miniforge.sh && \
    /opt/conda/bin/conda config --system --set auto_update_conda false && \
    /opt/conda/bin/conda install -y -c conda-forge mamba && \
    /opt/conda/bin/mamba install -y -c conda-forge \
      python=${PYTHON_VERSION} \
      pyopenssl \
      cython \
      mkl \
      mkl-include \
      parso \
      typing \
      scikit-learn \
      h5py \
      requests \
      conda-content-trust \
      charset-normalizer && \
    /opt/conda/bin/pip install --no-cache-dir --upgrade pip setuptools wheel

# Compatibility for unchanged start.sh.
# start.sh calls "python3.11 -m jupyter lab".
# Expose a python3.11 command alias only to satisfy that unchanged template.
RUN ln -sf /opt/conda/bin/python /usr/local/bin/python3.11 && \
    ln -sf /opt/conda/bin/pip /usr/local/bin/pip3.11

# ------------------------------------------------------------
# Neuron APT repo + pinned system packages
# ------------------------------------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    echo "deb [signed-by=/etc/apt/keyrings/neuron.gpg] https://${NEURON_APT_REPO} jammy main" > /etc/apt/sources.list.d/neuron.list && \
    curl -fsSL "https://${NEURON_APT_REPO}/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB" | gpg --dearmor > /etc/apt/keyrings/neuron.gpg && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      aws-neuronx-tools=${NEURONX_TOOLS_VERSION} \
      aws-neuronx-collectives=${NEURONX_COLLECTIVES_LIB_VERSION} \
      aws-neuronx-runtime-lib=${NEURONX_RUNTIME_LIB_VERSION} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Pinned Python Neuron stack, aligned with official prod stage
# ------------------------------------------------------------
RUN /opt/conda/bin/pip install --no-cache-dir \
      --index-url https://${NEURON_PIP_REPO} \
      --trusted-host ${NEURON_PIP_REPO} \
      --extra-index-url ${PYPI_SIMPLE_URL} \
      neuronx-cc==${NEURONX_CC_VERSION} \
      torch-neuronx==${NEURONX_FRAMEWORK_VERSION} \
      neuronx_distributed==${NEURONX_DISTRIBUTED_VERSION} \
      neuronx_distributed_inference==${NEURONX_DISTRIBUTED_INFERENCE_VERSION} \
      nki==${NKI_VERSION}

# ------------------------------------------------------------
# Clone and install vLLM-Neuron from the official source line
# ------------------------------------------------------------
RUN git clone -b ${GITHUB_REPO_BRANCH} ${GITHUB_REPO} /opt/vllm && \
    /opt/conda/bin/pip install --no-cache-dir -e /opt/vllm

# ------------------------------------------------------------
# Jupyter for unchanged start.sh
# ------------------------------------------------------------
RUN python3.11 -m pip install --no-cache-dir \
      jupyterlab \
      ipywidgets \
      jupyter-archive \
      "notebook==7.3.3"

# ------------------------------------------------------------
# User expected by unchanged start.sh
# ------------------------------------------------------------
RUN id -u ubuntu >/dev/null 2>&1 || useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

# ------------------------------------------------------------
# SSH config expected by unchanged start.sh
# ------------------------------------------------------------
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    rm -f /etc/ssh/ssh_host_*

# ------------------------------------------------------------
# Unchanged templates
# ------------------------------------------------------------
COPY scripts/start.sh /start.sh
COPY proxy/nginx.conf /etc/nginx/nginx.conf
COPY proxy/readme.html /usr/share/nginx/html/readme.html
COPY proxy/README.md /usr/share/nginx/html/README.md

RUN chmod 755 /start.sh

# ------------------------------------------------------------
# Runtime hooks added without changing start.sh
# ------------------------------------------------------------
COPY scripts/post_start.sh /post_start.sh
RUN chmod 755 /post_start.sh

RUN cat > /run_vllm.sh <<'EOF' && chmod 755 /run_vllm.sh
#!/bin/bash
set -e

echo "[run_vllm] container bootstrapping vLLM"

MODEL="${VLLM_MODEL:-${MODEL_ID:-}}"
HOST="${VLLM_HOST:-0.0.0.0}"
PORT="${VLLM_PORT:-8000}"
MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-2048}"

if [[ -z "${MODEL}" ]]; then
  echo "[run_vllm] VLLM_MODEL / MODEL_ID is empty; not starting vLLM"
  exit 0
fi

if [[ ! -e /dev/neuron0 && ! -e /dev/neuron1 && ! -e /dev/neuron ]]; then
  echo "[run_vllm] no /dev/neuron* device detected; skipping vLLM startup"
  exit 0
fi

export HF_HOME="${HF_HOME:-/workspace/hf}"
LOG_PATH="${VLLM_LOG:-/workspace/vllm.log}"

echo "[run_vllm] model=${MODEL}"
echo "[run_vllm] host=${HOST}"
echo "[run_vllm] port=${PORT}"
echo "[run_vllm] max_model_len=${MAX_MODEL_LEN}"
echo "[run_vllm] hf_home=${HF_HOME}"
echo "[run_vllm] log_path=${LOG_PATH}"

exec python -m vllm.entrypoints.openai.api_server \
  --host "${HOST}" \
  --port "${PORT}" \
  --model "${MODEL}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --block-size 16
EOF

# ------------------------------------------------------------
# Ports and entrypoint
# ------------------------------------------------------------
EXPOSE 22 80 8000 8888 9091 3001 7861 8081 8001 7270

USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]