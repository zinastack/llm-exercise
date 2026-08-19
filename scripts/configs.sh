#!/usr/bin/env bash
# NAME | MODEL_VAR | EXTRA_ENV | FLAGS | why
#
# levels are cumulative, so the table reads as a progression.

configs=(
# Pipeline validation only. Not a level, not reported.
"smoke|MODEL_SMOKE||\
--max-model-len 2048 --gpu-memory-utilization 0.30\
|Pipeline validation with a tiny model. Not a result."

# INT4 AWQ. fp16 is 141GB of the 160GB available, which leaves <20GB of kv
# and single-digit concurrency - not how anyone actually serves a 70B on two
# cards. every level below is config only, weights are untouched.

"baseline|MODEL_AWQ||\
|vLLM defaults. The 128K default context window caps how many sequences fit, regardless of available KV memory."

"L1-fit|MODEL_AWQ||\
--max-model-len 8192 --gpu-memory-utilization 0.95\
|Stop reserving context nobody uses, and claim the last 5% of HBM. Throughput up because the batch ceiling rises; TTFT down because requests stop queueing for cache blocks."

"L2-kv|MODEL_AWQ||\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2\
|Halve the bytes per KV token. Cache FORMAT, not weights - the model is unchanged. More concurrent sequences in the same memory."

"L3-schedule|MODEL_AWQ||\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192\
|Interleave prefill with decode so long prefills stop blocking token generation, and reuse shared prompt prefixes."

# Control, not a tuning level.
"nvlink-off|MODEL_AWQ|NCCL_P2P_DISABLE=1|\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192\
|Control for the NVLink question. Byte-identical to L3 except NCCL is forced to stage through host memory."

# demo endpoint, not a benchmark level. int4 because ~20ms tpot vs ~50ms on
# fp16 and a chat demo should feel responsive. tool flags because open-webui
# sends tool_choice and vllm 400s without a parser.
# kept out of TUNING_LEVELS.
"serve|MODEL_AWQ||\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192 --enable-auto-tool-choice --tool-call-parser llama3_json\
|Public demo endpoint. Not a measurement."

# same progression on fp16, to see what quantization actually buys
# part 1 reference. defaults won't start here, so this is the one change
# needed to serve at all - everything else left alone.
"baseline-servable|MODEL_FP16||\
--max-model-len 8192\
|Minimum viable baseline: the one change required to boot. All other settings default."

"fp16-baseline|MODEL_FP16||\
|vLLM defaults on the unquantized checkpoint. ~141GB of weights on 160GB leaves under 20GB for KV - roughly 59,000 tokens, and the 128K default context caps reported concurrency at ~2.6x."

"fp16-L1-fit|MODEL_FP16||\
--max-model-len 8192 --gpu-memory-utilization 0.95\
|Cap context to what is actually served and claim the last 5% of HBM. More usable KV, so more sequences resident."

"fp16-L2-kv|MODEL_FP16||\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2\
|Halve the bytes per KV token - cache FORMAT, not weights. Roughly doubles resident sequences in the same memory."

"fp16-L3-schedule|MODEL_FP16||\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192\
|Interleave prefill with decode so long prefills stop blocking generation, and reuse shared prompt prefixes."

"fp16-nvlink-off|MODEL_FP16|NCCL_P2P_DISABLE=1|\
--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192\
|Control. Byte-identical to fp16-L3 except NCCL is forced to stage through host memory."
)

# the reported progression. fp16-baseline is in here because it not starting
# is the part 1 result.
TUNING_LEVELS="fp16-baseline baseline-servable fp16-L1-fit fp16-L2-kv fp16-L3-schedule"
# int4, kept as the quantization comparison
INT4_LEVELS="baseline L1-fit L2-kv L3-schedule"

FINAL_LEVEL="serve"

config_names() { for c in "${configs[@]}"; do echo "${c%%|*}"; done; }
config_get() {
  for c in "${configs[@]}"; do [[ "${c%%|*}" == "$1" ]] && { echo "$c"; return 0; }; done
  return 1
}
config_rationale() {
  local e; e="$(config_get "$1")" || return 1
  echo "${e##*|}"
}
