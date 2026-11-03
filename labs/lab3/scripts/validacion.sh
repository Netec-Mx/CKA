#!/usr/bin/env bash

echo "=== Verificacion final de la Practica 1.1 ==="

# 1. Verificar Réplicas (Disponibles vs Deseadas)
READY=$(kubectl get deployment webapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
DESIRED=$(kubectl get deployment webapp -o jsonpath='{.spec.replicas}' 2>/dev/null)

# Asegurar que si están vacías se traten como 0 para evitar errores de sintaxis
READY=${READY:-0}
DESIRED=${DESIRED:-0}

if [ "$READY" = "$DESIRED" ] && [ "$DESIRED" -ne 0 ]; then
  echo "✅ Deployment disponible: $READY/$DESIRED replicas"
else
  echo "❌ Deployment incompleto: $READY/$DESIRED replicas"
fi

# 2. Verificar Imagen (Rollback)
IMAGE=$(kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

if [ "$IMAGE" = "nginx:1.25" ]; then
  echo "✅ Rollback confirmado: imagen activa nginx:1.25"
else
  echo "❌ Imagen inesperada: ${IMAGE:-Ninguna}"
fi

# 3. Contar ReplicaSets Históricos (Limpiando espacios para Git Bash)
RS_COUNT=$(kubectl get rs -l app=webapp --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [ -n "$RS_COUNT" ] && [ "$RS_COUNT" -ge 2 ] 2>/dev/null; then
  echo "✅ Existen ReplicaSets historicos para el Deployment"
else
  echo "❌ No se identificaron ReplicaSets historicos"
fi

# 4. Despliegue de Historiales y Estados actuales
echo ""
echo "Historial de revisiones:"
kubectl rollout history deployment/webapp 2>/dev/null || echo "❌ No se pudo obtener el historial"

echo ""
echo "ReplicaSets:"
kubectl get rs -l app=webapp 2>/dev/null || echo "❌ No se encontraron ReplicaSets"

echo ""
echo "=== Fin de verificación ==="
