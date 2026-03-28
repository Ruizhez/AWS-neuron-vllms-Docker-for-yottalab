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
.
├── dockerfile
├── scripts/
│   ├── start.sh
│   └── post_start.sh
└── proxy/
    ├── nginx.conf
    ├── readme.html
    └── README.md
