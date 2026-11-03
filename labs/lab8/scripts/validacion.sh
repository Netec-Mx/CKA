#!/usr/bin/env bash

echo "=== Verificacion final de la Practica 5 ==="

# 1. Verificar Recursos Básicos (ConfigMap, Secret, SA, RBAC)
# Nota: Si tus recursos están en un namespace específico (ej. lab5), puedes agregar '-n lab5' aquí.
kubectl get configmap app-config >/dev/null 2>&1 \
  && echo "✅ ConfigMap app-config disponible" \
  || echo "❌ ConfigMap app-config no encontrado"

  kubectl get secret db-credentials >/dev/null 2>&1 \
  && echo "✅ Secret db-credentials disponible" \
  || echo "❌ Secret db-credentials no encontrado"

  kubectl get serviceaccount app-reader >/dev/null 2>&1 \
  && echo "✅ ServiceAccount app-reader disponible" \
  || echo "❌ ServiceAccount no encontrada"

  kubectl get role pod-configmap-reader >/dev/null 2>&1 \
  && echo "✅ Role disponible" \
  || echo "❌ Role no encontrado"

  kubectl get rolebinding app-reader-binding >/dev/null 2>&1 \
  && echo "✅ RoleBinding disponible" \
  || echo "❌ RoleBinding no encontrado"

# 2. Verificar Permisos (RBAC Auth Can-i) con limpieza de texto para Git Bash
CAN_GET_PODS=$(kubectl auth can-i get pods --as=system:serviceaccount:lab5:app-reader --namespace=lab5 2>/dev/null | tr -d '[:space:]')
CAN_GET_SECRETS=$(kubectl auth can-i get secrets --as=system:serviceaccount:lab5:app-reader --namespace=lab5 2>/dev/null | tr -d '[:space:]')

if [ "$CAN_GET_PODS" = "yes" ]; then
  echo "✅ app-reader puede leer Pods"
else
  echo "❌ app-reader no puede leer Pods"
fi

if [ "$CAN_GET_SECRETS" = "no" ]; then
  echo "✅ app-reader no puede leer Secrets"
else
  echo "❌ app-reader tiene acceso inesperado a Secrets"
fi

# 3. Verificar ServiceAccount asignada al Pod
SA=$(kubectl get pod rbac-demo-pod -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null | tr -d '[:space:]')

if [ "$SA" = "app-reader" ]; then
  echo "✅ rbac-demo-pod usa app-reader"
else
  echo "❌ ServiceAccount inesperada u objeto no encontrado: ${SA:-Ninguna}"
fi

echo "=== Fin de verificacion ==="
