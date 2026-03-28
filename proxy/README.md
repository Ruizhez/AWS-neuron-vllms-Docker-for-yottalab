# AWS Neuron vLLM Pod

This image is built on top of the official AWS Neuron vLLM image and is intended to run inside the existing Yotta container template.

If you are seeing this page, it usually means:

1. the container has already started;
2. the template `start.sh` has already run;
3. nginx is up;
4. the vLLM backend is not ready yet, is still compiling, or failed to start.

## Default model

This image currently tries to start the following Hugging Face model by default:

- `Qwen/Qwen2.5-7B-Instruct`

Hugging Face page:

- `https://huggingface.co/Qwen/Qwen2.5-7B-Instruct`

## Runtime layout

- workspace: `/workspace`
- Hugging Face cache: `/workspace/hf`
- vLLM log: `/workspace/vllm.log`

## Ports

- SSH: `22`
- Jupyter Lab: `8888`
- current vLLM internal port: `8000`
- external proxy entrypoint: depends on the unchanged nginx template

## What this image does

- keeps the existing `start.sh` template unchanged;
- keeps the existing `nginx.conf` template unchanged;
- starts the shell services first;
- uses `/post_start.sh` to launch vLLM in the background;
- uses `/run_vllm.sh` to start the OpenAI-compatible vLLM API server.

## Quick checks inside the container

Check the vLLM log first:

```bash
cat /workspace/vllm.log