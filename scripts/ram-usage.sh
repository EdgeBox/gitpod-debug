#!/usr/bin/env bash

USAGE_IN_BYTES=$(cat /sys/fs/cgroup/memory/memory.kmem.usage_in_bytes)

USAGE_HUMAN_READABLE=$(echo "$USAGE_IN_BYTES" | numfmt --to=iec-i --suffix=B)

ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'
printf "${ORANGE}Usage must be below 12 GB at all times or you may lose your work.${NC}\n"
printf "Usage above 4GB is not recommended.\n\n\n\n\n"

# Show warning if greater than 4 GB which is what every pod gets guaranteed.
if (( USAGE_IN_BYTES > 1000 * 1000 * 1000 * 4 )); then
  printf "                    ${RED}Current usage is ${USAGE_HUMAN_READABLE}${NC}\n\n\n\n\n"
else
  printf "                    Current usage is ${USAGE_HUMAN_READABLE}\n\n\n\n\n"
fi
