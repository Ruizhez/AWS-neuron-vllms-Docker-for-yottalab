# AWS-neuron-vllms-Docker-for-yottalab# AWS Neuron vLLM Docker for YottaLab

This repository contains a Yotta-style AWS Neuron vLLM Docker setup and the validation work used to test model compilation and serving on **AWS Trainium (Trn1)**.

## Objective

The goal of this work was to:

- build a custom AWS Neuron vLLM image in a Yotta-style structure,
- validate that the container startup chain works correctly,
- compare the custom image against the official AWS Neuron DLC,
- determine whether model startup failures came from the custom Docker wrapper or from the official Neuron/vLLM compilation stack.

## Repository Structure

```text
.—— docker-bake.hcl
├── Dockerfile
├── scripts/
│   ├── start.sh
│   └── post_start.sh
└── proxy/
    ├── nginx.conf
    ├── readme.html
    └── README.md

```
## Base Environment

This image was built against the same version line as the official AWS Neuron vLLM container.

Validated baseline:

- vLLM: 0.13.0
- vLLM Neuron plugin: 0.4.1
- Neuron SDK line: 2.28.0
- Python: 3.12
- PyTorch Neuron: 2.9.0

The following package versions were verified against the official AWS Neuron DLC:

- `neuronx-cc = 2.23.6484.0+3b612583`
- `torch-neuronx = 2.9.0.2.12.22436+0f1dac25`
- `neuronx-distributed = 0.17.26814+4b18de63`
- `neuronx-distributed-inference = 0.8.16251+f3ca5575`
- `nki = 0.2.0+g82fdb402`
- `aws-neuronx-tools = 2.28.23.0-f1c114a9d`
- `aws-neuronx-runtime-lib = 2.30.51.0-faafe26f0`
- `aws-neuronx-collectives = 2.30.59.0-f5cdefb39`

## What Was Completed

The following work was completed during validation:

- Built the custom AWS Neuron vLLM Docker image successfully.
- Verified that the container startup path works end to end.
- Confirmed `/dev/neuron0` visibility inside the runtime environment.
- Verified that the vLLM Neuron plugin loads correctly.
- Validated the startup chain:

  `start.sh -> post_start.sh -> run_vllm.sh`

- Reached model loading, HLO generation, and `neuronx-cc` compilation stages.
- Investigated early OOM behavior and mitigated it by reducing model/context size during testing.
- Compared the custom image against the official AWS Neuron DLC.

## Official AWS Neuron DLC Used for Control Experiments

The official image used for comparison was:

```bash
public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.13.0-neuronx-py312-sdk2.28.0-ubuntu24.04
```
## Reproduction Command

The following command was used to reproduce startup behavior with the official AWS Neuron image:

```bash
docker run --rm -it \
  --device=/dev/neuron0 \
  -p 8000:8000 \
  --name official-vllm-test \
  public.ecr.aws/neuron/pytorch-inference-vllm-neuronx:0.13.0-neuronx-py312-sdk2.28.0-ubuntu24.04 \
  python -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --port 8000 \
    --model Qwen/Qwen2.5-0.5B-Instruct \
    --max-model-len 2048 \
    --block-size 16
```

## Key Finding

The primary blocker was not the custom Docker wrapper.

The same failure was reproduced in the official AWS Neuron DLC, with the same compiler-side error during `neuronx-cc` compilation:

- `NCC_ITEN404`
- `Internal tensorizer error`
- `SimplifyNeuronTensor`
- `neuronx-cc ... returned non-zero exit status 70`

This indicates that the issue is localized to the official AWS Neuron / vLLM compilation path rather than the custom image startup logic.

## Models Tested

The following models were used during validation:

- `Qwen/Qwen2.5-7B-Instruct`
- `Qwen/Qwen2.5-0.5B-Instruct`
- `TinyLlama/TinyLlama-1.1B-Chat-v1.0`

Notes:

- Larger models initially triggered OOM pressure during early validation.
- Smaller models were then used to separate memory pressure from compiler failure.
- The same internal compiler failure was reproduced on multiple text models.

## Current Conclusion

At the current stage, the following has been established:

1. The custom image can be built and started successfully.
2. The startup and runtime wiring is functional.
3. The issue is reproducible on the official AWS Neuron image.
4. The failure is centered in the `neuronx-cc` tensorizer/compiler stage.
5. The remaining blocker appears to be an upstream Neuron/vLLM compiler compatibility issue rather than a Docker packaging issue.

## Next Steps

Reasonable next steps would be:

- Open an AWS Neuron issue / support ticket with:
  - full command,
  - exact image tag,
  - model name,
  - full error logs,
  - `log-neuron-cc.txt`
- Continue testing additional public models only if needed to further bound the scope of the compiler issue.

## Status

This repository captures the image setup and the validation outcome up to the point where the issue was isolated to the official AWS Neuron compiler path.
