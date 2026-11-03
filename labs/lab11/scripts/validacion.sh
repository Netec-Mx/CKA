#!/usr/bin/env bash

echo "=== Validacion complementaria 6.1 ==="

# 1. Extraer datos del Servicio y Endpoints limpiando espacios ocultos de Windows
SELECTOR=$(kubectl get service backend-svc -n lab6 -o jsonpath='{.spec.selector.app}' 2>/dev/null | tr -d '[:space:]')
ENDPOINTS=$(kubectl get endpoints backend-svc -n lab6 -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | tr -d '[:space:]')
CURRENT_IP=$(kubectl get service backend-svc -n lab6 -o jsonpath='{.spec.clusterIP}' 2>/dev/null | tr -d '[:space:]')

echo "Selector: ${SELECTOR:-Ninguno}"
echo "Endpoints: ${ENDPOINTS:-Ninguno}"
echo "ClusterIP conservada: ${CURRENT_IP:-Ninguna}"

# 2. Obtener el nombre del primer Pod de Frontend
FRONTEND_POD=$(kubectl get pod -n lab6 -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | tr -d '[:space:]')

if [ -n "$FRONTEND_POD" ]; then
  # 3. Ejecutar la prueba de conectividad interna desde el Pod
  RESPONSE=$(kubectl exec -n lab6 "$FRONTEND_POD" -- sh -c 'wget -qO- http://backend-svc' 2>/dev/null)

  # Validar el contenido de la respuesta protegiendo variables vacías
  if echo "$RESPONSE" | grep -q "BACKEND API" 2>/dev/null; then
    echo "Conectividad: OK"
  else
    echo "Conectividad: ERROR"
  fi
else
  echo "❌ No se encontró ningún Pod con la etiqueta app=frontend en el namespace lab6"
  echo "Conectividad: ERROR"
fi

echo ""
echo "=== Fin de validacion ==="
