#!/usr/bin/env bash

set -e

source common.sh

login_to_gcp "$GCP_SA"
echo "Pushing image $1"
docker push $1
echo "Pushing image $1 ... Done."
