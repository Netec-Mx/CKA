#!/usr/bin/env bash

echo "=== Validacion final Lab 2.1 ==="

echo ""
echo "--- Deployment ---"
kubectl get deployment webapp 2>/dev/null || echo "❌ Deployment 'webapp' no encontrado"

echo ""
echo "--- Pods administrados ---"
kubectl get pods -l app=webapp --show-labels 2>/dev/null

echo ""
echo "--- ReplicaSets ---"
kubectl get replicasets -l app=webapp 2>/dev/null

echo ""
echo "--- Historial ---"
kubectl rollout history deployment/webapp 2>/dev/null || echo "❌ No se pudo obtener el historial de rollout"

echo ""
echo "--- Estado del rollout ---"
kubectl rollout status deployment/webapp 2>/dev/null || echo "❌ No se pudo obtener el estado del rollout"

echo ""
echo "=== Fin de validacion ==="
