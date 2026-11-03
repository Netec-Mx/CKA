#!/usr/bin/env bash

echo "=== Verificacion final de la Practica 3 ==="

# 1. Verificar Nodos no listos (Limpiando salidas para Git Bash)
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk 'BEGIN {count=0} $2 !~ /^Ready/ {count++} END {print count}' | tr -d ' ')

if [ "${NOT_READY:-0}" = "0" ]; then
  echo "✅ Todos los nodos estan disponibles"
else
  echo "❌ Existe al menos un nodo no disponible ($NOT_READY)"
fi

# 2. Verificar SchedulingDisabled en los Nodos
if kubectl get nodes --no-headers 2>/dev/null | grep -q "SchedulingDisabled"; then
  echo "❌ Existe un nodo con SchedulingDisabled"
else
  echo "✅ Todos los nodos aceptan scheduling"
fi

# 3. Verificar Deployment 'app-web' en namespace lab3
WEB_READY=$(kubectl get deployment app-web -n lab3 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
WEB_DESIRED=$(kubectl get deployment app-web -n lab3 -o jsonpath='{.spec.replicas}' 2>/dev/null)

WEB_READY=${WEB_READY:-0}
WEB_DESIRED=${WEB_DESIRED:-0}

if [ "$WEB_READY" = "$WEB_DESIRED" ] && [ "$WEB_DESIRED" -ne 0 ]; then
  echo "✅ app-web disponible: $WEB_READY/$WEB_DESIRED"
else
  echo "❌ app-web incompleto o inexistente: $WEB_READY/$WEB_DESIRED"
fi

# 4. Verificar Deployment 'app-backend' en namespace lab3
BACK_READY=$(kubectl get deployment app-backend -n lab3 -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
BACK_DESIRED=$(kubectl get deployment app-backend -n lab3 -o jsonpath='{.spec.replicas}' 2>/dev/null)

BACK_READY=${BACK_READY:-0}
BACK_DESIRED=${BACK_DESIRED:-0}

if [ "$BACK_READY" = "$BACK_DESIRED" ] && [ "$BACK_DESIRED" -ne 0 ]; then
  echo "✅ app-backend disponible: $BACK_READY/$BACK_DESIRED"
else
  echo "❌ app-backend incompleto o inexistente: $BACK_READY/$BACK_DESIRED"
fi

# 5. Despliegue de estados actuales
echo ""
echo "Distribucion final de Pods:"
kubectl get pods -n lab3 -o wide 2>/dev/null || echo "❌ No se encontraron Pods en el namespace lab3"

echo ""
echo "PodDisruptionBudgets:"
kubectl get pdb -n lab3 2>/dev/null || echo "❌ No se encontraron PDBs en el namespace lab3"

echo ""
echo "=== Fin de verificacion ==="
