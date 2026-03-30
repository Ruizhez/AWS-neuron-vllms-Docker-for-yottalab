variable "PUBLISHER" {
  default = "yottalabsai"
}

variable "TAG_SUFFIX" {
  default = "0.1.0"
}

group "default" {
  targets = ["aws-neuron-vllm"]
}

target "aws-neuron-vllm" {
  dockerfile = "Dockerfile"

  tags = [
    "${PUBLISHER}/aws-neuron-vllm:${TAG_SUFFIX}"
  ]

  contexts = {
    scripts = "./scripts"
    proxy   = "./proxy"
  }
}