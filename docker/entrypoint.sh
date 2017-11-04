#!/bin/bash
set -e

APP_NAME=${1}
TEMPLATE_URL=https://raw.githubusercontent.com/civica-digital/civic-generator/master/civicops.rb

main() {
  initialize_keybase
  execute_generator
}

initialize_keybase() {
  run_keybase > /dev/null
}

execute_generator() {
  exec rails new ${APP_NAME} \
    --template=${TEMPLATE_URL} \
    --skip-bundle
}

main
