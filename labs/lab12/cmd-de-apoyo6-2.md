# Solución puntual — Práctica complementaria 6.2

## 1. Confirmar que CoreDNS y backend-svc están bien

```bash
kubectl get service backend-svc -n lab6
kubectl get endpoints backend-svc -n lab6

kubectl get pods \
  -n kube-system \
  -l k8s-app=kube-dns
```

El Service debe tener endpoints y CoreDNS debe estar `Running`.

## 2. Reproducir el fallo

```bash
kubectl exec -n lab6 dns-client -- \
  nslookup backend-svc
```

La consulta falla.

## 3. Identificar la causa

```bash
kubectl exec -n lab6 dns-client -- \
  sh -c 'cat /etc/resolv.conf'
```

```bash
kubectl get pod dns-client \
  -n lab6 \
  -o jsonpath='{.spec.dnsPolicy}{"\n"}'

kubectl get pod dns-client \
  -n lab6 \
  -o jsonpath='{.spec.dnsConfig}{"\n"}'
```

Causa raíz:

```text
dnsPolicy: None
nameserver: 1.2.3.4
```

El Pod está reemplazando la configuración DNS normal de Kubernetes.

## 4. Corregir dns-internal-scenario.yaml

Eliminar `dnsConfig` y dejar:

```yaml
spec:
  dnsPolicy: ClusterFirst
```

El manifiesto corregido puede quedar:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
  namespace: lab6
  labels:
    app: dns-client
spec:
  dnsPolicy: ClusterFirst
  containers:
    - name: client
      image: busybox:1.36
      command:
        - sh
        - -c
        - sleep 3600
  restartPolicy: Never
```

## 5. Recrear

```bash
kubectl delete pod dns-client -n lab6
kubectl apply -f dns-internal-scenario.yaml

kubectl wait \
  --for=condition=Ready \
  pod/dns-client \
  -n lab6 \
  --timeout=60s
```

## 6. Validar

```bash
kubectl exec -n lab6 dns-client -- \
  nslookup backend-svc.lab6.svc.cluster.local
```

Debe devolver la ClusterIP de `backend-svc`.

```bash
kubectl exec -n lab6 dns-client -- \
  sh -c 'wget -qO- http://backend-svc | grep "BACKEND API"'
```

Debe aparecer `BACKEND API`.

## 7. Limpiar

```bash
kubectl delete pod dns-client -n lab6
```

## Resultado

```text
✓ CoreDNS descartado como causa
✓ dnsPolicy incorrecta identificada
✓ configuración personalizada retirada
✓ ClusterFirst restaurado
✓ nombre corto y FQDN resuelven
✓ conectividad HTTP validada
```
