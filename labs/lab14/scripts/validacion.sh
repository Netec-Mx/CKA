#!/usr/bin/env bash

echo "=== Validacion final de la Practica 8 ==="

# 1. Verificar Estado de las Fases de los Pods
for POD in \
  pod-a1-imagepull \
  pod-a2-crashloop \
  pod-a3-pending \
  pod-b1-backend \
  pod-b2-webserver \
  pod-c1-dns-policy \
  pod-c2-dns-debug
do
  STATUS=$(kubectl get pod "$POD" -n troubleshooting-lab -o jsonpath='{.status.phase}' 2>/dev/null | tr -d '[:space:]')
  echo "$POD: ${STATUS:-No encontrado}"
done

# 2. Verificar Réplicas del Deployment de Liveness
READY=$(kubectl get deployment deploy-b3-liveness -n troubleshooting-lab -o jsonpath='{.status.readyReplicas}' 2>/dev/null | tr -d '[:space:]')
echo "deploy-b3-liveness ready: ${READY:-0}/2"

# 3. Extraer Selectores, Puertos y Rutas de Liveness
B1_SELECTOR=$(kubectl get service svc-b1-wrong-selector -n troubleshooting-lab -o jsonpath='{.spec.selector.app}' 2>/dev/null | tr -d '[:space:]')
B2_TARGET=$(kubectl get service svc-b2-wrong-port -n troubleshooting-lab -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null | tr -d '[:space:]')
B3_PATH=$(kubectl get deployment deploy-b3-liveness -n troubleshooting-lab -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null | tr -d '[:space:]')

echo "B1 selector: ${B1_SELECTOR:-Ninguno}"
echo "B2 targetPort: ${B2_TARGET:-Ninguno}"
echo "B3 liveness path: ${B3_PATH:-Ninguno}"

# 4. Mostrar Estado de Endpoints
echo ""
echo "Endpoints:"
kubectl get endpoints -n troubleshooting-lab svc-b1-wrong-selector svc-b2-wrong-port svc-b3-liveness 2>/dev/null || echo "❌ Error al consultar los endpoints"

# 5. Pruebas de Diagnóstico DNS mediante Exec
echo ""
echo "DNS:"

# Validar C1 DNS
C1_EXISTS=$(kubectl get pod pod-c1-dns-policy -n troubleshooting-lab -o jsonpath='{.metadata.name}' 2>/dev/null | tr -d '[:space:]')
if [ -n "$C1_EXISTS" ]; then
  if kubectl exec pod-c1-dns-policy -n troubleshooting-lab -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
    echo "C1 DNS: OK"
  else
    echo "C1 DNS: FAIL"
  fi
else
  echo "C1 DNS: FAIL (Pod no encontrado)"
fi

# Validar C2 DNS
C2_EXISTS=$(kubectl get pod pod-c2-dns-debug -n troubleshooting-lab -o jsonpath='{.metadata.name}' 2>/dev/null | tr -d '[:space:]')
if [ -n "$C2_EXISTS" ]; then
  if kubectl exec pod-c2-dns-debug -n troubleshooting-lab -- nslookup svc-b1-wrong-selector.troubleshooting-lab.svc.cluster.local >/dev/null 2>&1; then
    echo "C2 DNS: OK"
  else
    echo "C2 DNS: FAIL"
  fi
else
  echo "C2 DNS: FAIL (Pod no encontrado)"
fi

echo ""
echo "=== Fin de validacion ==="
