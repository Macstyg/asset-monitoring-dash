#!/usr/bin/env bash

set -o errexit

mix deps.get --only prod

MIX_ENV=prod mix assets.setup
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite
