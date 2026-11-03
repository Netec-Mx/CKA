#!/usr/bin/env bash

echo "=== Verificacion final de la Practica 6 ==="

# 1. Verificar Réplicas de Deployments
BACKEND_READY=$(kubectl get deployment backend -n lab6 -o jsonpath='{.status.readyReplicas}' 2>/dev/null | tr -d '[:space:]')
FRONTEND_READY=$(kubectl get deployment frontend -n lab6 -o jsonpath='{.status.readyReplicas}' 2>/dev/null | tr -d '[:space:]')

if [ "$BACKEND_READY" = "2" ]; then
  echo "✅ backend disponible: 2/2"
else
  echo "❌ backend incompleto: ${BACKEND_READY:-0}/2"
fi

if [ "$FRONTEND_READY" = "2" ]; then
  echo "✅ frontend disponible: 2/2"
else
  echo "❌ frontend incompleto: ${FRONTEND_READY:-0}/2"
fi

# 2. Verificar Tipos de Servicios
BACKEND_TYPE=$(kubectl get service backend-svc -n lab6 -o jsonpath='{.spec.type}' 2>/dev/null | tr -d '[:space:]')
FRONTEND_TYPE=$(kubectl get service frontend-svc -n lab6 -o jsonpath='{.spec.type}' 2>/dev/null | tr -d '[:space:]')
NODEPORT_TYPE=$(kubectl get service frontend-nodeport -n lab6 -o jsonpath='{.spec.type}' 2>/dev/null | tr -d '[:space:]')

if [ "$BACKEND_TYPE" = "ClusterIP" ]; then
  echo "✅ backend-svc es ClusterIP"
else
  echo "❌ backend-svc tiene tipo inesperado: ${BACKEND_TYPE:-No encontrado}"
fi

if [ "$FRONTEND_TYPE" = "ClusterIP" ]; then
  echo "✅ frontend-svc es ClusterIP"
else
  echo "❌ frontend-svc tiene tipo inesperado: ${FRONTEND_TYPE:-No encontrado}"
fi

if [ "$NODEPORT_TYPE" = "NodePort" ]; then
  echo "✅ frontend-nodeport es NodePort"
else
  echo "❌ frontend-nodeport tiene tipo inesperado: ${NODEPORT_TYPE:-No encontrado}"
fi

# 3. Verificar Puerto NodePort especifico
NODEPORT=$(kubectl get service frontend-nodeport -n lab6 -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null | tr -d '[:space:]')

if [ "$NODEPORT" = "30080" ]; then
  echo "✅ NodePort configurado en 30080"
else
  echo "❌ NodePort inesperado: ${NODEPORT:-Ninguno}"
fi

# 4. Verificar Endpoints activos
BACKEND_ENDPOINTS=$(kubectl get endpoints backend-svc -n lab6 -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | tr -d '[:space:]')
FRONTEND_ENDPOINTS=$(kubectl get endpoints frontend-svc -n lab6 -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | tr -d '[:space:]')

if [ -n "$BACKEND_ENDPOINTS" ]; then
  echo "✅ backend-svc tiene endpoints"
else
  echo "❌ backend-svc no tiene endpoints"
fi

if [ -n "$FRONTEND_ENDPOINTS" ]; then
  echo "✅ frontend-svc tiene endpoints"
else
  echo "❌ frontend-svc no tiene endpoints"
fi

# 5. Verificar Clase Ingress
INGRESS_CLASS=$(kubectl get ingress app-ingress -n lab6 -o jsonpath='{.spec.ingressClassName}' 2>/dev/null | tr -d '[:space:]')

if [ "$INGRESS_CLASS" = "nginx" ]; then
  echo "✅ Ingress utiliza la clase nginx"
else
  echo "❌ IngressClass inesperada: ${INGRESS_CLASS:-Ninguna}"
fi

# 6. Verificar Reglas de ruteo en el Ingress (Formato compatible con Git Bash)
ROOT_BACKEND=$(kubectl get ingress app-ingress -n lab6 -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/")].backend.service.name}' 2>/dev/null | tr -d '[:space:]')
API_BACKEND=$(kubectl get ingress app-ingress -n lab6 -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/api")].backend.service.name}' 2>/dev/null | tr -d '[:space:]')

if [ "$ROOT_BACKEND" = "frontend-svc" ]; then
  echo "✅ / apunta a frontend-svc"
else
  echo "❌ / apunta a: ${ROOT_BACKEND:-No mapeado}"
fi

if [ "$API_BACKEND" = "backend-svc" ]; then
  echo "✅ /api apunta a backend-svc"
else
  echo "❌ /api apunta a: ${API_BACKEND:-No mapeado}"
fi

echo ""
echo "=== Fin de verificacion ==="
