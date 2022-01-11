#!/usr/bin/env bash

set -x

(
  cd /workspace/stack &&
  ./scripts/wait-for-healthy-container.sh stack_sync-core-2_1 &&
  ./scripts/wait-for-healthy-container.sh stack_sync-core-broker_1 &&
  /usr/bin/flock -n cron.lockfile /usr/local/bin/docker-compose exec -T sync-core-broker yarn console-broker:dev messages cron > sync-core-broker.cron.log
)

(
  cd /workspace/stack &&
  ./scripts/wait-for-healthy-container.sh stack_sync-core-2_1 &&
  ./scripts/wait-for-healthy-container.sh stack_sync-core-broker_1 &&
  /usr/bin/flock -n cron.lockfile /usr/local/bin/docker-compose exec -T sync-core-2 yarn run console:dev syndication update-stats > sync-core-2.cron.log
)
