#!/bin/bash

[[ -n "$input_file" ]] || echo "script was not provided with \$input_file"
[[ -n "$statistics_dir" ]] || echo "script was not provided with \$statistics_dir"

cat "${input_file}" |
  cut -c 89-92 |
  grep -v 999 |
  sort -rn |
  head -n1 > ${statistics_dir}/max.txt

cat "${input_file}" |
  cut -c 89-92 |
  grep -v 999 |
  sort -n |
  head -n1 > ${statistics_dir}/min.txt

cat "${input_file}" |
  cut -c 89-92 |
  grep -v 999 |
  awk "{ total += \$1; count++ } END { print total/count }" > ${statistics_dir}/average.txt 
