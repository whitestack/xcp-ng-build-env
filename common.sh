#!/bin/bash

function login_to_gcp() {
  echo "====> Logging in into GCP"
  echo "$1" >key.json
  GCLOUD_PROJECT=$(echo "$1" | awk -F',' '{print $2}' | awk -F':' '{print $2}' | xargs)
  gcloud auth activate-service-account --key-file=key.json --project="$GCLOUD_PROJECT"
  gcloud auth configure-docker -q gcr.io,us-central1-docker.pkg.dev
}
