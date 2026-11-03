#!/usr/bin/env bash

echo "=== Validacion complementaria 6.2 ==="

# 1. Verificar existencia y dnsPolicy del Pod
DNS_POLICY=$(kubectl get pod dns-client -n lab6 -o jsonpath='{.spec.dnsPolicy}' 2>/dev/null | tr -d '[:space:]')

if [ -n "$DNS_POLICY" ]; then
  echo "dnsPolicy: $DNS_POLICY"
  
  echo ""
  echo "Resolucion FQDN:"
  kubectl exec -n lab6 dns-client -- nslookup backend-svc.lab6.svc.cluster.local 2>/dev/null || echo "❌ Falló la resolución DNS del FQDN"

  echo ""
  echo "HTTP:"
  # Se ejecuta el wget y se evalúa la respuesta de forma segura para Git Bash
  HTTP_RESPONSE=$(kubectl exec -n lab6 dns-client -- sh -c 'wget -qO- http://backend-svc' 2>/dev/null)
  
  if echo "$HTTP_RESPONSE" | grep -q "BACKEND API" 2>/dev/null; then
    echo "✅ Conexión HTTP exitosa y contenido validado: 'BACKEND API'"
  else
    echo "❌ Error en conexión HTTP o contenido inesperado"
  fi
else
  echo "❌ El Pod 'dns-client' no se encuentra en el namespace lab6"
fi

echo ""
echo "=== Fin de validacion ==="
