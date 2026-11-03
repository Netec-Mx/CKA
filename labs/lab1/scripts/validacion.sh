#!/usr/bin/env bash

echo "=== Verificación final de la Práctica 1 ==="

# 1. Verificar Nodo
NODE_READY=$(kubectl get node minikube -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [ "$NODE_READY" = "True" ]; then
  echo "✅ Nodo Minikube en estado Ready"
else
  echo "❌ Nodo Minikube no está Ready"
fi

# 2. Verificar Deployment
AVAILABLE=$(kubectl get deployment node-web-deployment -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
if [ "$AVAILABLE" = "1" ]; then
  echo "✅ Deployment disponible con 1 réplica"
else
  echo "❌ Deployment sin réplica disponible"
fi

# 3. Verificar Pod
POD_PHASE=$(kubectl get pods -l app=node-web -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$POD_PHASE" = "Running" ]; then
  echo "✅ Pod en estado Running"
else
  echo "❌ Pod no está en estado Running"
fi

# 4. Verificar Service
SERVICE_TYPE=$(kubectl get service node-web-service -o jsonpath='{.spec.type}' 2>/dev/null)
if [ "$SERVICE_TYPE" = "NodePort" ]; then
  echo "✅ Service NodePort creado"
else
  echo "❌ Service NodePort no encontrado"
fi

# 5. Verificar Endpoints (limpiando espacios para compatibilidad con Git Bash)
ENDPOINT_COUNT=$(kubectl get endpoints node-web-service -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')

if [ -n "$ENDPOINT_COUNT" ] && [ "$ENDPOINT_COUNT" -ge 1 ] 2>/dev/null; then
  echo "✅ Service asociado con al menos un endpoint"
else
  echo "❌ Service sin endpoint disponible"
fi

echo "=== Fin de verificación ==="
