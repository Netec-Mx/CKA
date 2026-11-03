#!/usr/bin/env bash

echo "=== Validacion final de la Practica 7 ==="

# 1. Verificar PVC Estático
STATIC_PVC=$(kubectl get pvc pvc-lab7-static -n lab7 -o jsonpath='{.status.phase}' 2>/dev/null | tr -d '[:space:]')

if [ "$STATIC_PVC" = "Bound" ]; then
  echo "✅ PVC estatico Bound"
else
  echo "❌ PVC estatico: ${STATIC_PVC:-No encontrado}"
fi

# 2. Verificar PV Estático
STATIC_PV=$(kubectl get pv pv-lab7-static -o jsonpath='{.status.phase}' 2>/dev/null | tr -d '[:space:]')

if [ "$STATIC_PV" = "Bound" ]; then
  echo "✅ PV estatico Bound"
else
  echo "❌ PV estatico: ${STATIC_PV:-No encontrado}"
fi

# 3. Verificar Nodo de MySQL
MYSQL_NODE=$(kubectl get pod mysql-persistente -n lab7 -o jsonpath='{.spec.nodeName}' 2>/dev/null | tr -d '[:space:]')

if [ "$MYSQL_NODE" = "minikube" ]; then
  echo "✅ MySQL programado en minikube"
else
  echo "❌ MySQL programado en: ${MYSQL_NODE:-Desconocido / Pod inexistente}"
fi

# 4. Verificar Datos dentro de MySQL
if [ -n "$MYSQL_NODE" ]; then
  MYSQL_COUNT=$(kubectl exec mysql-persistente -n lab7 -- mysql -uroot -p'K8s-lab7-2026!' testdb -sNe 'SELECT COUNT(*) FROM registros;' 2>/dev/null | tr -d '[:space:]')

  if [ "$MYSQL_COUNT" = "3" ]; then
    echo "✅ Datos MySQL persistentes: 3 registros"
  else
    echo "❌ Registros encontrados: ${MYSQL_COUNT:-0}"
  fi
else
  echo "❌ Saltando validacion MySQL: Pod no disponible"
fi

# 5. Verificar PVC Dinámico
DYNAMIC_PVC=$(kubectl get pvc pvc-lab7-dynamic -n lab7 -o jsonpath='{.status.phase}' 2>/dev/null | tr -d '[:space:]')

if [ "$DYNAMIC_PVC" = "Bound" ]; then
  echo "✅ PVC dinamico Bound"
else
  echo "❌ PVC dinamico: ${DYNAMIC_PVC:-No encontrado}"
fi

# 6. Verificar Contenido en Nginx Dinámico
NGINX_EXISTS=$(kubectl get pod nginx-dynamic -n lab7 -o jsonpath='{.metadata.name}' 2>/dev/null | tr -d '[:space:]')

if [ -n "$NGINX_EXISTS" ]; then
  DYNAMIC_FILE=$(kubectl exec nginx-dynamic -n lab7 -- sh -c 'cat /usr/share/nginx/html/index.html' 2>/dev/null)

  if echo "$DYNAMIC_FILE" | grep -q "PVC dinamico operativo" 2>/dev/null; then
    echo "✅ PVC dinamico montado y con datos"
  else
    echo "❌ No se pudo validar el contenido del PVC dinamico"
  fi
else
  echo "❌ Saltando validacion Nginx: Pod 'nginx-dynamic' no disponible"
fi

# 7. Verificar comportamiento de emptyDir
EMPTYDIR_EXISTS=$(kubectl get pod emptydir-demo -n lab7 -o jsonpath='{.metadata.name}' 2>/dev/null | tr -d '[:space:]')

if [ -n "$EMPTYDIR_EXISTS" ]; then
  EMPTY_FILE=$(kubectl exec emptydir-demo -n lab7 -- sh -c 'test -f /datos/temporal.txt && echo existe || echo ausente' 2>/dev/null | tr -d '[:space:]')

  if [ "$EMPTY_FILE" = "ausente" ]; then
    echo "✅ emptyDir perdio el dato al recrear el Pod"
  else
    echo "❌ El archivo temporal sigue presente (emptyDir persistio inesperadamente)"
  fi
else
  echo "❌ Saltando validacion emptyDir: Pod 'emptydir-demo' no disponible"
fi

echo ""
echo "=== Fin de validacion ==="
