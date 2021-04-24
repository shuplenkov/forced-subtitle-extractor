#!/bin/bash
set -e

crond

source /extractForcedSubtitles.sh&

/node_modules/.bin/pm2 --no-daemon start /pm2.json --env production
