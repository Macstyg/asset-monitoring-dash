#!/usr/bin/env bash

set -o errexit

_build/prod/rel/asset_monitoring_dash/bin/asset_monitoring_dash eval "AssetMonitoringDash.Release.migrate_and_seed()"

exec _build/prod/rel/asset_monitoring_dash/bin/server
