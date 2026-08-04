# Solución puntual — Práctica complementaria 1.1

## 1. Confirmar que la aplicación está sana

```bash
kubectl get deployment node-web-deployment
kubectl get pods -l app=node-web

kubectl exec deployment/node-web-deployment -- \
  wget -qO- http://localhost:3000/health
```

Si `/health` responde, el problema no está en la aplicación.

## 2. Revisar el Service

```bash
kubectl get service node-web-service
kubectl get endpoints node-web-service

kubectl get service node-web-service \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get pods -l app=node-web --show-labels
```

### Causa raíz

El Service utiliza:

```text
app=node-web-v2
```

pero los Pods utilizan:

```text
app=node-web
```

Por eso el Service queda sin endpoints.

## 3. Corregir el selector

```bash
kubectl patch service node-web-service \
  --type=merge \
  -p '{"spec":{"selector":{"app":"node-web"}}}'
```

## 4. Validar

```bash
kubectl get endpoints node-web-service

kubectl exec deployment/node-web-deployment -- \
  wget -qO- http://node-web-service/health
```

Resultado final:

```text
✓ Deployment disponible
✓ Pods Running
✓ selector app=node-web
✓ endpoints restaurados
✓ acceso mediante Service recuperado
```
