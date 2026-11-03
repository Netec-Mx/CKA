#!/usr/bin/env bash

echo "=== Validacion final Lab 2 ==="

echo ""
echo "--- Deployment ---"
kubectl get deployment node-web-deployment 2>/dev/null || echo "❌ Deployment no encontrado"

echo ""
echo "--- Pods ---"
kubectl get pods -l app=node-web -o wide 2>/dev/null

echo ""
echo "--- Service ---"
kubectl get service node-web-service 2>/dev/null || echo "❌ Service no encontrado"

echo ""
echo "--- Selector ---"
# Se envuelve el jsonpath en comillas simples dobles para evitar problemas de escape en Git Bash de Windows
SELECTORES=$(kubectl get service node-web-service -o jsonpath='{.spec.selector}' 2>/dev/null)
if [ -n "$SELECTORES" ]; then
  echo "$SELECTORES"
else
  echo "❌ No se pudieron obtener los selectores"
fi

echo ""
echo "--- Endpoints ---"
kubectl get endpoints node-web-service 2>/dev/null || echo "❌ Endpoints no encontrados"

echo ""
echo "--- Health mediante Service ---"
# Se ejecuta el wget dentro del deployment para validar la conectividad interna
kubectl exec deployment/node-web-deployment -- wget -qO- http://node-web-service/health 2>/dev/null || echo "❌ Falló la conexión al endpoint de salud"

echo ""
echo "=== Fin de validacion ==="
