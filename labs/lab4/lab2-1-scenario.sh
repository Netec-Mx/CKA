#!/usr/bin/env bash

set -euo pipefail

POD_NAME=$(kubectl get pods \
  -l app=webapp \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
  echo "No se encontró ningún Pod con app=webapp."
  echo "Completa primero la Práctica 2."
  exit 1
fi

kubectl label pod "$POD_NAME" \
  app=webapp-debug \
  --overwrite

echo "Escenario aplicado."
