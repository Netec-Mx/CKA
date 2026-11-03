#!/usr/bin/env bash

echo "=== Validacion complementaria 5.1 ==="

echo ""
echo "--- Lectura de Services ---"
for verb in get list watch; do
  RESULT=$(kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5 2>/dev/null | tr -d '[:space:]')

  echo "$verb services: $RESULT"
done

echo ""
echo "--- Escritura de Services ---"
for verb in create update delete; do
  RESULT=$(kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5 2>/dev/null | tr -d '[:space:]')

  echo "$verb services: $RESULT"
done

echo ""
echo "--- Permisos sensibles ---"

CAN_GET_SECRETS=$(kubectl auth can-i get secrets --as=system:serviceaccount:lab5:app-reader --namespace=lab5 2>/dev/null | tr -d '[:space:]')
echo "get secrets: $CAN_GET_SECRETS"

CAN_CREATE_PODS=$(kubectl auth can-i create pods --as=system:serviceaccount:lab5:app-reader --namespace=lab5 2>/dev/null | tr -d '[:space:]')
echo "create pods: $CAN_CREATE_PODS"

CAN_GET_PODS_KUBE=$(kubectl auth can-i get pods --as=system:serviceaccount:lab5:app-reader --namespace=kube-system 2>/dev/null | tr -d '[:space:]')
echo "get pods kube-system: $CAN_GET_PODS_KUBE"

echo ""
echo "=== Fin de validacion ==="
