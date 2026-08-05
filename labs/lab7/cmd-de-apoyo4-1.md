# Solución puntual — Práctica complementaria 4.1

## 1. Comparar las ClusterIP

```bash
kubectl get service webapp-svc \
  -n development \
  -o jsonpath='{.spec.clusterIP}{"\n"}'

kubectl get service webapp-svc \
  -n production \
  -o jsonpath='{.spec.clusterIP}{"\n"}'
```

Ambos Services deben tener direcciones diferentes.

---

## 2. Consultar el destino del cliente

```bash
kubectl get pod environment-client \
  -n development \
  -o jsonpath='{.spec.containers[0].env[?(@.name=="TARGET_SERVICE")].value}{"\n"}'
```

Resultado:

```text
webapp-svc
```

Resolver:

```bash
kubectl exec environment-client \
  -n development -- \
  nslookup webapp-svc
```

La dirección obtenida corresponde a `webapp-svc` del namespace `development`.

---

## 3. Confirmar la causa

```bash
kubectl exec environment-client \
  -n development -- \
  cat /etc/resolv.conf
```

El Pod utiliza un dominio de búsqueda similar a:

```text
development.svc.cluster.local
svc.cluster.local
cluster.local
```

Por eso el nombre corto:

```text
webapp-svc
```

se resuelve en el contexto de `development`.

### Causa raíz

El cliente debía acceder al Service de `production`, pero `TARGET_SERVICE` contiene únicamente el nombre corto y no especifica el namespace remoto.

---

## 4. Corregir dns-client4-1.yaml

Cambiar:

```yaml
- name: TARGET_SERVICE
  value: webapp-svc
```

por:

```yaml
- name: TARGET_SERVICE
  value: webapp-svc.production.svc.cluster.local
```

---

## 5. Recrear únicamente el cliente

```bash
kubectl delete pod environment-client \
  -n development

kubectl apply -f dns-client4-1.yaml

kubectl wait \
  --for=condition=Ready \
  pod/environment-client \
  -n development \
  --timeout=60s
```

---

## 6. Validar DNS

```bash
kubectl exec environment-client \
  -n development -- \
  sh -c 'nslookup "$TARGET_SERVICE"'
```

La dirección debe coincidir con la ClusterIP de:

```text
webapp-svc / production
```

---

## 7. Validar conectividad HTTP

```bash
kubectl exec environment-client \
  -n development -- \
  sh -c 'wget -qO- "http://$TARGET_SERVICE" | head -5'
```

La aplicación de `production` debe responder.

---

## 8. Limpiar el recurso temporal

```bash
kubectl delete pod environment-client \
  -n development
```

---

## Resultado final

```text
✓ Service local identificado correctamente.
✓ Causa relacionada con nombre corto y namespace comprendida.
✓ FQDN de production configurado en TARGET_SERVICE.
✓ Resolución DNS hacia production validada.
✓ Conectividad HTTP confirmada.
✓ Deployments y Services originales sin modificaciones.
✓ Pod temporal eliminado.
```
