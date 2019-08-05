#!/bin/bash

wget -q -O - https://raw.githubusercontent.com/starkandwayne/homebrew-cf/master/public.key | sudo apt-key add -
echo "deb http://apt.starkandwayne.com stable main" | sudo tee /etc/apt/sources.list.d/starkandwayne.list

wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list

sudo apt-get update

sudo apt-get install \
  genesis            \
  cf-cli             \
  jq                 \
  unzip              \
  build-essential    \
  zlibc              \
  zlib1g-dev         \
  ruby               \
  ruby-dev           \
  openssl            \
  libssl-dev         

export LATEST_VAULT_VERSION=1.1.3
wget "https://releases.hashicorp.com/vault/${LATEST_VAULT_VERSION}/vault_${LATEST_VAULT_VERSION}_linux_amd64.zip"
sudo apt-get update
sudo apt-get install unzip
sudo unzip "vault_${LATEST_VAULT_VERSION}_linux_amd64.zip" -d /usr/local/bin
sudo chmod 0777 /usr/local/bin/vault
