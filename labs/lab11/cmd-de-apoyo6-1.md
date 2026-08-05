# Solución puntual — Práctica complementaria 6.1

## 1. Confirmar que backend está sano

```bash
kubectl get pods -n lab6 -l app=backend
```

Los dos Pods deben estar `Running`.

```bash
BACKEND_POD=$(kubectl get pod \
  -n lab6 \
  -l app=backend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n lab6 "$BACKEND_POD" -- \
  sh -c 'wget -qO- http://127.0.0.1/'
```

Debe aparecer `BACKEND API`.

## 2. Identificar la causa

```bash
kubectl get endpoints backend-svc -n lab6
```

Resultado:

```text
backend-svc   <none>
```

```bash
kubectl get service backend-svc \
  -n lab6 \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get pods \
  -n lab6 \
  -l app=backend \
  --show-labels
```

Causa raíz:

```text
Service: app=backend-api
Pods:    app=backend
```

El selector no coincide con los labels.

## 3. Corregir

```bash
kubectl patch service backend-svc \
  -n lab6 \
  --type=merge \
  -p '{"spec":{"selector":{"app":"backend"}}}'
```

## 4. Validar

```bash
kubectl get endpoints backend-svc -n lab6
```

Debe mostrar dos IPs en puerto 80.

```bash
FRONTEND_POD=$(kubectl get pod \
  -n lab6 \
  -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n lab6 "$FRONTEND_POD" -- \
  sh -c 'wget -qO- http://backend-svc'
```

Debe aparecer:

```text
BACKEND API
```

## Resultado

```text
✓ Pods backend saludables
✓ selector incorrecto identificado
✓ endpoints restaurados
✓ ClusterIP conservada
✓ conectividad frontend → backend recuperada
```
