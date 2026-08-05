# Solución — Práctica 9: Simulación integral tipo CKA

> Documento de solución posterior a la simulación. Contiene comandos de referencia para resolver y validar las 10 tareas del Lab 15.

---

# Tarea 1 — Mantenimiento de nodo

## Objetivo

Dejar temporalmente `minikube-m02` fuera de scheduling, desalojar workloads administrados y devolver el nodo al servicio con `maintenance-app` en `6/6`.

## Solución

```bash
kubectl get nodes
kubectl get pods -n cka-admin -o wide
```

```bash
kubectl cordon minikube-m02
```

```bash
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data
```

```bash
kubectl get pods -n cka-admin -o wide
kubectl rollout status deployment/maintenance-app \
  -n cka-admin \
  --timeout=120s
```

```bash
kubectl uncordon minikube-m02
```

## Validación

```bash
kubectl get node minikube-m02
kubectl get deployment maintenance-app -n cka-admin
kubectl get pods -n cka-admin -o wide
```

Resultado esperado:

```text
minikube-m02 → Ready
maintenance-app → 6/6 disponibles
ningún Pod de maintenance-app → Pending
```

---

# Tarea 2 — RBAC con mínimo privilegio

## Objetivo

Crear `auditor`, `workload-reader` y `auditor-reader` dentro de `cka-security`.

## Crear ServiceAccount

```bash
kubectl create serviceaccount auditor \
  -n cka-security
```

## Crear Role

```bash
cat > workload-reader.yaml <<'EOF_ROLE'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workload-reader
  namespace: cka-security
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
EOF_ROLE
```

```bash
kubectl apply --dry-run=client -f workload-reader.yaml
kubectl apply -f workload-reader.yaml
```

## Crear RoleBinding

```bash
kubectl create rolebinding auditor-reader \
  --role=workload-reader \
  --serviceaccount=cka-security:auditor \
  -n cka-security
```

## Validar permisos permitidos

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i list pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i watch pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i get configmaps \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i list configmaps \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security
```

Todos deben devolver:

```text
yes
```

## Validar permisos denegados

```bash
kubectl auth can-i create pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i delete pods \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security

kubectl auth can-i get secrets \
  --as=system:serviceaccount:cka-security:auditor \
  -n cka-security
```

Todos deben devolver:

```text
no
```

---

# Tarea 3 — Rolling update y rollback

## Crear Deployment inicial

```bash
kubectl create deployment exam-web \
  --image=nginx:1.27-alpine \
  --replicas=4 \
  -n cka-workloads
```

```bash
kubectl rollout status deployment/exam-web \
  -n cka-workloads \
  --timeout=120s
```

## Actualizar imagen

```bash
kubectl set image deployment/exam-web \
  nginx=nginx:1.28-alpine \
  -n cka-workloads
```

```bash
kubectl rollout status deployment/exam-web \
  -n cka-workloads \
  --timeout=120s
```

```bash
kubectl rollout history deployment/exam-web \
  -n cka-workloads
```

## Realizar rollback

```bash
kubectl rollout undo deployment/exam-web \
  -n cka-workloads
```

```bash
kubectl rollout status deployment/exam-web \
  -n cka-workloads \
  --timeout=120s
```

## Validación

```bash
kubectl get deployment exam-web -n cka-workloads
kubectl get deployment exam-web \
  -n cka-workloads \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl rollout history deployment/exam-web -n cka-workloads
```

Resultado esperado:

```text
4/4 Ready
nginx:1.27-alpine
al menos dos revisiones
```

---

# Tarea 4 — Scheduling con label, taint y toleration

## Configurar nodo

```bash
kubectl label node minikube-m03 \
  workload=analytics \
  --overwrite
```

```bash
kubectl taint node minikube-m03 \
  dedicated=analytics:NoSchedule \
  --overwrite
```

## Crear Deployment

```bash
cat > analytics-app.yaml <<'EOF_ANALYTICS'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-app
  namespace: cka-workloads
spec:
  replicas: 2
  selector:
    matchLabels:
      app: analytics-app
  template:
    metadata:
      labels:
        app: analytics-app
    spec:
      nodeSelector:
        workload: analytics
      tolerations:
        - key: dedicated
          operator: Equal
          value: analytics
          effect: NoSchedule
      containers:
        - name: nginx
          image: nginx:1.27-alpine
EOF_ANALYTICS
```

```bash
kubectl apply --dry-run=client -f analytics-app.yaml
kubectl apply -f analytics-app.yaml
```

```bash
kubectl rollout status deployment/analytics-app \
  -n cka-workloads \
  --timeout=120s
```

## Validación

```bash
kubectl get node minikube-m03 --show-labels
kubectl describe node minikube-m03 | grep -A2 Taints
kubectl get pods \
  -n cka-workloads \
  -l app=analytics-app \
  -o wide
```

Los dos Pods deben ejecutarse en:

```text
minikube-m03
```

---

# Tarea 5 — Reparar Service y exponer mediante NodePort

## Diagnóstico

```bash
kubectl get pods \
  -n cka-network \
  -l app=backend \
  --show-labels
```

```bash
kubectl describe service broken-backend-svc \
  -n cka-network
```

```bash
kubectl get endpoints broken-backend-svc \
  -n cka-network
```

Estado inicial esperado:

```text
Pods:       app=backend
Selector:   app=backend-error
targetPort: 8080
Endpoints:  <none>
```

## Corrección

```bash
kubectl patch service broken-backend-svc \
  -n cka-network \
  --type=merge \
  -p '{
    "spec":{
      "type":"NodePort",
      "selector":{"app":"backend"},
      "ports":[{
        "port":80,
        "targetPort":80,
        "nodePort":30081,
        "protocol":"TCP"
      }]
    }
  }'
```

## Validación

```bash
kubectl get service broken-backend-svc \
  -n cka-network
```

Debe mostrar:

```text
NodePort
80:30081/TCP
```

```bash
kubectl get endpoints broken-backend-svc \
  -n cka-network
```

Debe mostrar dos endpoints en puerto 80.

## Prueba interna

```bash
kubectl run service-test \
  --rm -i \
  --restart=Never \
  --image=busybox:1.36 \
  -n cka-network \
  -- sh -c 'wget -qO- http://broken-backend-svc | head -2'
```

## Prueba desde el host

```bash
minikube service broken-backend-svc \
  -n cka-network \
  --url
```

---

# Tarea 6 — Ingress con enrutamiento por path

## Crear Deployments

```bash
kubectl create deployment portal \
  --image=nginx:1.27-alpine \
  --replicas=2 \
  -n cka-network

kubectl create deployment api \
  --image=nginx:1.27-alpine \
  --replicas=2 \
  -n cka-network
```

```bash
kubectl rollout status deployment/portal \
  -n cka-network \
  --timeout=120s

kubectl rollout status deployment/api \
  -n cka-network \
  --timeout=120s
```

## Crear Services ClusterIP

```bash
kubectl expose deployment portal \
  --name=portal-svc \
  --port=80 \
  --target-port=80 \
  --type=ClusterIP \
  -n cka-network
```

```bash
kubectl expose deployment api \
  --name=api-svc \
  --port=80 \
  --target-port=80 \
  --type=ClusterIP \
  -n cka-network
```

## Crear Ingress

```bash
cat > exam-ingress.yaml <<'EOF_INGRESS'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: exam-ingress
  namespace: cka-network
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: portal-svc
                port:
                  number: 80
EOF_INGRESS
```

```bash
kubectl apply --dry-run=client -f exam-ingress.yaml
kubectl apply -f exam-ingress.yaml
```

## Validar reglas

```bash
kubectl get endpoints \
  -n cka-network \
  portal-svc api-svc
```

```bash
kubectl describe ingress exam-ingress \
  -n cka-network
```

Debe mostrar:

```text
/      → portal-svc:80
/api   → api-svc:80
```

## Prueba funcional

En una segunda terminal:

```bash
kubectl port-forward \
  -n ingress-nginx \
  service/ingress-nginx-controller \
  8080:80
```

En la terminal principal:

```bash
curl -s http://127.0.0.1:8080/ | head
curl -s http://127.0.0.1:8080/api | head
```

Ambas rutas deben devolver contenido NGINX.

---

# Tarea 7 — PersistentVolume y PersistentVolumeClaim

## Preparar directorio en minikube

```bash
minikube ssh -- \
  "sudo mkdir -p /mnt/data/cka-exam && sudo chmod 777 /mnt/data/cka-exam"
```

```bash
minikube ssh -- \
  "ls -ld /mnt/data/cka-exam"
```

## Crear PV

```bash
cat > exam-pv.yaml <<'EOF_PV'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: exam-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /mnt/data/cka-exam
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - minikube
EOF_PV
```

```bash
kubectl apply -f exam-pv.yaml
```

## Crear PVC

```bash
cat > exam-pvc.yaml <<'EOF_PVC'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: exam-pvc
  namespace: cka-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: ""
  volumeName: exam-pv
EOF_PVC
```

```bash
kubectl apply -f exam-pvc.yaml
```

```bash
kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/exam-pvc \
  -n cka-storage \
  --timeout=60s
```

## Crear Pod consumidor

```bash
cat > storage-check.yaml <<'EOF_STORAGE'
apiVersion: v1
kind: Pod
metadata:
  name: storage-check
  namespace: cka-storage
spec:
  containers:
    - name: tools
      image: busybox:1.36
      command: ["sh", "-c", "sleep 7200"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: exam-pvc
EOF_STORAGE
```

```bash
kubectl apply -f storage-check.yaml
```

```bash
kubectl wait \
  --for=condition=Ready \
  pod/storage-check \
  -n cka-storage \
  --timeout=90s
```

## Crear archivo requerido

```bash
kubectl exec storage-check \
  -n cka-storage -- \
  sh -c 'printf "CKA-STORAGE-OK\n" > /data/exam.txt'
```

## Validar

```bash
kubectl get pv exam-pv
kubectl get pvc exam-pvc -n cka-storage
kubectl get pod storage-check -n cka-storage -o wide
```

```bash
kubectl exec storage-check \
  -n cka-storage -- \
  sh -c 'cat /data/exam.txt'
```

Resultado exacto:

```text
CKA-STORAGE-OK
```

El Pod debe estar programado en `minikube`.

---

# Tarea 8 — Troubleshooting de Pods

## 8.1 Reparar image-failure

### Diagnóstico

```bash
kubectl get pod image-failure -n cka-troubleshoot
kubectl describe pod image-failure -n cka-troubleshoot
kubectl get pod image-failure \
  -n cka-troubleshoot \
  -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Resultado inicial:

```text
nginx:tag-does-not-exist-cka
```

### Corrección

```bash
kubectl delete pod image-failure \
  -n cka-troubleshoot
```

```bash
kubectl run image-failure \
  --image=nginx:1.27-alpine \
  -n cka-troubleshoot
```

```bash
kubectl wait \
  --for=condition=Ready \
  pod/image-failure \
  -n cka-troubleshoot \
  --timeout=90s
```

## 8.2 Reparar crash-failure

### Diagnóstico

```bash
kubectl describe pod crash-failure \
  -n cka-troubleshoot
```

```bash
kubectl logs crash-failure \
  -n cka-troubleshoot \
  --previous
```

```bash
kubectl get pod crash-failure \
  -n cka-troubleshoot \
  -o jsonpath='{.spec.containers[0].command}{"\n"}'
```

La causa es:

```text
exit 17
```

### Corrección

```bash
kubectl delete pod crash-failure \
  -n cka-troubleshoot
```

```bash
kubectl run crash-failure \
  --image=nginx:1.27-alpine \
  -n cka-troubleshoot
```

```bash
kubectl wait \
  --for=condition=Ready \
  pod/crash-failure \
  -n cka-troubleshoot \
  --timeout=90s
```

## Validación

```bash
kubectl get pods \
  image-failure crash-failure \
  -n cka-troubleshoot
```

Ambos deben aparecer `1/1 Running`.

---

# Tarea 9 — Service y DNS

## Diagnosticar Service

```bash
kubectl get pods \
  -n cka-troubleshoot \
  -l app=dns-backend \
  --show-labels
```

```bash
kubectl describe service dns-backend-svc \
  -n cka-troubleshoot
```

```bash
kubectl get endpoints dns-backend-svc \
  -n cka-troubleshoot
```

Estado inicial:

```text
Pods:     app=dns-backend
Service:  app=dns-wrong
Endpoints: <none>
```

## Corregir selector

```bash
kubectl patch service dns-backend-svc \
  -n cka-troubleshoot \
  --type=merge \
  -p '{"spec":{"selector":{"app":"dns-backend"}}}'
```

## Validar endpoints

```bash
kubectl get endpoints dns-backend-svc \
  -n cka-troubleshoot
```

Debe mostrar dos endpoints en puerto 80.

## Diagnosticar dns-client

```bash
kubectl get pod dns-client \
  -n cka-troubleshoot \
  -o jsonpath='{.spec.dnsPolicy}{"\n"}'
```

Resultado:

```text
None
```

```bash
kubectl get pod dns-client \
  -n cka-troubleshoot \
  -o jsonpath='{.spec.dnsConfig}{"\n"}'
```

Resultado aproximado:

```text
{"nameservers":["1.2.3.4"]}
```

```bash
kubectl exec dns-client \
  -n cka-troubleshoot -- \
  sh -c 'cat /etc/resolv.conf'
```

## Recrear con ClusterFirst

```bash
kubectl delete pod dns-client \
  -n cka-troubleshoot
```

```bash
cat > dns-client-fixed.yaml <<'EOF_DNS'
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
  namespace: cka-troubleshoot
spec:
  dnsPolicy: ClusterFirst
  containers:
    - name: tools
      image: busybox:1.36
      command: ["sh", "-c", "sleep 7200"]
EOF_DNS
```

```bash
kubectl apply -f dns-client-fixed.yaml
```

```bash
kubectl wait \
  --for=condition=Ready \
  pod/dns-client \
  -n cka-troubleshoot \
  --timeout=60s
```

## Validar FQDN

```bash
kubectl exec dns-client \
  -n cka-troubleshoot -- \
  nslookup dns-backend-svc.cka-troubleshoot.svc.cluster.local
```

Debe devolver la ClusterIP del Service.

## Validar nombre corto funcionalmente

```bash
kubectl exec dns-client \
  -n cka-troubleshoot -- \
  sh -c 'wget -qO- http://dns-backend-svc | head -2'
```

Debe devolver contenido NGINX.

## Comprobar nombre corto con nslookup

```bash
kubectl exec dns-client \
  -n cka-troubleshoot -- \
  nslookup dns-backend-svc
```

Debe aparecer una resolución para:

```text
dns-backend-svc.cka-troubleshoot.svc.cluster.local
```

> BusyBox puede realizar intentos adicionales asociados con los search domains y mostrar `NXDOMAIN` aunque haya resuelto correctamente el nombre esperado. Para una validación determinista utiliza el FQDN y confirma el nombre corto mediante HTTP.

---

# Tarea 10 — Incidente integral de disponibilidad

## Diagnóstico inicial

```bash
kubectl get deployment production-api \
  -n cka-troubleshoot
```

```bash
kubectl get pods \
  -n cka-troubleshoot \
  -l app=production-api
```

Los Pods pueden aparecer `Running` pero `0/1 Ready`.

```bash
kubectl get endpoints production-api-svc \
  -n cka-troubleshoot
```

## Revisar Events

```bash
PROD_POD=$(kubectl get pod \
  -n cka-troubleshoot \
  -l app=production-api \
  -o jsonpath='{.items[0].metadata.name}')

kubectl describe pod "$PROD_POD" \
  -n cka-troubleshoot
```

Evidencia esperada:

```text
Readiness probe failed: HTTP probe failed with statuscode: 404
```

## Consultar readiness probe

```bash
kubectl get deployment production-api \
  -n cka-troubleshoot \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
```

Resultado:

```text
/ready-does-not-exist
```

## Corrección

```bash
kubectl patch deployment production-api \
  -n cka-troubleshoot \
  --type='json' \
  -p='[
    {
      "op":"replace",
      "path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path",
      "value":"/"
    }
  ]'
```

## Esperar rollout

```bash
kubectl rollout status deployment/production-api \
  -n cka-troubleshoot \
  --timeout=120s
```

## Validar 3/3 Ready

```bash
kubectl get deployment production-api \
  -n cka-troubleshoot
```

Debe mostrar:

```text
3/3
```

## Validar tres endpoints

```bash
kubectl get endpoints production-api-svc \
  -n cka-troubleshoot
```

Debe mostrar tres direcciones en puerto 80.

## Validación HTTP

```bash
kubectl run production-test \
  --rm -i \
  --restart=Never \
  --image=busybox:1.36 \
  -n cka-troubleshoot \
  -- sh -c 'wget -qO- -T 5 http://production-api-svc | head -2'
```

Debe devolver contenido NGINX.

---

# Resumen de soluciones

| Tarea | Solución principal |
|---|---|
| T1 | `cordon` → `drain --ignore-daemonsets` → verificar reprogramación → `uncordon` |
| T2 | ServiceAccount + Role namespaced + RoleBinding con mínimo privilegio |
| T3 | Deployment de 4 réplicas → `set image` → rollout → `rollout undo` |
| T4 | Label + taint + `nodeSelector` + toleration |
| T5 | Corregir selector y `targetPort`; convertir a NodePort `30081` |
| T6 | Dos Deployments + dos ClusterIP + Ingress nginx con rewrite para `/api` |
| T7 | PV `hostPath` con nodeAffinity + PVC estático + Pod consumidor |
| T8 | Recrear ambos Pods con `nginx:1.27-alpine` conservando sus nombres |
| T9 | Corregir selector de Service y recrear `dns-client` con `ClusterFirst` |
| T10 | Corregir readiness probe de `/ready-does-not-exist` a `/` |

---

# Nota para Git Bash

Para rutas Linux dentro de contenedores utiliza `sh -c`.

Correcto:

```bash
kubectl exec storage-check \
  -n cka-storage -- \
  sh -c 'cat /data/exam.txt'
```

Esto evita que Git Bash/MSYS2 transforme rutas como `/data/exam.txt` o `/etc/resolv.conf` en rutas de Windows.
