# Práctica 9 — Resolución de Escenarios Integrales Tipo CKA

## Metadatos

| Campo            | Detalle                                      |
|------------------|----------------------------------------------|
| **Duración**     | 134 minutos                                  |
| **Complejidad**  | Alta (Hard)                                  |
| **Nivel Bloom**  | Crear (Create)                               |
| **Módulo**       | 9 — Simulación de Examen CKA                 |
| **Lab ID**       | 09-00-01                                     |

---

## Descripción General

Este laboratorio simula las condiciones reales del examen CKA: 10 tareas independientes con criterios de aceptación explícitos, distribuidas en múltiples namespaces que representan contextos de clúster distintos, con un límite de tiempo estricto de **134 minutos**. Las tareas cubren redes (Services, NetworkPolicy), almacenamiento (PV/PVC), troubleshooting (CrashLoopBackOff, DNS, escalado), y configuración avanzada (ConfigMaps, Secrets TLS). El objetivo no es solo resolver cada tarea, sino hacerlo con la velocidad, precisión y metodología de verificación que exige el examen real.

---

## Objetivos de Aprendizaje

- [ ] Ejecutar tareas técnicas complejas de Kubernetes bajo restricciones de tiempo, aplicando el flujo: **cambiar contexto → generar YAML → revisar → aplicar → verificar**.
- [ ] Demostrar dominio integrado de Pods, Deployments, Services, PVCs, ConfigMaps, Secrets y RBAC en escenarios multi-componente.
- [ ] Aplicar el patrón `--dry-run=client -o yaml` y aliases de `kubectl` para generar manifiestos correctos en segundos.
- [ ] Diagnosticar y resolver fallos en Services, DNS y Pods aplicando metodología sistemática de troubleshooting.
- [ ] Validar cada recurso desplegado con `kubectl get`, `kubectl describe` y `kubectl exec` antes de avanzar a la siguiente tarea.

---

## Prerrequisitos

### Conocimiento Previo

- Completar Labs 06-00-02, 06-00-03, 07-00-01 y 08-00-01 del curso.
- Dominio de creación de recursos Kubernetes mediante YAML y comandos imperativos.
- Conocimiento de RBAC: ServiceAccounts, Roles, RoleBindings.
- Comprensión de ConfigMaps y Secrets (envFrom, volumeMount).
- Capacidad de cambiar entre contextos con `kubectl config use-context`.

### Acceso Requerido

- Clúster Minikube multi-nodo activo (mínimo 3 nodos).
- Terminal con `kubectl` configurado y acceso de administrador al clúster.
- Editor de texto disponible (`vim`, `nano` o VS Code).

---

## Entorno del Laboratorio

### Requisitos de Hardware y Software

| Recurso       | Mínimo              | Recomendado          |
|---------------|---------------------|----------------------|
| CPU           | 4 núcleos físicos   | 8 núcleos            |
| RAM           | 8 GB                | 16 GB                |
| Almacenamiento| 40 GB libres (SSD)  | 60 GB libres (SSD)   |
| SO Host       | Ubuntu 20.04/22.04  | Ubuntu 22.04 LTS     |

| Software         | Versión Mínima |
|------------------|----------------|
| kubectl          | 1.28.x         |
| Minikube         | 1.31.x         |
| Docker Engine    | 24.x           |
| curl             | 7.x            |
| jq               | 1.6            |

### Preparación del Entorno

Ejecuta los siguientes comandos **antes de iniciar el cronómetro**. Esta preparación no cuenta como parte del tiempo del examen.

```bash
# 1. Verificar que el clúster multi-nodo esté activo
minikube status

# Si el clúster no está activo, iniciarlo con 3 nodos
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# 2. Verificar nodos disponibles
kubectl get nodes

# 3. Configurar alias y autocompletado (OBLIGATORIO antes de iniciar)
echo 'alias k=kubectl' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

# 4. Verificar alias
k version --short 2>/dev/null || k version

# 5. Pre-descargar imágenes necesarias (evitar delays durante el lab)
docker pull nginx:1.25
docker pull nginx:1.26
docker pull busybox:latest
minikube image load nginx:1.25
minikube image load nginx:1.26
minikube image load busybox:latest

# 6. Crear los namespaces base del laboratorio
kubectl create namespace cka-red
kubectl create namespace cka-storage
kubectl create namespace cka-troubleshoot
kubectl create namespace cka-advanced
kubectl create namespace cka-dns

# 7. Verificar namespaces creados
kubectl get namespaces | grep cka
```

**Salida esperada de `kubectl get nodes`:**
```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

> ⚠️ **Nota para macOS/Windows con WSL2:** Al usar el driver Docker, el acceso a NodePort requiere `minikube service <nombre> --url` en lugar de la IP directa del nodo.

---

## Hoja de Referencia Rápida (Cheat Sheet)

> Consulta esta sección durante el lab. En el examen CKA real, la documentación oficial está disponible en `kubernetes.io/docs`.

```bash
# ── ALIAS Y CONTEXTO ──────────────────────────────────────────────
alias k=kubectl
k config use-context <contexto>
k config current-context
k config set-context --current --namespace=<ns>

# ── GENERACIÓN RÁPIDA DE YAML ─────────────────────────────────────
k run <pod> --image=<img> --restart=Never --dry-run=client -o yaml
k create deployment <dep> --image=<img> --replicas=3 --dry-run=client -o yaml
k expose deployment <dep> --port=<p> --target-port=<tp> --type=NodePort --dry-run=client -o yaml
k create configmap <cm> --from-literal=key=val --dry-run=client -o yaml
k create secret generic <sec> --from-literal=key=val --dry-run=client -o yaml
k create serviceaccount <sa> --dry-run=client -o yaml
k create role <rol> --verb=get,list,watch --resource=pods --dry-run=client -o yaml
k create rolebinding <rb> --role=<rol> --serviceaccount=<ns>:<sa> --dry-run=client -o yaml

# ── VERIFICACIÓN RÁPIDA ───────────────────────────────────────────
k get all -n <ns>
k describe pod <pod> -n <ns>
k logs <pod> -n <ns>
k exec -it <pod> -n <ns> -- /bin/sh
k get events -n <ns> --sort-by='.lastTimestamp'

# ── TROUBLESHOOTING ───────────────────────────────────────────────
k get endpoints <svc> -n <ns>
k get pvc -n <ns>
k get pv
k rollout status deployment/<dep> -n <ns>
k scale deployment <dep> --replicas=<n> -n <ns>
k auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>
```

---

## Instrucciones del Laboratorio

> ⏱️ **INICIA EL CRONÓMETRO AHORA. Tiempo total: 134 minutos.**
>
> **Estrategia recomendada:**
> 1. Lee los enunciados de las 10 tareas (5 min).
> 2. Resuelve primero T1, T4, T6, T9 (tareas de mayor claridad y peso).
> 3. Marca y salta cualquier tarea que te bloquee más de 4 minutos.
> 4. Regresa a las tareas pendientes con el tiempo sobrante.
> 5. Verifica SIEMPRE antes de avanzar.

---

### Tarea T1 — Red: Deployment con Service NodePort

**Objetivo:** Crear un Deployment con 3 réplicas y exponerlo mediante un Service NodePort en el puerto 30080, validando accesibilidad externa.

**Namespace:** `cka-red` | **Tiempo estimado:** 12 minutos

#### Instrucciones

1. Cambia al namespace de trabajo:

```bash
kubectl config set-context --current --namespace=cka-red
```

2. Crea el Deployment `web-app` con 3 réplicas usando `nginx:1.25`:

```bash
kubectl create deployment web-app \
  --image=nginx:1.25 \
  --replicas=3 \
  --namespace=cka-red \
  --dry-run=client -o yaml > /tmp/t1-deployment.yaml
```

3. Revisa y aplica el manifiesto:

```bash
cat /tmp/t1-deployment.yaml
kubectl apply -f /tmp/t1-deployment.yaml
```

4. Genera el manifiesto del Service NodePort:

```bash
kubectl expose deployment web-app \
  --port=80 \
  --target-port=80 \
  --type=NodePort \
  --name=web-app-svc \
  --namespace=cka-red \
  --dry-run=client -o yaml > /tmp/t1-service.yaml
```

5. Edita `/tmp/t1-service.yaml` para fijar el `nodePort` en **30080**. Abre el archivo y añade `nodePort: 30080` bajo el bloque `ports`:

```yaml
# Sección ports del Service (editar con vim /tmp/t1-service.yaml)
ports:
- port: 80
  protocol: TCP
  targetPort: 80
  nodePort: 30080
```

6. Aplica el Service:

```bash
kubectl apply -f /tmp/t1-service.yaml
```

7. Verifica accesibilidad:

```bash
# Obtener IP del nodo
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')

# Probar acceso HTTP (Linux nativo)
curl -s http://${NODE_IP}:30080 | grep -i "Welcome to nginx"

# En macOS/Windows con driver Docker:
minikube service web-app-svc -n cka-red --url
# Luego usar la URL obtenida con curl
```

**Salida esperada:**
```
deployment.apps/web-app created
service/web-app-svc created
```
```html
<!DOCTYPE html>
...Welcome to nginx!...
```

**Criterios de aceptación T1:**
- [ ] Deployment `web-app` existe en `cka-red` con 3/3 réplicas Ready.
- [ ] Service `web-app-svc` de tipo NodePort existe en `cka-red`.
- [ ] El NodePort es exactamente **30080**.
- [ ] `curl` al NodePort devuelve la página de bienvenida de nginx.

**Verificación:**
```bash
kubectl get deployment web-app -n cka-red
kubectl get service web-app-svc -n cka-red
kubectl get endpoints web-app-svc -n cka-red
```

---

### Tarea T2 — Red: Reparar un Service Roto

**Objetivo:** Diagnosticar y reparar un Service que no enruta tráfico a sus Pods destino.

**Namespace:** `cka-red` | **Tiempo estimado:** 10 minutos

#### Instrucciones

1. Despliega el escenario roto (recursos con fallo intencional):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: cka-red
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: cka-red
spec:
  selector:
    app: backend-wrong   # <-- selector incorrecto (fallo intencional)
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

2. Diagnostica el problema:

```bash
# Verificar que los pods existen y están Running
kubectl get pods -n cka-red -l app=backend

# Verificar endpoints del Service (deben estar vacíos si el selector es incorrecto)
kubectl get endpoints backend-svc -n cka-red

# Inspeccionar el selector del Service
kubectl describe service backend-svc -n cka-red | grep -A5 "Selector"

# Inspeccionar los labels de los pods
kubectl get pods -n cka-red -l app=backend --show-labels
```

3. Identifica el fallo: el selector del Service apunta a `app: backend-wrong` pero los Pods tienen el label `app: backend`.

4. Repara el Service editando el selector:

```bash
kubectl patch service backend-svc -n cka-red \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend"}]'
```

5. Verifica que los endpoints ahora están poblados:

```bash
kubectl get endpoints backend-svc -n cka-red
```

**Salida esperada tras la reparación:**
```
NAME          ENDPOINTS                       AGE
backend-svc   10.244.x.x:80,10.244.x.x:80   Xm
```

**Criterios de aceptación T2:**
- [ ] `kubectl get endpoints backend-svc -n cka-red` muestra al menos 2 endpoints (IPs de los Pods).
- [ ] El selector del Service coincide con los labels de los Pods (`app: backend`).

**Verificación:**
```bash
kubectl describe service backend-svc -n cka-red
kubectl get endpoints backend-svc -n cka-red
```

---

### Tarea T3 — Red: Configurar NetworkPolicy

**Objetivo:** Configurar una NetworkPolicy que restrinja el tráfico entrante a un Pod solo desde Pods con el label `role=frontend`.

**Namespace:** `cka-red` | **Tiempo estimado:** 14 minutos

#### Instrucciones

1. Habilita el addon de CNI con soporte NetworkPolicy en Minikube:

```bash
# Verificar si Calico o Cilium está disponible; en Minikube con driver Docker
# se puede usar el addon de network-policy
minikube addons enable network-policy-enforcement 2>/dev/null || \
  echo "Addon no disponible; la NetworkPolicy se aplica pero puede no ejecutarse en Minikube sin CNI compatible."
```

> **Nota:** En Minikube con driver Docker, las NetworkPolicies se crean correctamente en la API pero su enforcement requiere un CNI compatible (Calico, Cilium). En este lab, el objetivo es demostrar la creación y estructura correcta del recurso.

2. Crea el Pod destino con label `role=api`:

```bash
kubectl run api-server \
  --image=nginx:1.25 \
  --labels="role=api" \
  --namespace=cka-red \
  --restart=Never
```

3. Crea la NetworkPolicy que permite tráfico solo desde `role=frontend`:

```bash
cat <<'EOF' > /tmp/t3-netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-only
  namespace: cka-red
spec:
  podSelector:
    matchLabels:
      role: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

kubectl apply -f /tmp/t3-netpol.yaml
```

4. Verifica la NetworkPolicy:

```bash
kubectl get networkpolicy allow-frontend-only -n cka-red
kubectl describe networkpolicy allow-frontend-only -n cka-red
```

5. (Opcional — si el CNI soporta enforcement) Prueba la restricción:

```bash
# Pod con label correcto (debe poder conectar)
kubectl run test-frontend \
  --image=busybox:latest \
  --labels="role=frontend" \
  --namespace=cka-red \
  --restart=Never \
  --rm -it -- wget -qO- http://$(kubectl get pod api-server -n cka-red -o jsonpath='{.status.podIP}') 2>/dev/null && echo "CONEXIÓN PERMITIDA"

# Pod sin label correcto (debe ser bloqueado con CNI compatible)
kubectl run test-other \
  --image=busybox:latest \
  --labels="role=db" \
  --namespace=cka-red \
  --restart=Never \
  --rm -it -- wget -qO- --timeout=5 http://$(kubectl get pod api-server -n cka-red -o jsonpath='{.status.podIP}') 2>/dev/null || echo "CONEXIÓN BLOQUEADA"
```

**Criterios de aceptación T3:**
- [ ] NetworkPolicy `allow-frontend-only` existe en `cka-red`.
- [ ] `podSelector` apunta a `role=api`.
- [ ] La regla `ingress.from.podSelector` especifica `role=frontend`.
- [ ] `policyTypes` incluye `Ingress`.

**Verificación:**
```bash
kubectl get networkpolicy -n cka-red
kubectl describe networkpolicy allow-frontend-only -n cka-red
```

---

### Tarea T4 — Almacenamiento: PV, PVC y Pod

**Objetivo:** Crear un PersistentVolume (PV) y PersistentVolumeClaim (PVC) con especificaciones exactas, y desplegar un Pod que use el PVC verificando persistencia de datos.

**Namespace:** `cka-storage` | **Tiempo estimado:** 15 minutos

#### Instrucciones

1. Crea el PersistentVolume con `hostPath`:

```bash
cat <<'EOF' > /tmp/t4-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cka-pv-data
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/cka-data
    type: DirectoryOrCreate
EOF

kubectl apply -f /tmp/t4-pv.yaml
```

2. Crea el PersistentVolumeClaim:

```bash
cat <<'EOF' > /tmp/t4-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cka-pvc-data
  namespace: cka-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

kubectl apply -f /tmp/t4-pvc.yaml
```

3. Verifica que el PVC se enlaza al PV:

```bash
kubectl get pvc cka-pvc-data -n cka-storage
kubectl get pv cka-pv-data
```

**Salida esperada:**
```
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   AGE
cka-pvc-data   Bound    cka-pv-data   1Gi        RWO            manual         Xs
```

4. Crea el Pod que monta el PVC y escribe datos:

```bash
cat <<'EOF' > /tmp/t4-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-writer
  namespace: cka-storage
spec:
  containers:
  - name: writer
    image: busybox:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "CKA-LAB-DATA-$(date)" > /data/test.txt
      echo "Datos escritos correctamente"
      sleep 3600
    volumeMounts:
    - name: data-volume
      mountPath: /data
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: cka-pvc-data
  restartPolicy: Never
EOF

kubectl apply -f /tmp/t4-pod.yaml
```

5. Verifica que los datos persisten:

```bash
# Esperar a que el Pod esté Running
kubectl wait pod data-writer -n cka-storage --for=condition=Ready --timeout=60s

# Leer el archivo escrito
kubectl exec data-writer -n cka-storage -- cat /data/test.txt
```

**Salida esperada:**
```
CKA-LAB-DATA-<fecha-actual>
```

**Criterios de aceptación T4:**
- [ ] PV `cka-pv-data` existe con capacidad 1Gi y `storageClassName: manual`.
- [ ] PVC `cka-pvc-data` existe en `cka-storage` con estado `Bound`.
- [ ] Pod `data-writer` está en estado `Running`.
- [ ] `kubectl exec data-writer -n cka-storage -- cat /data/test.txt` devuelve contenido.

**Verificación:**
```bash
kubectl get pv cka-pv-data
kubectl get pvc -n cka-storage
kubectl get pod data-writer -n cka-storage
kubectl exec data-writer -n cka-storage -- cat /data/test.txt
```

---

### Tarea T5 — Almacenamiento: Resolver PVC en Pending

**Objetivo:** Identificar por qué un PVC está en estado `Pending` y resolverlo.

**Namespace:** `cka-storage` | **Tiempo estimado:** 10 minutos

#### Instrucciones

1. Despliega el escenario con PVC roto (fallo intencional en `storageClassName`):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
  namespace: cka-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
  storageClassName: nonexistent-class   # <-- clase inexistente (fallo intencional)
EOF
```

2. Diagnostica el estado del PVC:

```bash
# Verificar estado Pending
kubectl get pvc broken-pvc -n cka-storage

# Obtener detalles del problema
kubectl describe pvc broken-pvc -n cka-storage
```

**Salida esperada del describe:**
```
Events:
  ...no persistent volumes available for this claim and no storage class is set...
  storageclass.storage.k8s.io "nonexistent-class" not found
```

3. Identifica las StorageClasses disponibles:

```bash
kubectl get storageclass
```

4. Resuelve el problema: elimina el PVC roto y recréalo con la StorageClass correcta (`standard` en Minikube o `manual` creada en T4):

```bash
# Eliminar el PVC roto
kubectl delete pvc broken-pvc -n cka-storage

# Crear PV adicional para este PVC
cat <<'EOF' > /tmp/t5-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cka-pv-fixed
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/cka-fixed
    type: DirectoryOrCreate
EOF
kubectl apply -f /tmp/t5-pv.yaml

# Recrear el PVC con storageClassName correcto
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
  namespace: cka-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
  storageClassName: manual
EOF
```

5. Verifica que el PVC ahora está `Bound`:

```bash
kubectl get pvc broken-pvc -n cka-storage
```

**Criterios de aceptación T5:**
- [ ] PVC `broken-pvc` en `cka-storage` está en estado `Bound`.
- [ ] El PVC usa una StorageClass existente en el clúster.

**Verificación:**
```bash
kubectl get pvc -n cka-storage
kubectl get pv
```

---

### Tarea T6 — Troubleshooting: Reparar Pod en CrashLoopBackOff

**Objetivo:** Reparar un Pod en estado `CrashLoopBackOff` modificando su configuración.

**Namespace:** `cka-troubleshoot` | **Tiempo estimado:** 12 minutos

#### Instrucciones

1. Despliega el Pod con fallo intencional:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
  namespace: cka-troubleshoot
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: ["/bin/sh", "-c"]
    args: ["exit 1"]   # <-- comando que falla inmediatamente (fallo intencional)
    ports:
    - containerPort: 80
  restartPolicy: Always
EOF
```

2. Observa el estado del Pod:

```bash
kubectl get pod crash-pod -n cka-troubleshoot
# Esperar ~30 segundos para ver CrashLoopBackOff
kubectl get pod crash-pod -n cka-troubleshoot --watch &
sleep 35 && kill %1 2>/dev/null
```

3. Diagnostica la causa:

```bash
# Ver logs del contenedor fallido
kubectl logs crash-pod -n cka-troubleshoot

# Ver eventos
kubectl describe pod crash-pod -n cka-troubleshoot | tail -20
```

4. Repara el Pod: elimínalo y recréalo con el comando correcto (nginx debe correr en primer plano):

```bash
# Eliminar el Pod roto
kubectl delete pod crash-pod -n cka-troubleshoot

# Recrear con comando correcto
cat <<'EOF' > /tmp/t6-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
  namespace: cka-troubleshoot
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: []
    args: []
    ports:
    - containerPort: 80
  restartPolicy: Always
EOF

kubectl apply -f /tmp/t6-pod.yaml
```

5. Verifica que el Pod está Running:

```bash
kubectl wait pod crash-pod -n cka-troubleshoot --for=condition=Ready --timeout=60s
kubectl get pod crash-pod -n cka-troubleshoot
```

**Criterios de aceptación T6:**
- [ ] Pod `crash-pod` en `cka-troubleshoot` está en estado `Running`.
- [ ] El Pod NO está en `CrashLoopBackOff` ni `Error`.
- [ ] `kubectl logs crash-pod -n cka-troubleshoot` muestra logs normales de nginx.

**Verificación:**
```bash
kubectl get pod crash-pod -n cka-troubleshoot
kubectl logs crash-pod -n cka-troubleshoot | head -5
```

---

### Tarea T7 — Troubleshooting: Resolver Fallo de DNS

**Objetivo:** Resolver un fallo de resolución DNS en el namespace `cka-dns`, verificando que los Pods pueden resolver nombres de Services internos.

**Namespace:** `cka-dns` | **Tiempo estimado:** 14 minutos

#### Instrucciones

1. Despliega un Service y un Pod de prueba en `cka-dns`:

```bash
# Service destino
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dns-target-svc
  namespace: cka-dns
spec:
  selector:
    app: dns-target
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-target
  namespace: cka-dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dns-target
  template:
    metadata:
      labels:
        app: dns-target
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
```

2. Despliega un Pod de diagnóstico DNS:

```bash
kubectl run dns-debug \
  --image=busybox:latest \
  --namespace=cka-dns \
  --restart=Never \
  --command -- sleep 3600
```

3. Espera a que el Pod esté listo:

```bash
kubectl wait pod dns-debug -n cka-dns --for=condition=Ready --timeout=60s
```

4. Diagnostica la resolución DNS desde el Pod:

```bash
# Probar resolución del Service por nombre corto
kubectl exec dns-debug -n cka-dns -- nslookup dns-target-svc

# Probar resolución por FQDN
kubectl exec dns-debug -n cka-dns -- nslookup dns-target-svc.cka-dns.svc.cluster.local

# Verificar que CoreDNS está funcionando
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

5. Si CoreDNS no está funcionando, reinícialo:

```bash
# Verificar estado de CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl describe pods -n kube-system -l k8s-app=kube-dns | grep -A10 "Events"

# Si hay fallos, reiniciar CoreDNS
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=60s
```

6. Simula un fallo de DNS modificando temporalmente el ConfigMap de CoreDNS y luego restaúralo:

```bash
# Ver la configuración actual de CoreDNS
kubectl get configmap coredns -n kube-system -o yaml

# Verificar que la entrada 'kubernetes' está presente en el Corefile
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
```

7. Prueba final de resolución DNS:

```bash
kubectl exec dns-debug -n cka-dns -- nslookup dns-target-svc.cka-dns.svc.cluster.local
kubectl exec dns-debug -n cka-dns -- wget -qO- http://dns-target-svc 2>/dev/null | head -3
```

**Salida esperada:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      dns-target-svc.cka-dns.svc.cluster.local
Address 1: 10.x.x.x dns-target-svc.cka-dns.svc.cluster.local
```

**Criterios de aceptación T7:**
- [ ] `nslookup dns-target-svc` desde `dns-debug` resuelve correctamente.
- [ ] `nslookup dns-target-svc.cka-dns.svc.cluster.local` devuelve una IP.
- [ ] CoreDNS está en estado `Running` en `kube-system`.
- [ ] `wget` al Service desde el Pod de prueba devuelve contenido HTML.

**Verificación:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl exec dns-debug -n cka-dns -- nslookup kubernetes.default
```

---

### Tarea T8 — Troubleshooting: Escalar Deployment y Verificar Tráfico

**Objetivo:** Escalar un Deployment de 1 a 4 réplicas y verificar que los nuevos Pods están `Ready` y recibiendo tráfico.

**Namespace:** `cka-troubleshoot` | **Tiempo estimado:** 10 minutos

#### Instrucciones

1. Crea el Deployment inicial con 1 réplica:

```bash
kubectl create deployment scale-app \
  --image=nginx:1.25 \
  --replicas=1 \
  --namespace=cka-troubleshoot

kubectl expose deployment scale-app \
  --port=80 \
  --target-port=80 \
  --name=scale-app-svc \
  --namespace=cka-troubleshoot
```

2. Verifica el estado inicial:

```bash
kubectl get deployment scale-app -n cka-troubleshoot
kubectl get endpoints scale-app-svc -n cka-troubleshoot
```

3. Escala el Deployment a 4 réplicas:

```bash
kubectl scale deployment scale-app \
  --replicas=4 \
  --namespace=cka-troubleshoot
```

4. Monitorea el rollout:

```bash
kubectl rollout status deployment/scale-app -n cka-troubleshoot --timeout=90s
```

5. Verifica que los 4 Pods están Ready y el Service los incluye:

```bash
kubectl get pods -n cka-troubleshoot -l app=scale-app
kubectl get endpoints scale-app-svc -n cka-troubleshoot
```

6. Verifica que el tráfico llega a todos los Pods (round-robin):

```bash
# Crear Pod de prueba temporal
kubectl run traffic-test \
  --image=busybox:latest \
  --namespace=cka-troubleshoot \
  --restart=Never \
  --rm -it -- /bin/sh -c \
  "for i in \$(seq 1 8); do wget -qO- http://scale-app-svc 2>/dev/null | grep -o 'Welcome to nginx' ; done"
```

**Salida esperada:**
```
deployment.apps/scale-app scaled
Waiting for deployment "scale-app" rollout to finish: 3 of 4 updated replicas are available...
deployment "scale-app" successfully rolled out
```
```
NAME                         READY   STATUS    RESTARTS   AGE
scale-app-xxxxx-aaaaa        1/1     Running   0          Xm
scale-app-xxxxx-bbbbb        1/1     Running   0          Xs
scale-app-xxxxx-ccccc        1/1     Running   0          Xs
scale-app-xxxxx-ddddd        1/1     Running   0          Xs
```

**Criterios de aceptación T8:**
- [ ] Deployment `scale-app` tiene 4/4 réplicas Ready.
- [ ] `kubectl get endpoints scale-app-svc -n cka-troubleshoot` muestra 4 IPs.
- [ ] `kubectl rollout status` reporta "successfully rolled out".

**Verificación:**
```bash
kubectl get deployment scale-app -n cka-troubleshoot
kubectl get endpoints scale-app-svc -n cka-troubleshoot
kubectl rollout history deployment/scale-app -n cka-troubleshoot
```

---

### Tarea T9 — Avanzado: ConfigMap como Variable de Entorno y Volumen

**Objetivo:** Crear un ConfigMap y montarlo tanto como variable de entorno como como archivo en un Pod.

**Namespace:** `cka-advanced` | **Tiempo estimado:** 14 minutos

#### Instrucciones

1. Crea el ConfigMap con múltiples valores:

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080 \
  --from-literal=APP_LOG_LEVEL=info \
  --namespace=cka-advanced \
  --dry-run=client -o yaml > /tmp/t9-configmap.yaml

kubectl apply -f /tmp/t9-configmap.yaml
```

2. Crea también un ConfigMap con contenido de archivo:

```bash
cat <<'EOF' > /tmp/app.properties
environment=production
max_connections=100
timeout_seconds=30
EOF

kubectl create configmap app-file-config \
  --from-file=app.properties=/tmp/app.properties \
  --namespace=cka-advanced
```

3. Crea el Pod que usa el ConfigMap de ambas formas:

```bash
cat <<'EOF' > /tmp/t9-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-consumer
  namespace: cka-advanced
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "=== Variables de Entorno ==="
      echo "APP_ENV=$APP_ENV"
      echo "APP_PORT=$APP_PORT"
      echo "APP_LOG_LEVEL=$APP_LOG_LEVEL"
      echo ""
      echo "=== Archivo montado ==="
      cat /config/app.properties
      sleep 3600
    envFrom:
    - configMapRef:
        name: app-config
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: app-file-config
  restartPolicy: Never
EOF

kubectl apply -f /tmp/t9-pod.yaml
```

4. Espera a que el Pod esté listo y verifica ambas formas de consumo:

```bash
kubectl wait pod config-consumer -n cka-advanced --for=condition=Ready --timeout=60s

# Verificar variables de entorno
kubectl exec config-consumer -n cka-advanced -- env | grep APP_

# Verificar archivo montado
kubectl exec config-consumer -n cka-advanced -- cat /config/app.properties

# Ver logs del Pod (muestra ambas fuentes)
kubectl logs config-consumer -n cka-advanced
```

**Salida esperada:**
```
=== Variables de Entorno ===
APP_ENV=production
APP_PORT=8080
APP_LOG_LEVEL=info

=== Archivo montado ===
environment=production
max_connections=100
timeout_seconds=30
```

**Criterios de aceptación T9:**
- [ ] ConfigMap `app-config` existe en `cka-advanced` con las 3 claves.
- [ ] ConfigMap `app-file-config` existe en `cka-advanced` con el archivo `app.properties`.
- [ ] Pod `config-consumer` está en `Running`.
- [ ] `kubectl exec` muestra las variables `APP_ENV`, `APP_PORT`, `APP_LOG_LEVEL`.
- [ ] `kubectl exec` muestra el contenido del archivo en `/config/app.properties`.

**Verificación:**
```bash
kubectl get configmap -n cka-advanced
kubectl exec config-consumer -n cka-advanced -- env | grep APP_
kubectl exec config-consumer -n cka-advanced -- cat /config/app.properties
```

---

### Tarea T10 — Avanzado: Secret TLS Referenciado en un Pod

**Objetivo:** Crear un Secret TLS y referenciarlo en un Pod como volumen montado.

**Namespace:** `cka-advanced` | **Tiempo estimado:** 13 minutos

#### Instrucciones

1. Genera un certificado TLS autofirmado:

```bash
# Crear directorio de trabajo
mkdir -p /tmp/tls-certs

# Generar clave privada y certificado autofirmado
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /tmp/tls-certs/tls.key \
  -out /tmp/tls-certs/tls.crt \
  -subj "/CN=cka-lab.local/O=CKA-Lab"

# Verificar los archivos generados
ls -la /tmp/tls-certs/
```

2. Crea el Secret TLS en Kubernetes:

```bash
kubectl create secret tls tls-secret \
  --cert=/tmp/tls-certs/tls.crt \
  --key=/tmp/tls-certs/tls.key \
  --namespace=cka-advanced \
  --dry-run=client -o yaml > /tmp/t10-secret.yaml

kubectl apply -f /tmp/t10-secret.yaml
```

3. Verifica el Secret (los datos deben estar en base64):

```bash
kubectl get secret tls-secret -n cka-advanced
kubectl describe secret tls-secret -n cka-advanced
```

**Salida esperada:**
```
Name:         tls-secret
Namespace:    cka-advanced
Type:         kubernetes.io/tls

Data
====
tls.crt:  1234 bytes
tls.key:  1679 bytes
```

4. Crea un Pod que monte el Secret TLS como volumen:

```bash
cat <<'EOF' > /tmp/t10-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tls-consumer
  namespace: cka-advanced
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "=== Certificado TLS montado ==="
      ls -la /tls/
      echo ""
      echo "=== Primeras líneas del certificado ==="
      head -3 /tls/tls.crt
      echo ""
      echo "=== Verificando clave privada ==="
      head -3 /tls/tls.key
      sleep 3600
    volumeMounts:
    - name: tls-volume
      mountPath: /tls
      readOnly: true
  volumes:
  - name: tls-volume
    secret:
      secretName: tls-secret
  restartPolicy: Never
EOF

kubectl apply -f /tmp/t10-pod.yaml
```

5. Verifica que el Pod monta correctamente el Secret:

```bash
kubectl wait pod tls-consumer -n cka-advanced --for=condition=Ready --timeout=60s

# Verificar archivos montados
kubectl exec tls-consumer -n cka-advanced -- ls -la /tls/

# Verificar contenido del certificado
kubectl exec tls-consumer -n cka-advanced -- head -3 /tls/tls.crt

# Ver logs
kubectl logs tls-consumer -n cka-advanced
```

**Salida esperada:**
```
=== Certificado TLS montado ===
-r--r--r--    1 root     root          xxxx tls.crt
-r--r--r--    1 root     root          xxxx tls.key

=== Primeras líneas del certificado ===
-----BEGIN CERTIFICATE-----
MIIDxxx...
```

**Criterios de aceptación T10:**
- [ ] Secret `tls-secret` de tipo `kubernetes.io/tls` existe en `cka-advanced`.
- [ ] Pod `tls-consumer` está en estado `Running`.
- [ ] `kubectl exec tls-consumer -n cka-advanced -- ls /tls/` muestra `tls.crt` y `tls.key`.
- [ ] Los archivos contienen los encabezados PEM correctos (`-----BEGIN CERTIFICATE-----`).

**Verificación:**
```bash
kubectl get secret tls-secret -n cka-advanced -o jsonpath='{.type}'
kubectl exec tls-consumer -n cka-advanced -- ls /tls/
kubectl exec tls-consumer -n cka-advanced -- head -1 /tls/tls.crt
```

---

## Validación Final del Laboratorio

Ejecuta este script de validación integral al finalizar todas las tareas. Cada verificación exitosa suma puntos.

```bash
#!/bin/bash
echo "════════════════════════════════════════════"
echo "  VALIDACIÓN FINAL — LAB 09-00-01"
echo "════════════════════════════════════════════"
PASS=0; FAIL=0

check() {
  local desc="$1"; local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  ✅ PASS: $desc"; ((PASS++))
  else
    echo "  ❌ FAIL: $desc"; ((FAIL++))
  fi
}

echo ""
echo "── T1: Deployment web-app y Service NodePort ──"
check "Deployment web-app con 3 réplicas Ready" \
  "kubectl get deployment web-app -n cka-red -o jsonpath='{.status.readyReplicas}' | grep -q '3'"
check "Service web-app-svc tipo NodePort" \
  "kubectl get svc web-app-svc -n cka-red -o jsonpath='{.spec.type}' | grep -q 'NodePort'"
check "NodePort es 30080" \
  "kubectl get svc web-app-svc -n cka-red -o jsonpath='{.spec.ports[0].nodePort}' | grep -q '30080'"

echo ""
echo "── T2: Service backend-svc reparado ──"
check "Endpoints de backend-svc no vacíos" \
  "kubectl get endpoints backend-svc -n cka-red -o jsonpath='{.subsets}' | grep -q 'addresses'"

echo ""
echo "── T3: NetworkPolicy allow-frontend-only ──"
check "NetworkPolicy existe en cka-red" \
  "kubectl get networkpolicy allow-frontend-only -n cka-red"
check "PolicyType es Ingress" \
  "kubectl get networkpolicy allow-frontend-only -n cka-red -o jsonpath='{.spec.policyTypes[0]}' | grep -q 'Ingress'"

echo ""
echo "── T4: PV, PVC y Pod con datos ──"
check "PV cka-pv-data existe" \
  "kubectl get pv cka-pv-data"
check "PVC cka-pvc-data está Bound" \
  "kubectl get pvc cka-pvc-data -n cka-storage -o jsonpath='{.status.phase}' | grep -q 'Bound'"
check "Pod data-writer está Running" \
  "kubectl get pod data-writer -n cka-storage -o jsonpath='{.status.phase}' | grep -q 'Running'"
check "Datos escritos en el volumen" \
  "kubectl exec data-writer -n cka-storage -- cat /data/test.txt"

echo ""
echo "── T5: PVC broken-pvc reparado ──"
check "PVC broken-pvc está Bound" \
  "kubectl get pvc broken-pvc -n cka-storage -o jsonpath='{.status.phase}' | grep -q 'Bound'"

echo ""
echo "── T6: Pod crash-pod reparado ──"
check "Pod crash-pod está Running" \
  "kubectl get pod crash-pod -n cka-troubleshoot -o jsonpath='{.status.phase}' | grep -q 'Running'"

echo ""
echo "── T7: DNS funcional en cka-dns ──"
check "CoreDNS pods Running" \
  "kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running | grep -q 'Running'"
check "Resolución DNS funcional" \
  "kubectl exec dns-debug -n cka-dns -- nslookup kubernetes.default 2>/dev/null"

echo ""
echo "── T8: Deployment scale-app con 4 réplicas ──"
check "Deployment scale-app tiene 4 réplicas Ready" \
  "kubectl get deployment scale-app -n cka-troubleshoot -o jsonpath='{.status.readyReplicas}' | grep -q '4'"
check "Endpoints scale-app-svc con 4 IPs" \
  "kubectl get endpoints scale-app-svc -n cka-troubleshoot -o jsonpath='{.subsets[0].addresses}' | jq 'length' 2>/dev/null | grep -q '4'"

echo ""
echo "── T9: ConfigMap como envVar y volumen ──"
check "ConfigMap app-config existe" \
  "kubectl get configmap app-config -n cka-advanced"
check "ConfigMap app-file-config existe" \
  "kubectl get configmap app-file-config -n cka-advanced"
check "Pod config-consumer Running" \
  "kubectl get pod config-consumer -n cka-advanced -o jsonpath='{.status.phase}' | grep -q 'Running'"
check "Variable APP_ENV disponible en Pod" \
  "kubectl exec config-consumer -n cka-advanced -- env 2>/dev/null | grep -q 'APP_ENV=production'"
check "Archivo app.properties montado" \
  "kubectl exec config-consumer -n cka-advanced -- cat /config/app.properties 2>/dev/null | grep -q 'environment'"

echo ""
echo "── T10: Secret TLS referenciado en Pod ──"
check "Secret tls-secret tipo TLS" \
  "kubectl get secret tls-secret -n cka-advanced -o jsonpath='{.type}' | grep -q 'kubernetes.io/tls'"
check "Pod tls-consumer Running" \
  "kubectl get pod tls-consumer -n cka-advanced -o jsonpath='{.status.phase}' | grep -q 'Running'"
check "Certificado montado en /tls/" \
  "kubectl exec tls-consumer -n cka-advanced -- ls /tls/ 2>/dev/null | grep -q 'tls.crt'"

echo ""
echo "════════════════════════════════════════════"
echo "  RESULTADO: ${PASS} PASS / ${FAIL} FAIL"
TOTAL=$((PASS + FAIL))
PCT=$((PASS * 100 / TOTAL))
echo "  PUNTUACIÓN ESTIMADA: ${PCT}%"
echo "════════════════════════════════════════════"
[ $PCT -ge 74 ] && echo "  🎓 APROBADO (≥74%)" || echo "  ⚠️  REPASO NECESARIO (<74%)"
```

Guarda el script como `/tmp/validate-lab09.sh`, dale permisos y ejecútalo:

```bash
chmod +x /tmp/validate-lab09.sh
bash /tmp/validate-lab09.sh
```

---

## Troubleshooting

### Problema 1: El PVC permanece en estado `Pending` después de la corrección

**Síntomas:**
```
NAME           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
broken-pvc     Pending                                      manual         5m
```
`kubectl describe pvc broken-pvc -n cka-storage` muestra:
```
Events: no persistent volumes available for this claim and no storage class is set
```

**Causa:** No existe ningún PV disponible que satisfaga los requisitos del PVC (capacidad, accessMode y storageClassName deben coincidir exactamente). Si el PV `cka-pv-fixed` ya fue reclamado por otro PVC, su estado será `Released` pero no `Available`, y Kubernetes no lo reasignará automáticamente con la política `Retain`.

**Solución:**
```bash
# Verificar estado del PV
kubectl get pv

# Si el PV está en estado Released, limpiar el claimRef para liberarlo
kubectl patch pv cka-pv-fixed \
  --type='json' \
  -p='[{"op": "remove", "path": "/spec/claimRef"}]'

# Verificar que el PV vuelve a estado Available
kubectl get pv cka-pv-fixed

# Si persiste el problema, crear un nuevo PV con nombre diferente
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cka-pv-fixed-v2
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/cka-fixed-v2
    type: DirectoryOrCreate
EOF
```

---

### Problema 2: El Pod `config-consumer` (T9) queda en `Error` o `CrashLoopBackOff`

**Síntomas:**
```
NAME              READY   STATUS             RESTARTS   AGE
config-consumer   0/1     CrashLoopBackOff   3          2m
```
`kubectl logs config-consumer -n cka-advanced` muestra:
```
cat: can't open '/config/app.properties': No such file or directory
```

**Causa:** El nombre de la clave en el ConfigMap `app-file-config` no coincide con lo que el Pod intenta montar. Al usar `--from-file=app.properties=/tmp/app.properties`, la clave del ConfigMap es `app.properties`, pero si se usó una ruta diferente la clave puede ser distinta. Además, si el Pod tiene `restartPolicy: Never` y el comando falla, quedará en estado `Error` (no `CrashLoopBackOff`).

**Solución:**
```bash
# Verificar las claves exactas del ConfigMap
kubectl get configmap app-file-config -n cka-advanced -o jsonpath='{.data}' | jq 'keys'

# Si la clave es diferente a 'app.properties', recrear el ConfigMap
kubectl delete configmap app-file-config -n cka-advanced

cat <<'EOF' > /tmp/app.properties
environment=production
max_connections=100
timeout_seconds=30
EOF

kubectl create configmap app-file-config \
  --from-file=app.properties=/tmp/app.properties \
  --namespace=cka-advanced

# Verificar la clave creada
kubectl get configmap app-file-config -n cka-advanced -o yaml | grep "app.properties"

# Eliminar y recrear el Pod
kubectl delete pod config-consumer -n cka-advanced
kubectl apply -f /tmp/t9-pod.yaml

# Verificar
kubectl wait pod config-consumer -n cka-advanced --for=condition=Ready --timeout=60s
kubectl exec config-consumer -n cka-advanced -- cat /config/app.properties
```

---

## Limpieza del Entorno

> ⚠️ **Importante:** Ejecuta la limpieza **solo si** no vas a continuar con otros laboratorios que reutilicen estos recursos. Si el clúster se usa en prácticas posteriores, conserva los namespaces.

```bash
# Eliminar todos los recursos creados en este laboratorio
echo "Iniciando limpieza del Lab 09-00-01..."

# Eliminar namespaces (elimina todos los recursos dentro de ellos)
kubectl delete namespace cka-red cka-storage cka-troubleshoot cka-advanced cka-dns \
  --ignore-not-found=true

# Eliminar PersistentVolumes (son recursos de clúster, no de namespace)
kubectl delete pv cka-pv-data cka-pv-fixed cka-pv-fixed-v2 \
  --ignore-not-found=true

# Limpiar archivos temporales
rm -f /tmp/t1-deployment.yaml /tmp/t1-service.yaml
rm -f /tmp/t3-netpol.yaml
rm -f /tmp/t4-pv.yaml /tmp/t4-pvc.yaml /tmp/t4-pod.yaml
rm -f /tmp/t5-pv.yaml
rm -f /tmp/t6-pod.yaml
rm -f /tmp/t9-configmap.yaml /tmp/t9-pod.yaml
rm -f /tmp/t10-secret.yaml /tmp/t10-pod.yaml
rm -f /tmp/app.properties
rm -rf /tmp/tls-certs
rm -f /tmp/validate-lab09.sh

# Verificar que los namespaces fueron eliminados
kubectl get namespaces | grep cka || echo "Limpieza completada correctamente."

# Verificar que los PVs fueron eliminados
kubectl get pv | grep cka || echo "PersistentVolumes eliminados correctamente."

echo "✅ Limpieza completada."
```

Si deseas detener el clúster Minikube sin eliminarlo (recomendado para preservar configuración entre módulos):

```bash
# Detener sin eliminar (preserva estado)
minikube stop

# Para reiniciar en la próxima sesión
minikube start
```

---

## Resumen

### Puntos Clave del Laboratorio

Este laboratorio ha simulado las condiciones reales del examen CKA con 10 tareas independientes que cubren los dominios fundamentales de Kubernetes:

| Tarea | Dominio          | Técnica Principal                              |
|-------|------------------|------------------------------------------------|
| T1    | Red              | Deployment + Service NodePort con nodePort fijo |
| T2    | Red              | Diagnóstico de selector incorrecto en Service  |
| T3    | Red              | NetworkPolicy con podSelector                  |
| T4    | Almacenamiento   | PV/PVC con hostPath y Pod con volumeMount      |
| T5    | Almacenamiento   | Diagnóstico de PVC Pending por StorageClass    |
| T6    | Troubleshooting  | Reparación de CrashLoopBackOff                 |
| T7    | Troubleshooting  | Verificación y restauración de DNS (CoreDNS)   |
| T8    | Troubleshooting  | Escalado de Deployment y verificación de tráfico|
| T9    | Configuración    | ConfigMap como envFrom y volumeMount           |
| T10   | Configuración    | Secret TLS montado como volumen                |

### Lecciones Metodológicas

- **Nunca omitas el cambio de contexto/namespace**: es el error más costoso en el examen real.
- **El patrón `--dry-run=client -o yaml`** es tu herramienta más valiosa: genera YAML correcto en segundos y te permite editarlo antes de aplicar.
- **Verifica siempre con `kubectl get` y `kubectl describe`** antes de marcar una tarea como completa; una solución no verificada puede contener errores silenciosos.
- **Los endpoints vacíos** son la primera señal de un selector incorrecto entre Service y Pods.
- **Un PVC en Pending** casi siempre indica falta de PV disponible o StorageClass incorrecta.

### Recursos Adicionales

- [Guía oficial del examen CKA — Linux Foundation](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- [kubectl Cheat Sheet oficial](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Simulador oficial killer.sh para CKA](https://killer.sh/cka)
- [Documentación: Gestión de objetos con kubectl](https://kubernetes.io/docs/concepts/overview/working-with-objects/object-management/)
- [Documentación: NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Documentación: Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Documentación: Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Documentación: ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)

---
*Lab 09-00-01 — Módulo 9: Resolución de Escenarios Integrales Tipo CKA*
*Curso: Kubernetes Administrator — Nivel Intermedio*
