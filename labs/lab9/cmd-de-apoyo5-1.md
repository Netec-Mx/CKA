# Solución puntual — Práctica complementaria 5.1

## 1. Confirmar el fallo

```bash
kubectl auth can-i get services \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5

kubectl auth can-i list services \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5
```

Resultado inicial:

```text
no
no
```

---

## 2. Revisar el Role

```bash
kubectl describe role pod-configmap-reader \
  -n lab5
```

El Role contiene lectura de Pods, logs y ConfigMaps, pero no de Services.

### Causa raíz

`app-reader` está correctamente vinculada al Role, pero `pod-configmap-reader` no contiene una regla para el recurso `services`.

---

## 3. Corregir lab9-rbac-scenario.yaml

Agregar:

```yaml
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
```

El Role final debe quedar:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-configmap-reader
  namespace: lab5
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]

  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]

  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
```

---

## 4. Aplicar

```bash
kubectl apply \
  --dry-run=client \
  -f lab9-rbac-scenario.yaml

kubectl apply -f lab9-rbac-scenario.yaml
```

Resultado:

```text
role.rbac.authorization.k8s.io/pod-configmap-reader configured
```

---

## 5. Validar lectura de Services

```bash
for verb in get list watch; do
  kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
done
```

Resultado:

```text
yes
yes
yes
```

---

## 6. Confirmar mínimo privilegio

```bash
for verb in create update delete; do
  kubectl auth can-i "$verb" services \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
done
```

Resultado:

```text
no
no
no
```

```bash
kubectl auth can-i get secrets \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5

kubectl auth can-i create pods \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=lab5

kubectl auth can-i get pods \
  --as=system:serviceaccount:lab5:app-reader \
  --namespace=kube-system
```

Resultado:

```text
no
no
no
```

---

## 7. Validar desde el Pod real

```bash
kubectl get pod rbac-demo-pod \
  -n lab5 \
  -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

Resultado:

```text
app-reader
```

```bash
kubectl exec rbac-demo-pod \
  -n lab5 -- \
  kubectl get services -n lab5
```

La operación debe completarse sin `Forbidden`.

Comprueba que Secrets continúan protegidos:

```bash
kubectl exec rbac-demo-pod \
  -n lab5 -- \
  sh -c 'kubectl get secrets -n lab5 || true'
```

Resultado esperado aproximado:

```text
Error from server (Forbidden): secrets is forbidden ...
```

---

## Resultado final

```text
✓ autorización faltante identificada
✓ lectura de Services agregada
✓ get/list/watch services permitidos
✓ escritura de Services denegada
✓ Secrets continúan protegidos
✓ alcance limitado a lab5
✓ validación realizada desde app-reader real
```
