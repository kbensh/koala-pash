#!/bin/bash

TOP="$(git rev-parse --show-toplevel)"
input_dir="${TOP}/ci-cd/inputs/scripts/vim"

mkdir -p "$input_dir/dev"

git clone https://github.com/vim/vim.git "$input_dir/dev"
git -C "$input_dir/dev" checkout b836f631dba2534efd314a8f77439cebc75acd4e

(cd "$input_dir/dev" && "$input_dir/dev/configure")

