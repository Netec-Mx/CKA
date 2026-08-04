# Solución puntual — Práctica complementaria 2.1

## 1. Identificar el Pod anómalo

```bash
kubectl get pods -l app=webapp
kubectl get pods --show-labels
```

Debe existir un Pod que sigue `Running` pero utiliza:

```text
app=webapp-debug
```

## 2. Confirmar la causa

```bash
kubectl get deployment webapp \
  -o jsonpath='{.spec.selector.matchLabels}{"\n"}'

kubectl get replicasets \
  -l app=webapp \
  --show-labels

kubectl get pods \
  -o custom-columns=NAME:.metadata.name,APP:.metadata.labels.app,OWNER:.metadata.ownerReferences[0].name
```

### Causa raíz

El Pod dejó de coincidir con el selector:

```text
app=webapp
```

Aunque continúa `Running`, el ReplicaSet deja de contarlo y crea otro Pod para mantener el número deseado de réplicas.

## 3. Localizar y eliminar solo el Pod aislado

```bash
POD_AISLADO=$(kubectl get pods \
  -l app=webapp-debug \
  -o jsonpath='{.items[0].metadata.name}')

echo "$POD_AISLADO"

kubectl delete pod "$POD_AISLADO"
```

## 4. Validar

```bash
kubectl get pods \
  -l app=webapp \
  --show-labels

kubectl get replicasets \
  -l app=webapp

kubectl rollout status deployment/webapp
```

Resultado final:

```text
✓ Pod anómalo identificado
✓ causa relacionada con labels/selectors comprendida
✓ réplica de reemplazo explicada
✓ Pod aislado eliminado
✓ Deployment estable
✓ ReplicaSets históricos conservados
```
