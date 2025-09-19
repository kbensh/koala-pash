#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
URL="https://atlas.cs.brown.edu/data"

input_dir="${TOP}/unixfun/inputs"
mkdir -p "$input_dir"
cd "$input_dir" || exit 1

inputs=(1 2 3 4 5 6 7 8 9.1 9.2 9.3 9.4 9.5 9.6 9.7 9.8 9.9 10 11 12)

size=full
for arg in "$@"; do
    case "$arg" in
        --small) size=small ;;
        --min)   size=min ;;
    esac
done

for input in "${inputs[@]}"
do
    if [ "$size" = "min" ]; then
        if [ ! -f "${input}.txt" ]; then
            wget --no-check-certificate "${URL}/unix50/${input}.txt" || exit 1
        fi
        if [ ! -f "${input}_6M.txt" ]; then
            file_content_size=$(wc -c < "${input}.txt")
            iteration_limit=$((1048576 / $file_content_size))
            for (( i = 0; i < iteration_limit; i++ )); do
                cat "${input}.txt" >> "${input}_1M.txt"
            done
            for (( i = 0; i < 6; i++ )); do
                cat "${input}_1M.txt" >> "${input}_6M.txt"
            done
            rm "${input}_1M.txt"
        fi
    else
        continue
    fi
    if [ "$size" = "small" ]; then
        if [ ! -f "${input}_30M.txt" ]; then
            wget --no-check-certificate "${URL}/unix50/small/${input}_30M.txt" || exit 1
        else 
            continue
        fi
    fi

    if [ "$size" = "full" ]; then 
        if [ ! -f "${input}_3G.txt" ]; then
            wget --no-check-certificate "${URL}/unix50/large/${input}_3G.txt" || exit 1
        else
            continue
        fi
    fi
done
