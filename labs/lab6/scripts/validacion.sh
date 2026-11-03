#!/usr/bin/env bash

echo "=== Verificacion final de la Practica 4 ==="

# 1. Verificar los Namespaces 'development' y 'production'
for ns in development production; do
  STATUS=$(kubectl get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$STATUS" = "Active" ]; then
    echo "✅ Namespace $ns disponible"
  else
    echo "❌ Namespace $ns no disponible"
  fi
done

# 2. Verificar eliminación de 'staging'
if kubectl get namespace staging >/dev/null 2>&1; then
  echo "❌ staging todavia existe"
else
  echo "✅ staging fue eliminado"
fi

# 3. Verificar ResourceQuota en 'development'
if kubectl get resourcequota development-quota -n development >/dev/null 2>&1; then
  echo "✅ ResourceQuota disponible"
else
  echo "❌ ResourceQuota no encontrada"
fi

# 4. Verificar LimitRange en 'development'
if kubectl get limitrange development-limits -n development >/dev/null 2>&1; then
  echo "✅ LimitRange disponible"
else
  echo "❌ LimitRange no encontrado"
fi

# 5. Mostrar Deployments restantes relacionados con 'webapp'
echo ""
echo "Deployments restantes:"
DEPLOYMENTS_EXIST=$(kubectl get deployments --all-namespaces 2>/dev/null | grep "webapp")

if [ -n "$DEPLOYMENTS_EXIST" ]; then
  echo "$DEPLOYMENTS_EXIST"
else
  echo "ℹ️ No se encontraron deployments con el nombre 'webapp'"
fi

echo ""
echo "=== Fin de verificacion ==="
