#!/usr/bin/env bash

set -o errexit

release="_build/prod/rel/asset_monitoring_dash/bin/asset_monitoring_dash"

"$release" eval "AssetMonitoringDash.Release.migrate()"

(
  "$release" eval "AssetMonitoringDash.Release.seed()"
) &

exec _build/prod/rel/asset_monitoring_dash/bin/server
