#!/usr/bin/env bash

PASS=0
TOTAL=100

pass() {
  echo "✅ $1 (+$2)"
  PASS=$((PASS + $2))
}

fail() {
  echo "❌ $1 (+0/$2)"
}

echo "================================================"
echo "        EVALUACION SIMULACION TIPO CKA"
echo "================================================"

echo ""
echo "--- T1 Mantenimiento de nodo: 15 puntos ---"

UNSCHED=$(kubectl get node minikube-m02 \
  -o jsonpath='{.spec.unschedulable}' 2>/dev/null)

READY=$(kubectl get deployment maintenance-app \
  -n cka-admin \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

if [ "$UNSCHED" != "true" ] && [ "$READY" = "6" ]; then
  pass "T1 mantenimiento completado" 15
else
  fail "T1 mantenimiento incompleto" 15
fi

echo ""
echo "--- T2 RBAC: 10 puntos ---"

CAN_GET=$(kubectl auth can-i get pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security 2>/dev/null)

CAN_SECRET=$(kubectl auth can-i get secrets \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security 2>/dev/null)

if [ "$CAN_GET" = "yes" ] && [ "$CAN_SECRET" = "no" ]; then
  pass "T2 RBAC correcto" 10
else
  fail "T2 RBAC incorrecto" 10
fi

echo ""
echo "--- T3 Rollout: 8 puntos ---"

T3_READY=$(kubectl get deployment exam-web \
  -n cka-workloads \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

T3_IMAGE=$(kubectl get deployment exam-web \
  -n cka-workloads \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

if [ "$T3_READY" = "4" ] && [ "$T3_IMAGE" = "nginx:1.27-alpine" ]; then
  pass "T3 rollout y rollback correctos" 8
else
  fail "T3 rollout incompleto" 8
fi

echo ""
echo "--- T4 Scheduling: 7 puntos ---"

T4_READY=$(kubectl get deployment analytics-app \
  -n cka-workloads \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

T4_NODES=$(kubectl get pod \
  -n cka-workloads \
  -l app=analytics-app \
  -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)

if [ "$T4_READY" = "2" ] && \
   echo "$T4_NODES" | grep -q "minikube-m03" && \
   ! echo "$T4_NODES" | grep -q "minikube-m02"; then
  pass "T4 scheduling correcto" 7
else
  fail "T4 scheduling incorrecto" 7
fi

echo ""
echo "--- T5 Service NodePort: 10 puntos ---"

T5_TYPE=$(kubectl get service broken-backend-svc \
  -n cka-network \
  -o jsonpath='{.spec.type}' 2>/dev/null)

T5_NODEPORT=$(kubectl get service broken-backend-svc \
  -n cka-network \
  -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

T5_EP=$(kubectl get endpoints broken-backend-svc \
  -n cka-network \
  -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

if [ "$T5_TYPE" = "NodePort" ] && \
   [ "$T5_NODEPORT" = "30081" ] && \
   [ "$T5_EP" -eq 2 ]; then
  pass "T5 Service reparado" 10
else
  fail "T5 Service incorrecto" 10
fi

echo ""
echo "--- T6 Ingress: 10 puntos ---"

PORTAL_READY=$(kubectl get deployment portal \
  -n cka-network \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

API_READY=$(kubectl get deployment api \
  -n cka-network \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

INGRESS_CLASS=$(kubectl get ingress exam-ingress \
  -n cka-network \
  -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)

if [ "$PORTAL_READY" = "2" ] && \
   [ "$API_READY" = "2" ] && \
   [ "$INGRESS_CLASS" = "nginx" ]; then
  pass "T6 Ingress creado" 10
else
  fail "T6 Ingress incompleto" 10
fi

echo ""
echo "--- T7 Storage: 10 puntos ---"

PVC_PHASE=$(kubectl get pvc exam-pvc \
  -n cka-storage \
  -o jsonpath='{.status.phase}' 2>/dev/null)

STORAGE_DATA=$(kubectl exec storage-check \
  -n cka-storage -- \
  cat /data/exam.txt 2>/dev/null)

if [ "$PVC_PHASE" = "Bound" ] && \
   [ "$STORAGE_DATA" = "CKA-STORAGE-OK" ]; then
  pass "T7 almacenamiento correcto" 10
else
  fail "T7 almacenamiento incorrecto" 10
fi

echo ""
echo "--- T8 Troubleshooting Pods: 10 puntos ---"

P1=$(kubectl get pod image-failure \
  -n cka-troubleshoot \
  -o jsonpath='{.status.phase}' 2>/dev/null)

P2=$(kubectl get pod crash-failure \
  -n cka-troubleshoot \
  -o jsonpath='{.status.phase}' 2>/dev/null)

if [ "$P1" = "Running" ] && [ "$P2" = "Running" ]; then
  pass "T8 Pods reparados" 10
else
  fail "T8 Pods continúan fallando" 10
fi

echo ""
echo "--- T9 DNS y Service: 10 puntos ---"

DNS_EP=$(kubectl get endpoints dns-backend-svc \
  -n cka-troubleshoot \
  -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

kubectl exec dns-client \
  -n cka-troubleshoot -- \
  nslookup dns-backend-svc >/dev/null 2>&1
DNS_OK=$?

if [ "$DNS_EP" -eq 2 ] && [ "$DNS_OK" -eq 0 ]; then
  pass "T9 DNS y Service correctos" 10
else
  fail "T9 DNS o Service incorrectos" 10
fi

echo ""
echo "--- T10 Incidente integral: 10 puntos ---"

PROD_READY=$(kubectl get deployment production-api \
  -n cka-troubleshoot \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

PROD_EP=$(kubectl get endpoints production-api-svc \
  -n cka-troubleshoot \
  -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

if [ "$PROD_READY" = "3" ] && [ "$PROD_EP" -eq 3 ]; then
  pass "T10 disponibilidad restaurada" 10
else
  fail "T10 incidente no resuelto" 10
fi

echo ""
echo "================================================"
echo "PUNTUACION FINAL: $PASS / $TOTAL"
echo "================================================"

if [ "$PASS" -ge 75 ]; then
  echo "🎓 RESULTADO PEDAGOGICO: APROBADO"
else
  echo "📚 RESULTADO PEDAGOGICO: REQUIERE REPASO"
fi
