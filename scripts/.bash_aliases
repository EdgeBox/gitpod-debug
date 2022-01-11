#!/bin/bash

update-container-packages() {
  PARENT=$(basename $(dirname "$PWD"))
  if [[ "$PARENT" == "services" ]] ;
  then
    echo -e "\n\nUpdating the container with the new package...\n\n"
    CURRENT=$(basename $PWD)
    (cd /workspace/stack && docker-compose exec -T "$CURRENT" yarn --frozen-lockfile)

    # If this is a React app, we have to restart the container as otherwise React will
    # keep serving an outdated (cached) version of the package to browsers even when
    # you refresh the page.
    if [[ "$CURRENT" == "app" || "$CURRENT" == "embed" ]] ;
    then
      echo -e "\n\nRestarting the container...\n\n"
      (cd /workspace/stack && docker-compose restart "$CURRENT")
    fi
  fi
}
alias ucp='update-container-packages'

alias ebup='yarn upgrade --latest --scope @edgebox && ebi'

alias watch-ram="watch --color '/workspace/stack/scripts/ram-usage.sh'"

dc() {
  if [[ "$WORDPRESS" == "1" ]] ;
  then
    echo "Including Wordpress..."
    (cd /workspace/stack && docker-compose --profile wordpress "$@")
  else
    (cd /workspace/stack && docker-compose "$@")
  fi
}

ebi() {
  yarn --frozen-lockfile
  ucp
}

run-test() {
  SUITE="$1"
  TEST_ID="$2"

  source /workspace/stack/env.sh

  EXPORT_SITE="https://${DEFAULT_EXPORT_DOMAIN}"
  IMPORT_SITE="https://${DEFAULT_IMPORT_DOMAIN}"

  API="https://${API_DOMAIN}"
  FRESH_EXPORT_SITE="https://${FRESH_EXPORT_DOMAIN}"
  FRESH_IMPORT_SITE="https://${FRESH_IMPORT_DOMAIN}"

  if [[ "$SUITE" == "core-fields" ]] ;
  then
    ghost-inspector suite execute 5ed74b6b542d8c0b866bc414 --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "core-functions" ]] ;
  then
    ghost-inspector suite execute 5ee8bce684c3505ea71a45b4 --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "contrib-fields" ]] ;
  then
    ghost-inspector suite execute 5ee8bceee2f0792dcf662903 --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "contrib-functions" ]] ;
  then
    ghost-inspector suite execute 5eec5ce384c3505ea7351689 --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "fresh-installation" ]] ;
  then
    echo "Configure sites"
    ghost-inspector test execute 5e8f22aeca79c736104c4050 --drupal-version=8 --contentSyncVersion=2 --export-site=$FRESH_EXPORT_SITE --import-site=$FRESH_IMPORT_SITE --api=$API

    echo "Le core fields..."
    ghost-inspector suite execute 5ed74b6b542d8c0b866bc414 --drupal-version=8 --export-site=$FRESH_EXPORT_SITE --import-site=$FRESH_IMPORT_SITE

    echo "El core functions..."
    ghost-inspector suite execute 5ee8bce684c3505ea71a45b4 --drupal-version=8 --export-site=$FRESH_EXPORT_SITE --import-site=$FRESH_IMPORT_SITE

    echo "Der contrib fields..."
    ghost-inspector suite execute 5ee8bceee2f0792dcf662903 --drupal-version=8 --export-site=$FRESH_EXPORT_SITE --import-site=$FRESH_IMPORT_SITE

    echo "Il contrib functions..."
    ghost-inspector suite execute 5eec5ce384c3505ea7351689 --drupal-version=8 --export-site=$FRESH_EXPORT_SITE --import-site=$FRESH_IMPORT_SITE
  elif [[ "$SUITE" == "single-test" ]] && [[ "$TEST_ID" != "" ]] ;
  then
    ghost-inspector test execute $TEST_ID --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "misc" ]] ;
  then
    ghost-inspector suite execute 5ef34d1384c3505ea754d015 --drupal-version=8 --export-site=$EXPORT_SITE --import-site=$IMPORT_SITE
  elif [[ "$SUITE" == "content-syndication" ]] ;
  then
    SITE_1="https://${SYNDICATION_SITE_1_DOMAIN}"
    SITE_2="https://${SYNDICATION_SITE_2_DOMAIN}"
    SITE_3="https://${SYNDICATION_SITE_3_DOMAIN}"

    ghost-inspector suite execute 5ebe340f2b5be62d8ccaa0a3 --drupal-version=8 --site-1=$SITE_1 --site-2=$SITE_2 --site-3=$SITE_3
  elif [[ "$SUITE" == "all" ]] ;
  then
    echo 'Running all test suites. Although "Walking all test suites" would be more precise 😴 talk to you next week 👋'

    echo "Le core fields..."
    run-test core-fields

    echo "El core functions..."
    run-test core-functions

    echo "Der contrib fields..."
    run-test contrib-fields

    echo "Il contrib functions..."
    run-test contrib-functions
  else
    echo "Unknown suite $SUITE. Please rtfm." >&2
    echo "The following suits are availabe: core-fields, core-functions, contrib-fields, contrib-functions, all, fresh-installation" >&2
  fi
}

reset-api() {
  (cd /workspace/stack; docker exec -i stack_mongo_1 mongo api --eval "db.dropDatabase()"; docker-compose run --no-deps --rm api yarn console:dev data import required)
}

reset-fresh-installation() {
  docker exec -i stack_mongo_1 mongo sync-core --eval "db.dropDatabase()"
  docker exec -i stack_mongo_1 mongo api --eval "db.dropDatabase()"
  docker exec -w /opt/drupal/docroot -i stack_drupal_1 drush @fresh-export.gitpod ev '\Drupal::state()->delete("cms_content_sync.site_uuid")'
  docker exec -w /opt/drupal/docroot -i stack_drupal_1 drush @fresh-import.gitpod ev '\Drupal::state()->delete("cms_content_sync.site_uuid")'
  docker-compose down && docker-compose up -d
  docker-compose exec sync-core-2 yarn console:dev install new
  docker-compose run --no-deps --rm api yarn console:dev data import required
}

drupal-switch-v1() {
  cd /workspace/stack/php-library && git checkout tags/2.3
  cd /workspace/stack/drupal/module && git checkout 8.x-1.x
  cd /workspace/stack
}

drupal-switch-v2() {
  cd /workspace/stack/php-library && git checkout 3.x
  cd /workspace/stack/drupal/module && git checkout 2.1.x
  docker exec -i stack_drupal_1 drush @default-export.local -y updb
  docker exec -i stack_drupal_1 drush @default-import.local -y updb
  docker exec -i stack_drupal_1 drush @default-export.local cr
  docker exec -i stack_drupal_1 drush @default-import.local cr
  cd /workspace/stack
}

rollback-to-v1() {
  drupal-switch-v1

  EXPORT_SITE="https://${DEFAULT_EXPORT_DOMAIN}"
  IMPORT_SITE="https://${DEFAULT_IMPORT_DOMAIN}"

  # Get clean database dumps
  aws s3 cp s3://gitpod-files/drupal-database-dumps/d8_default-export.sql ./drupal/default-export.sql
  aws s3 cp s3://gitpod-files/drupal-database-dumps/d8_default-import.sql ./drupal/default-import.sql

  docker exec -i stack_drupal_1 drush @default-export.local -y sql-drop
  docker exec -i stack_drupal_1 drush @default-import.local -y sql-drop
  docker-compose exec -T mysql mysql -uroot -proot_password "default_export" < ./drupal/default-export.sql
  docker-compose exec -T mysql mysql -uroot -proot_password "default_import" < ./drupal/default-import.sql

  docker exec -i stack_drupal_1 drush @default-export.local cr
  docker exec -i stack_drupal_1 drush @default-import.local cr

  # Set Sync Core V1 URL
  docker exec -i stack_drupal_1 drush @default-export.local cset cms_content_sync.pool.content_staging_content backend_url http://test:test@sync-core-1:8691/rest
  docker exec -i stack_drupal_1 drush @default-import.local cset cms_content_sync.pool.content_staging_content backend_url http://test:test@sync-core-1:8691/rest

  # Ensure base urls
  docker exec -i stack_drupal_1 drush @default-export.local ev "\Drupal::state()->set('cms_content_sync.base_url', '$EXPORT_SITE');"
  docker exec -i stack_drupal_1 drush @default-import.local ev "\Drupal::state()->set('cms_content_sync.base_url', '$IMPORT_SITE');"

  # Delete V2 configs
  docker exec -i stack_drupal_1 drush @default-export.local cdel system.action.push_status_entity_to_v2
  docker exec -i stack_drupal_1 drush @default-export.local cdel rest.resource.cms_content_sync_sync_core_entity_item
  docker exec -i stack_drupal_1 drush @default-export.local cdel rest.resource.cms_content_sync_sync_core_entity_list
  docker exec -i stack_drupal_1 drush @default-import.local cdel system.action.push_status_entity_to_v2
  docker exec -i stack_drupal_1 drush @default-import.local cdel rest.resource.cms_content_sync_sync_core_entity_item
  docker exec -i stack_drupal_1 drush @default-import.local cdel rest.resource.cms_content_sync_sync_core_entity_list

  # Reset role configuration
  # ToDo!
  # drush cset user.role.cms_content_sync permissions '["restful get cms_content_sync_preview_resource", "restful get cms_content_sync_entity_resource","restful post cms_content_sync_entity_resource", "restful patch cms_content_sync_entity_resource", "restful delete cms_content_sync_entity_resource", "restful get cms_content_sync_sync_core_entity_list"]'


  # Export config
  docker exec -i stack_drupal_1 drush @default-export.local cse
  docker exec -i stack_drupal_1 drush @default-import.local cse

  rm /workspace/stack/drupal/default-export.sql
  rm /workspace/stack/drupal/default-import.sql

  # Reset Sync Core and API
  docker exec -i stack_mongo_1 mongo sync-core --eval "db.dropDatabase()"
  docker exec -i stack_mongo_1 mongo api --eval "db.dropDatabase()"
  docker-compose down && docker-compose up -d
  docker-compose run --no-deps --rm api yarn console:dev data import required

  # Get Login links
  docker exec -i stack_drupal_1 drush @default-export.local uli
  docker exec -i stack_drupal_1 drush @default-import.local uli
}

domains() {
  echo "App:" $(gp url 3000)
  echo "Embed:" $(gp url 3001)
  echo "Api:" $(gp url 3010)
  echo "Sync Core:" $(gp url 3020)
  echo "Elastic Search:" $(gp url 9200)
  echo "Kibana:" $(gp url 5601)
  echo "Drupal - Default Export:" $(gp url 3030)
  echo "Drupal - Default Import:" $(gp url 3031)
  echo "Drupal - Syndication Site 1:" $(gp url 3032)
  echo "Drupal - Syndication Site 2:" $(gp url 3033)
  echo "Drupal - Syndication Site 3:" $(gp url 3034)
  echo "Drupal - Fresh Export:" $(gp url 3035)
  echo "Drupal - Fresh Import:" $(gp url 3036)
}

drupal-logins() {
  EXPORT_URL=$(ddrush @default-export.local uli) &&
  IMPORT_URL=$(ddrush @default-import.local uli) &&
  echo "Export Site: $EXPORT_URL" &&
  echo "Import Site: $IMPORT_URL" &&
  if [ "$START_SYNDICATION_SITES" == "true" ]; then
  SYNDICATION_SITE_1_URL=$(ddrush @syndication-site-1.local uli) &&
  SYNDICATION_SITE_2_URL=$(ddrush @syndication-site-2.local uli) &&
  SYNDICATION_SITE_3_URL=$(ddrush @syndication-site-3.local uli) &&
  echo "Syndication Site 1: $SYNDICATION_SITE_1_URL" &&
  echo "Syndication Site 2: $SYNDICATION_SITE_2_URL" &&
  echo "Syndication Site 3: $SYNDICATION_SITE_3_URL";
  fi &&
  if [ "$FRESH_INSTALLATION" == "true" ]; then
  FRESH_EXPORT_URL=$(ddrush @fresh-export.local uli) &&
  FRESH_IMPORT_URL=$(ddrush @fresh-import.local uli) &&
  echo "Fresh Export: $FRESH_EXPORT_URL" &&
  echo "Fresh Import: $FRESH_IMPORT_URL";
  fi
}

# Kill process on port
alias kpop='sudo fuser -n tcp -k $1'

# Push the module to Drupal with the current user's credentials.
alias push-drupal-module='git push https://$DRUPAL_GIT_USERNAME:$DRUPAL_GIT_PASSWORD@git.drupalcode.org/project/cms_content_sync.git/'

# Syndication Status: Show syndication count, grouped by status. Updated every half second.
# Without the clear it doesn't work in gitpod.
alias ebss='clear; docker-compose exec sync-core-2 yarn console:dev syndication status'

# Messages Cron: Re-run any failed or other "queued for later" messages.
alias ebmc='docker-compose exec sync-core-broker yarn console-broker:dev messages cron'
# Run messages cron, then show syndication status.
alias ebmcss='ebmc; ebss'
# Run update-stats cron
alias ebus='docker-compose exec sync-core-2 yarn run console:dev syndication update-stats'
# Run Contracts renewal cron
alias ebcr='docker-compose exec api yarn console:dev contracts renew'

# Sync Core: Update Clients.
# Update the swagger.yaml, then based on that the rest-client and php-rest-client and then move the code to the local php-library and run a codestyle fix.
alias scuc='(cd /workspace/stack/services/sync-core-2 && yarn update-rest-client && rm -rf /workspace/stack/php-library/src/V2/Raw/* && cp -r ./php-rest-client/src/Raw/* /workspace/stack/php-library/src/V2/Raw/ && cd /workspace/stack/php-library && composer fix-cs && cd /workspace/stack)'

# Control xDebug within Drupal
alias xdebug-enable='/workspace/stack/scripts/drupal/xdebug.sh enable "$1"'
alias xdebug-disable='/workspace/stack/scripts/drupal/xdebug.sh disable "$1"'
alias xdebug-kill='fuser -k 9003/tcp'

source /workspace/stack/env.sh
