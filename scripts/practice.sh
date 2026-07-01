#!/bin/bash

cd ../python

python_files=$(find . -maxdepth 1 -type f -name "*.py")

for file in $python_files; do
    grep -hE '^[[:space:]]*(import|from)[[:space:]]' "$file"
done |
sed -E '
    s/^[[:space:]]*import[[:space:]]+//
    s/^[[:space:]]*from[[:space:]]+([^[:space:]]+).*/\1/
' |
tr ',' '\n' |
sed 's/^[[:space:]]*//' |
cut -d' ' -f1 |
cut -d'.' -f1 |
sort -u