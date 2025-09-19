#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/covid"
input_dir="${eval_dir}/inputs"
outputs_dir="${eval_dir}/outputs"
scripts_dir="${eval_dir}/scripts"
export LC_ALL=C

suffix=""
for arg in "$@"; do
    if [ "$arg" = "--small" ]; then
        suffix="_small"
        break
    fi
    if [ "$arg" = "--min" ]; then
        suffix="_min"
        break
    fi
done

input_file="$input_dir/in$suffix.csv"
output_scoped="$outputs_dir/outputs$suffix"
mkdir -p "$output_scoped"

KOALA_SHELL="${KOALA_SHELL:-bash}"
export KOALA_SHELL

BENCHMARK_CATEGORY="covid"
export BENCHMARK_CATEGORY

BENCHMARK_INPUT_FILE="$(realpath "$input_file")"
export BENCHMARK_INPUT_FILE

for i in 1 2 3 4 5; do
    script="$scripts_dir/$i.sh"
    BENCHMARK_SCRIPT="$(realpath "$script")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$script" "$input_file" > "$output_scoped/$i.out"
done