# Diagnóstico y resolución de fallos en Pods, Services y DNS

## Metadatos

| Campo        | Valor                          |
|--------------|-------------------------------|
| **Duración** | 90 minutos                    |
| **Complejidad** | Alta                       |
| **Nivel Bloom** | Aplicar (Apply)            |
| **Módulo**   | 8 — Troubleshooting en Kubernetes |
| **Versión Kubernetes** | 1.28+               |

---

## Descripción General

Este laboratorio presenta **8 escenarios de fallo pre-configurados** en tres categorías: fallos en Pods, fallos en Services y fallos de DNS. El estudiante aplicará una metodología sistemática de diagnóstico usando `kubectl describe`, `kubectl logs`, `kubectl get events` y herramientas de debug dentro de contenedores para identificar la causa raíz de cada fallo, aplicar la corrección y validar la resolución. El lab refuerza directamente los conceptos de la Lección 8.1 sobre inspección con `kubectl describe`, extendiendo la práctica hacia logs, conectividad de servicios y resolución DNS.

---

## Objetivos de Aprendizaje

- [ ] Aplicar la metodología de troubleshooting usando `kubectl describe`, `kubectl logs` y `kubectl get events` para diagnosticar fallos en Pods (ImagePullBackOff, CrashLoopBackOff, OOMKilled, Pending)
- [ ] Identificar y corregir problemas de conectividad en Services causados por selectores incorrectos, targetPort erróneo y liveness probes fallidas
- [ ] Resolver fallos de DNS interno usando pods de diagnóstico efímeros y análisis del estado de CoreDNS
- [ ] Utilizar `kubectl debug` y `kubectl exec` para diagnóstico avanzado dentro de contenedores en ejecución
- [ ] Validar la resolución completa de todos los escenarios mediante comandos de verificación sistemáticos

---

## Prerrequisitos

### Conocimiento Previo
- Completar Labs 06-00-02 y 06-00-03 (Services y DNS) o conocimiento equivalente
- Comprensión de los estados del ciclo de vida de un Pod: `Pending`, `Running`, `CrashLoopBackOff`, `OOMKilled`
- Familiaridad básica con `kubectl describe`, `kubectl logs` y `kubectl get events`
- Conocimiento de liveness/readiness probes en Kubernetes

### Acceso Requerido
- Clúster Kubernetes operativo con **mínimo 2 nodos** (control plane + 1 worker)
- `kubectl` configurado con acceso de administrador al clúster
- Acceso a Internet para descarga de imágenes de contenedor
- Terminal con `curl`, `jq` instalados en el host

---

## Entorno del Laboratorio

### Requisitos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 4 núcleos | 8 núcleos |
| RAM | 8 GB | 16 GB |
| Almacenamiento | 40 GB libres | 60 GB libres |
| Red | 10 Mbps | 25 Mbps |

### Software Requerido

| Herramienta | Versión |
|-------------|---------|
| Kubernetes | 1.28+ |
| kubectl | 1.28+ |
| Minikube | 1.31+ (si aplica) |
| Docker Engine | 24.x+ |
| curl | 7.x+ |
| dig / nslookup | bind-utils 9.x |

### Configuración del Entorno

**Paso 1 — Verificar o iniciar el clúster multi-nodo:**

```bash
# Verificar si el clúster ya está corriendo
kubectl get nodes

# Si usas Minikube y necesitas iniciar el clúster:
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que todos los nodos estén Ready
kubectl get nodes -o wide
```

**Paso 2 — Crear el namespace de trabajo:**

```bash
kubectl create namespace troubleshooting-lab
```

**Paso 3 — Pre-descargar imágenes necesarias (opcional, para entornos con conectividad limitada):**

```bash
for img in nginx:1.25 nginx:1.26 busybox:latest node:18-alpine; do
  docker pull $img
done
```

**Paso 4 — Desplegar todos los escenarios de fallo con el script de setup:**

Crea el archivo `lab08-setup.sh` con el siguiente contenido:

```bash
#!/bin/bash
# lab08-setup.sh — Configura los 8 escenarios de fallo del Lab 08-00-01
NS="troubleshooting-lab"

echo "=== Desplegando escenarios de fallo en namespace: $NS ==="

# ── CATEGORÍA A: Fallos en Pods ──────────────────────────────────────────────

# A1: ImagePullBackOff — imagen inexistente
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a1-imagepull
  labels:
    scenario: a1
spec:
  containers:
  - name: app
    image: nginx:this-tag-does-not-exist-99999
    ports:
    - containerPort: 80
EOF

# A2: CrashLoopBackOff — comando de inicio incorrecto
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a2-crashloop
  labels:
    scenario: a2
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: ["/bin/sh", "-c", "ejecutar-comando-inexistente --flag"]
EOF

# A3: Pending — requests de recursos excesivos
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a3-pending
  labels:
    scenario: a3
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "999Gi"
        cpu: "999"
EOF

# ── CATEGORÍA B: Fallos en Services ─────────────────────────────────────────

# B1: Selector incorrecto — el Service no apunta a ningún Pod
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-b1-backend
  labels:
    app: backend-real
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: svc-b1-wrong-selector
spec:
  selector:
    app: backend-typo
  ports:
  - port: 80
    targetPort: 80
EOF

# B2: targetPort incorrecto — el Service apunta al puerto equivocado
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-b2-webserver
  labels:
    app: webserver-b2
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: svc-b2-wrong-port
spec:
  selector:
    app: webserver-b2
  ports:
  - port: 80
    targetPort: 9999
EOF

# B3: Liveness probe fallida — 0 réplicas ready
kubectl apply -n $NS -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-b3-liveness
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-b3
  template:
    metadata:
      labels:
        app: app-b3
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /this-path-does-not-exist-healthz
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
---
apiVersion: v1
kind: Service
metadata:
  name: svc-b3-liveness
spec:
  selector:
    app: app-b3
  ports:
  - port: 80
    targetPort: 80
EOF

# ── CATEGORÍA C: Fallos de DNS ───────────────────────────────────────────────

# C1: dnsPolicy incorrecta — Pod no puede resolver nombres
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-c1-dns-policy
  labels:
    scenario: c1
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 1.2.3.4
  containers:
  - name: debug
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

# C2: Pod de diagnóstico para simular resolución DNS lenta
# (CoreDNS se diagnostica desde un pod de debug)
kubectl apply -n $NS -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-c2-dns-debug
  labels:
    scenario: c2
spec:
  containers:
  - name: debug
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF

echo ""
echo "=== Setup completado. Espera 30 segundos para que los recursos se estabilicen... ==="
sleep 30
echo "=== Listo. Ejecuta: kubectl get pods -n troubleshooting-lab ==="
```

```bash
chmod +x lab08-setup.sh
bash lab08-setup.sh
```

**Verificación del setup:**

```bash
kubectl get pods -n troubleshooting-lab
kubectl get deployments -n troubleshooting-lab
kubectl get services -n troubleshooting-lab
```

> **Nota:** Es normal ver pods en estado `Pending`, `CrashLoopBackOff` o `ImagePullBackOff`. Eso es exactamente lo que debes diagnosticar.

---

## Instrucciones Paso a Paso

### Sección 8.1 — Metodología de Troubleshooting: El Flujo Sistemático

**Objetivo:** Establecer el flujo de diagnóstico que usarás en todos los escenarios.

Antes de abordar cada escenario, interioriza este flujo de cuatro pasos basado en la Lección 8.1:

```
1. OBSERVAR  → kubectl get pods/services/endpoints (estado general)
2. DESCRIBIR → kubectl describe pod/service/node (causa raíz)
3. ANALIZAR  → kubectl logs / kubectl get events (historial)
4. CORREGIR  → kubectl apply / kubectl patch / kubectl delete+recrear
5. VALIDAR   → kubectl get + prueba funcional
```

```bash
# Comando de observación inicial — ejecuta esto primero en cada escenario
kubectl get pods -n troubleshooting-lab -o wide
kubectl get events -n troubleshooting-lab --sort-by=.lastTimestamp | tail -30
```

---

### Escenario A1 — ImagePullBackOff: Imagen Inexistente

**Objetivo:** Diagnosticar y corregir un Pod que no puede descargarse la imagen del contenedor.

#### Instrucciones

**1. Observar el estado del Pod:**

```bash
kubectl get pod pod-a1-imagepull -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                 READY   STATUS             RESTARTS   AGE
pod-a1-imagepull     0/1     ImagePullBackOff   0          2m
```

**2. Describir el Pod para identificar la causa raíz:**

```bash
kubectl describe pod pod-a1-imagepull -n troubleshooting-lab
```

Localiza la sección **Events** al final de la salida. Busca el campo `Reason` y `Message`:

**Salida esperada (sección Events):**
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  3m                 default-scheduler  Successfully assigned...
  Normal   Pulling    2m (x3 over 3m)    kubelet            Pulling image "nginx:this-tag-does-not-exist-99999"
  Warning  Failed     2m (x3 over 3m)    kubelet            Failed to pull image "nginx:this-tag-does-not-exist-99999": ...
  Warning  Failed     2m (x3 over 3m)    kubelet            Error: ErrImagePull
  Warning  BackOff    90s (x4 over 2m)   kubelet            Back-off pulling image "nginx:this-tag-does-not-exist-99999"
```

**3. Identificar la causa raíz:**

El mensaje `Failed to pull image` con el tag `this-tag-does-not-exist-99999` confirma que el nombre de la imagen es incorrecto. La causa raíz es un **tag de imagen inválido**.

**4. Aplicar la corrección — eliminar y recrear el Pod con la imagen correcta:**

```bash
kubectl delete pod pod-a1-imagepull -n troubleshooting-lab

kubectl run pod-a1-imagepull \
  --image=nginx:1.25 \
  --port=80 \
  -n troubleshooting-lab \
  --labels="scenario=a1"
```

**5. Verificar la resolución:**

```bash
kubectl get pod pod-a1-imagepull -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                 READY   STATUS    RESTARTS   AGE
pod-a1-imagepull     1/1     Running   0          30s
```

```bash
# Verificación adicional — confirmar que el contenedor responde
kubectl exec pod-a1-imagepull -n troubleshooting-lab -- curl -s -o /dev/null -w "%{http_code}" http://localhost:80
```

**Salida esperada:** `200`

> **Lección aprendida:** En `ImagePullBackOff`, la sección **Events** de `kubectl describe` siempre muestra el nombre exacto de la imagen que falló. Verifica tag, nombre del repositorio y, si es una imagen privada, la existencia del `imagePullSecret`.

---

### Escenario A2 — CrashLoopBackOff: Comando de Inicio Incorrecto

**Objetivo:** Diagnosticar un Pod que falla inmediatamente al iniciar por un entrypoint inválido.

#### Instrucciones

**1. Observar el estado:**

```bash
kubectl get pod pod-a2-crashloop -n troubleshooting-lab
```

**Salida esperada:**
```
NAME               READY   STATUS             RESTARTS   AGE
pod-a2-crashloop   0/1     CrashLoopBackOff   4          3m
```

**2. Describir el Pod — revisar el bloque Containers:**

```bash
kubectl describe pod pod-a2-crashloop -n troubleshooting-lab
```

Localiza el bloque **Containers** y el campo **Last State**:

**Salida esperada (bloque Containers):**
```
Containers:
  app:
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled / Error
      Exit Code:    127
      Started:      <timestamp>
      Finished:     <timestamp>
    Ready:          False
    Restart Count:  4
```

> El **Exit Code 127** significa "command not found" en shells Unix. Confirma que el comando del entrypoint no existe.

**3. Revisar los logs del contenedor terminado:**

```bash
kubectl logs pod-a2-crashloop -n troubleshooting-lab --previous
```

**Salida esperada:**
```
/bin/sh: ejecutar-comando-inexistente: not found
```

**4. Confirmar el comando configurado:**

```bash
kubectl get pod pod-a2-crashloop -n troubleshooting-lab -o jsonpath='{.spec.containers[0].command}'
```

**Salida esperada:**
```
["/bin/sh","-c","ejecutar-comando-inexistente --flag"]
```

**5. Aplicar la corrección:**

```bash
kubectl delete pod pod-a2-crashloop -n troubleshooting-lab

kubectl apply -n troubleshooting-lab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a2-crashloop
  labels:
    scenario: a2
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: ["/bin/sh", "-c", "nginx -g 'daemon off;'"]
    ports:
    - containerPort: 80
EOF
```

**6. Verificar la resolución:**

```bash
kubectl get pod pod-a2-crashloop -n troubleshooting-lab
kubectl logs pod-a2-crashloop -n troubleshooting-lab | head -5
```

**Salida esperada:**
```
NAME               READY   STATUS    RESTARTS   AGE
pod-a2-crashloop   1/1     Running   0          20s
```

> **Lección aprendida:** En `CrashLoopBackOff`, el **Exit Code** en `kubectl describe` es el primer indicador clave: `127` = comando no encontrado, `1` = error de aplicación, `137` = OOMKilled (señal SIGKILL). Siempre combina `describe` + `logs --previous`.

---

### Escenario A3 — Pod en Pending: Recursos Insuficientes

**Objetivo:** Diagnosticar por qué un Pod no puede ser programado en ningún nodo.

#### Instrucciones

**1. Observar el estado — el Pod lleva tiempo en Pending:**

```bash
kubectl get pod pod-a3-pending -n troubleshooting-lab
```

**Salida esperada:**
```
NAME            READY   STATUS    RESTARTS   AGE
pod-a3-pending  0/1     Pending   0          5m
```

**2. Describir el Pod — leer la sección Events:**

```bash
kubectl describe pod pod-a3-pending -n troubleshooting-lab
```

**Salida esperada (sección Events):**
```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  5m    default-scheduler  0/3 nodes are available:
                                                       3 Insufficient memory.
                                                       preemption: 0/3 nodes are
                                                       available: 3 No preemption
                                                       victims found...
```

**3. Verificar los recursos del nodo para entender el límite:**

```bash
kubectl describe nodes | grep -A 8 "Allocated resources"
```

**Salida esperada (ejemplo):**
```
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests      Limits
  --------           --------      ------
  cpu                650m (32%)    0 (0%)
  memory             640Mi (16%)   0 (0%)
```

**4. Confirmar el request excesivo del Pod:**

```bash
kubectl get pod pod-a3-pending -n troubleshooting-lab \
  -o jsonpath='{.spec.containers[0].resources}'
```

**Salida esperada:**
```
{"requests":{"cpu":"999","memory":"999Gi"}}
```

Un request de `999Gi` de memoria y `999` CPUs es imposible de satisfacer en cualquier nodo del clúster de práctica.

**5. Aplicar la corrección — requests razonables:**

```bash
kubectl delete pod pod-a3-pending -n troubleshooting-lab

kubectl apply -n troubleshooting-lab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a3-pending
  labels:
    scenario: a3
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
EOF
```

**6. Verificar la resolución:**

```bash
kubectl get pod pod-a3-pending -n troubleshooting-lab -w
```

**Salida esperada:**
```
NAME            READY   STATUS    RESTARTS   AGE
pod-a3-pending  0/1     Pending   0          0s
pod-a3-pending  0/1     ContainerCreating   0   2s
pod-a3-pending  1/1     Running   0          5s
```

> **Lección aprendida:** Un Pod en `Pending` con el evento `FailedScheduling` siempre indica un problema de scheduling. Lee el mensaje completo: puede ser recursos insuficientes, taints sin tolerations, nodeSelector sin coincidencia o affinity rules. `kubectl describe node` revela la capacidad real disponible.

---

### Escenario B1 — Service con Selector Incorrecto

**Objetivo:** Diagnosticar un Service que no enruta tráfico porque su selector no coincide con ningún Pod.

#### Instrucciones

**1. Verificar el estado del Service y sus Endpoints:**

```bash
kubectl get service svc-b1-wrong-selector -n troubleshooting-lab
kubectl get endpoints svc-b1-wrong-selector -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
svc-b1-wrong-selector   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    5m

NAME                    ENDPOINTS   AGE
svc-b1-wrong-selector   <none>      5m
```

> **Señal crítica:** `ENDPOINTS: <none>` significa que el Service no tiene ningún Pod backend. El tráfico no llegará a ningún destino.

**2. Describir el Service para ver su selector:**

```bash
kubectl describe service svc-b1-wrong-selector -n troubleshooting-lab
```

**Salida esperada (sección relevante):**
```
Selector:          app=backend-typo
...
Endpoints:         <none>
```

**3. Verificar las labels del Pod destino:**

```bash
kubectl get pod pod-b1-backend -n troubleshooting-lab --show-labels
```

**Salida esperada:**
```
NAME             READY   STATUS    RESTARTS   AGE   LABELS
pod-b1-backend   1/1     Running   0          5m    app=backend-real
```

**Causa raíz identificada:** El selector del Service usa `app=backend-typo` pero el Pod tiene la label `app=backend-real`. El typo en el selector impide la asociación.

**4. Aplicar la corrección — parchear el selector del Service:**

```bash
kubectl patch service svc-b1-wrong-selector -n troubleshooting-lab \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend-real"}]'
```

**5. Verificar la resolución:**

```bash
kubectl get endpoints svc-b1-wrong-selector -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                    ENDPOINTS          AGE
svc-b1-wrong-selector   10.244.x.x:80      5m
```

```bash
# Prueba funcional desde un pod de diagnóstico temporal
kubectl run test-b1 --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- wget -qO- http://svc-b1-wrong-selector:80 | head -5
```

**Salida esperada:** HTML de la página de bienvenida de nginx.

> **Lección aprendida:** Cuando un Service no funciona, **siempre revisa los Endpoints primero** con `kubectl get endpoints`. Si están vacíos, el problema es el selector. Compara el selector del Service con las labels reales del Pod usando `kubectl get pods --show-labels`.

---

### Escenario B2 — Service con targetPort Incorrecto

**Objetivo:** Diagnosticar un Service que tiene Endpoints pero las conexiones son rechazadas.

#### Instrucciones

**1. Verificar Endpoints — esta vez SÍ existen:**

```bash
kubectl get endpoints svc-b2-wrong-port -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                ENDPOINTS          AGE
svc-b2-wrong-port   10.244.x.x:9999    5m
```

> El Endpoint existe pero apunta al **puerto 9999**. Nginx escucha en el puerto 80.

**2. Probar la conectividad para confirmar el fallo:**

```bash
kubectl run test-b2 --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- wget -qO- --timeout=5 http://svc-b2-wrong-port:80
```

**Salida esperada:**
```
wget: can't connect to remote host (10.96.x.x): Connection refused
```

**3. Describir el Service para ver la configuración de puertos:**

```bash
kubectl describe service svc-b2-wrong-port -n troubleshooting-lab
```

**Salida esperada (sección relevante):**
```
Port:              <unset>  80/TCP
TargetPort:        9999/TCP
Endpoints:         10.244.x.x:9999
```

**4. Verificar el puerto real del contenedor:**

```bash
kubectl describe pod pod-b2-webserver -n troubleshooting-lab | grep -A 5 "Ports:"
```

**Salida esperada:**
```
    Ports:          80/TCP
```

**Causa raíz:** El `targetPort` del Service es `9999` pero el contenedor escucha en el puerto `80`.

**5. Aplicar la corrección:**

```bash
kubectl patch service svc-b2-wrong-port -n troubleshooting-lab \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 80}]'
```

**6. Verificar la resolución:**

```bash
kubectl get endpoints svc-b2-wrong-port -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                ENDPOINTS         AGE
svc-b2-wrong-port   10.244.x.x:80     5m
```

```bash
kubectl run test-b2 --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- wget -qO- http://svc-b2-wrong-port:80 | head -3
```

**Salida esperada:** HTML de nginx (código 200).

> **Lección aprendida:** Cuando los Endpoints existen pero la conexión falla, el problema suele ser `targetPort` incorrecto o un firewall/NetworkPolicy. Verifica que el `targetPort` del Service coincida con el `containerPort` del Pod.

---

### Escenario B3 — Liveness Probe Fallida: 0 Réplicas Ready

**Objetivo:** Diagnosticar un Deployment donde las liveness probes fallan continuamente, dejando el Service sin backends disponibles.

#### Instrucciones

**1. Observar el estado del Deployment:**

```bash
kubectl get deployment deploy-b3-liveness -n troubleshooting-lab
kubectl get pods -n troubleshooting-lab -l app=app-b3
```

**Salida esperada (después de ~30 segundos):**
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
deploy-b3-liveness  0/2     2            0           2m

NAME                                  READY   STATUS             RESTARTS   AGE
deploy-b3-liveness-xxxxxxxxx-xxxxx    0/1     CrashLoopBackOff   3          2m
deploy-b3-liveness-xxxxxxxxx-yyyyy    0/1     CrashLoopBackOff   3          2m
```

**2. Describir uno de los Pods para ver los eventos de la probe:**

```bash
# Obtener el nombre de un Pod del Deployment
POD_B3=$(kubectl get pods -n troubleshooting-lab -l app=app-b3 -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_B3 -n troubleshooting-lab
```

**Salida esperada (sección Events):**
```
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  3m                default-scheduler  Successfully assigned...
  Normal   Pulled     3m                kubelet            Successfully pulled image
  Normal   Created    3m                kubelet            Created container app
  Normal   Started    3m                kubelet            Started container app
  Warning  Unhealthy  2m (x6 over 3m)   kubelet            Liveness probe failed:
                                                            HTTP probe failed with
                                                            statuscode: 404
  Normal   Killing    2m (x2 over 2m)   kubelet            Container app failed
                                                            liveness probe, will be
                                                            restarted
```

**3. Verificar la configuración de la liveness probe:**

```bash
kubectl get deployment deploy-b3-liveness -n troubleshooting-lab \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' | jq .
```

**Salida esperada:**
```json
{
  "failureThreshold": 2,
  "httpGet": {
    "path": "/this-path-does-not-exist-healthz",
    "port": 80,
    "scheme": "HTTP"
  },
  "initialDelaySeconds": 5,
  "periodSeconds": 5
}
```

**Causa raíz:** La liveness probe hace GET a `/this-path-does-not-exist-healthz` en nginx. Nginx responde `404`, la probe falla, y Kubernetes reinicia el contenedor indefinidamente.

**4. Verificar qué ruta existe en nginx:**

```bash
# Crear un pod temporal para probar
kubectl run test-b3 --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- wget -qO- http://svc-b3-liveness:80/ | head -3
```

**5. Aplicar la corrección — actualizar la liveness probe al path correcto:**

```bash
kubectl patch deployment deploy-b3-liveness -n troubleshooting-lab \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path", "value": "/"}]'
```

**6. Verificar la resolución:**

```bash
kubectl rollout status deployment/deploy-b3-liveness -n troubleshooting-lab
kubectl get pods -n troubleshooting-lab -l app=app-b3
kubectl get endpoints svc-b3-liveness -n troubleshooting-lab
```

**Salida esperada:**
```
deployment "deploy-b3-liveness" successfully rolled out

NAME                                  READY   STATUS    RESTARTS   AGE
deploy-b3-liveness-xxxxxxxxx-aaaaa    1/1     Running   0          45s
deploy-b3-liveness-xxxxxxxxx-bbbbb    1/1     Running   0          40s

NAME              ENDPOINTS                         AGE
svc-b3-liveness   10.244.x.x:80,10.244.x.x:80      5m
```

> **Lección aprendida:** Una liveness probe mal configurada puede destruir la disponibilidad de un Service completo. El síntoma es `CrashLoopBackOff` con el evento `Unhealthy` y `Liveness probe failed`. Siempre verifica que el `path` de la probe exista y devuelva HTTP 2xx.

---

### Escenario C1 — dnsPolicy Incorrecta: Pod Incapaz de Resolver DNS

**Objetivo:** Diagnosticar y corregir un Pod que no puede resolver nombres de Service por configuración incorrecta de DNS.

#### Instrucciones

**1. Verificar que el Pod esté corriendo:**

```bash
kubectl get pod pod-c1-dns-policy -n troubleshooting-lab
```

**Salida esperada:**
```
NAME                 READY   STATUS    RESTARTS   AGE
pod-c1-dns-policy    1/1     Running   0          5m
```

> El Pod está en Running, pero no puede resolver DNS. Este es un caso donde `kubectl get` no muestra el problema.

**2. Intentar resolver un nombre de Service desde dentro del Pod:**

```bash
kubectl exec pod-c1-dns-policy -n troubleshooting-lab \
  -- nslookup kubernetes.default.svc.cluster.local
```

**Salida esperada:**
```
Server:    1.2.3.4
Address 1: 1.2.3.4

nslookup: can't resolve 'kubernetes.default.svc.cluster.local'
```

> El servidor DNS configurado es `1.2.3.4` (inexistente), no el servidor CoreDNS del clúster.

**3. Inspeccionar la configuración DNS del Pod:**

```bash
kubectl describe pod pod-c1-dns-policy -n troubleshooting-lab | grep -A 10 "DNS"
```

```bash
kubectl get pod pod-c1-dns-policy -n troubleshooting-lab \
  -o jsonpath='{.spec.dnsPolicy}'
```

**Salida esperada:**
```
None
```

```bash
kubectl exec pod-c1-dns-policy -n troubleshooting-lab -- cat /etc/resolv.conf
```

**Salida esperada:**
```
nameserver 1.2.3.4
```

**Causa raíz:** `dnsPolicy: None` con un `nameserver` inexistente (`1.2.3.4`) en `dnsConfig`. La política correcta para resolución interna del clúster es `ClusterFirst`.

**4. Aplicar la corrección — recrear el Pod con dnsPolicy correcta:**

```bash
kubectl delete pod pod-c1-dns-policy -n troubleshooting-lab

kubectl apply -n troubleshooting-lab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-c1-dns-policy
  labels:
    scenario: c1
spec:
  dnsPolicy: ClusterFirst
  containers:
  - name: debug
    image: busybox:latest
    command: ["sh", "-c", "sleep 3600"]
EOF
```

**5. Verificar la resolución:**

```bash
kubectl wait --for=condition=Ready pod/pod-c1-dns-policy \
  -n troubleshooting-lab --timeout=60s

kubectl exec pod-c1-dns-policy -n troubleshooting-lab \
  -- nslookup kubernetes.default.svc.cluster.local
```

**Salida esperada:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

```bash
# Verificar el /etc/resolv.conf correcto
kubectl exec pod-c1-dns-policy -n troubleshooting-lab -- cat /etc/resolv.conf
```

**Salida esperada:**
```
nameserver 10.96.0.10
search troubleshooting-lab.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

> **Lección aprendida:** Los valores válidos de `dnsPolicy` son: `ClusterFirst` (default, usa CoreDNS), `Default` (usa DNS del nodo), `None` (configuración manual con `dnsConfig`) y `ClusterFirstWithHostNet`. Un Pod con `dnsPolicy: None` sin nameservers válidos no puede resolver nada.

---

### Escenario C2 — Diagnóstico Avanzado de CoreDNS y DNS del Clúster

**Objetivo:** Usar herramientas de debug para diagnosticar la salud de CoreDNS y realizar resolución DNS desde un pod de diagnóstico, aplicando `kubectl debug` para análisis avanzado.

#### Instrucciones

**1. Verificar el estado de CoreDNS:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Salida esperada:**
```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-xxxxxxxxx-aaaaa    1/1     Running   0          1h
coredns-xxxxxxxxx-bbbbb    1/1     Running   0          1h
```

**2. Revisar los logs de CoreDNS para detectar errores:**

```bash
COREDNS_POD=$(kubectl get pods -n kube-system -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}')

kubectl logs $COREDNS_POD -n kube-system --tail=20
```

**Salida esperada (logs normales):**
```
[INFO] plugin/ready: Still waiting on: "kubernetes"
.:53
[INFO] plugin/reload: Running configuration MD5...
CoreDNS-1.10.x
linux/amd64, go1.20...
```

**3. Usar el pod de diagnóstico para probar resolución DNS completa:**

```bash
kubectl exec pod-c2-dns-debug -n troubleshooting-lab \
  -- nslookup kubernetes.default.svc.cluster.local
```

```bash
# Probar resolución del Service del escenario B1 (ya corregido)
kubectl exec pod-c2-dns-debug -n troubleshooting-lab \
  -- nslookup svc-b1-wrong-selector.troubleshooting-lab.svc.cluster.local
```

```bash
# Probar resolución DNS externa
kubectl exec pod-c2-dns-debug -n troubleshooting-lab \
  -- nslookup google.com
```

**4. Usar kubectl debug para diagnóstico avanzado con un contenedor efímero:**

```bash
# Adjuntar un contenedor de debug efímero a un pod en ejecución
kubectl debug -it pod-c2-dns-debug \
  -n troubleshooting-lab \
  --image=busybox:latest \
  --target=debug \
  -- sh
```

Dentro del shell efímero, ejecuta:

```sh
# Verificar configuración DNS
cat /etc/resolv.conf

# Probar resolución con dig (si está disponible en la imagen)
nslookup kube-dns.kube-system.svc.cluster.local

# Probar conectividad al servidor DNS
nc -zv 10.96.0.10 53

# Salir
exit
```

**5. Simular diagnóstico de DNS lento — usar un pod de diagnóstico temporal:**

```bash
# Crear un pod de diagnóstico temporal con herramientas de red
kubectl run dns-diag --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- sh -c "
    echo '=== Resolución DNS del clúster ===';
    nslookup kubernetes.default.svc.cluster.local;
    echo '';
    echo '=== Resolución de Services en el namespace ===';
    nslookup svc-b3-liveness.troubleshooting-lab.svc.cluster.local;
    echo '';
    echo '=== DNS externo ===';
    nslookup google.com;
  "
```

**Salida esperada:** Todas las resoluciones deben completarse exitosamente.

**6. Verificar la descripción del Service kube-dns:**

```bash
kubectl describe service kube-dns -n kube-system
```

**Salida esperada (campos clave):**
```
Name:              kube-dns
Namespace:         kube-system
Selector:          k8s-app=kube-dns
...
Port:              dns  53/UDP
TargetPort:        53/UDP
Endpoints:         10.244.x.x:53,10.244.x.x:53
Port:              dns-tcp  53/TCP
...
```

> **Verificación clave:** Los Endpoints del Service `kube-dns` deben tener IPs activas. Si están vacíos, CoreDNS no está corriendo correctamente.

**7. Verificar el ConfigMap de CoreDNS:**

```bash
kubectl describe configmap coredns -n kube-system
```

Busca la sección `Corefile` y verifica que contenga el plugin `kubernetes`:

**Salida esperada (fragmento del Corefile):**
```
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

> **Lección aprendida:** Para diagnosticar DNS en Kubernetes: (1) verifica que los pods de CoreDNS estén `Running` y `Ready`, (2) revisa los logs de CoreDNS, (3) prueba resolución desde un pod de debug con `nslookup`/`dig`, (4) verifica el ConfigMap `coredns` en `kube-system`, (5) confirma que el Service `kube-dns` tiene Endpoints activos.

---

## Validación Final (Sección 8.10)

**Objetivo:** Confirmar que todos los escenarios han sido resueltos correctamente.

### Verificación Integral de Todos los Recursos

```bash
echo "=========================================="
echo "VALIDACIÓN FINAL — Lab 08-00-01"
echo "=========================================="

NS="troubleshooting-lab"

echo ""
echo "--- CATEGORÍA A: Pods ---"
kubectl get pods -n $NS -l scenario=a1 --no-headers | awk '{print "A1 pod-a1-imagepull:", $3}'
kubectl get pods -n $NS -l scenario=a2 --no-headers | awk '{print "A2 pod-a2-crashloop:", $3}'
kubectl get pods -n $NS -l scenario=a3 --no-headers | awk '{print "A3 pod-a3-pending:", $3}'

echo ""
echo "--- CATEGORÍA B: Services y Endpoints ---"
kubectl get endpoints svc-b1-wrong-selector -n $NS --no-headers | awk '{print "B1 endpoints:", $2}'
kubectl get endpoints svc-b2-wrong-port -n $NS --no-headers | awk '{print "B2 endpoints:", $2}'
kubectl get endpoints svc-b3-liveness -n $NS --no-headers | awk '{print "B3 endpoints:", $2}'
kubectl get deployment deploy-b3-liveness -n $NS --no-headers | awk '{print "B3 deployment ready:", $2}'

echo ""
echo "--- CATEGORÍA C: DNS ---"
kubectl exec pod-c1-dns-policy -n $NS -- nslookup kubernetes.default 2>&1 | grep -q "Address" && echo "C1 DNS policy: OK" || echo "C1 DNS policy: FAIL"
kubectl exec pod-c2-dns-debug -n $NS -- nslookup kubernetes.default 2>&1 | grep -q "Address" && echo "C2 CoreDNS: OK" || echo "C2 CoreDNS: FAIL"

echo ""
echo "--- CoreDNS Health ---"
kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | awk '{print "CoreDNS pod:", $1, "Status:", $3, "Ready:", $2}'
```

**Salida esperada completa:**
```
==========================================
VALIDACIÓN FINAL — Lab 08-00-01
==========================================

--- CATEGORÍA A: Pods ---
A1 pod-a1-imagepull: Running
A2 pod-a2-crashloop: Running
A3 pod-a3-pending: Running

--- CATEGORÍA B: Services y Endpoints ---
B1 endpoints: 10.244.x.x:80
B2 endpoints: 10.244.x.x:80
B3 endpoints: 10.244.x.x:80,10.244.x.x:80
B3 deployment ready: 2/2

--- CATEGORÍA C: DNS ---
C1 DNS policy: OK
C2 CoreDNS: OK

--- CoreDNS Health ---
CoreDNS pod: coredns-xxx-yyy Status: Running Ready: 1/1
CoreDNS pod: coredns-xxx-zzz Status: Running Ready: 1/1
```

### Prueba Funcional de Conectividad End-to-End

```bash
# Prueba final de conectividad a través de Services
kubectl run final-test --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- sh -c "
    echo '=== Test B1 ===';
    wget -qO- --timeout=5 http://svc-b1-wrong-selector.troubleshooting-lab.svc.cluster.local:80 | head -2;
    echo '=== Test B2 ===';
    wget -qO- --timeout=5 http://svc-b2-wrong-port.troubleshooting-lab.svc.cluster.local:80 | head -2;
    echo '=== Test B3 ===';
    wget -qO- --timeout=5 http://svc-b3-liveness.troubleshooting-lab.svc.cluster.local:80 | head -2;
    echo '=== Todos los tests completados ===';
  "
```

---

## Troubleshooting del Laboratorio

### Problema 1: El Pod A3 sigue en Pending después de aplicar la corrección

**Síntoma:**
```
NAME            READY   STATUS    RESTARTS   AGE
pod-a3-pending  0/1     Pending   0          3m
```
Después de eliminar y recrear el Pod con requests reducidos, sigue sin ser programado.

**Causa:**
El clúster Minikube tiene los nodos con recursos ya comprometidos por otros Pods del laboratorio. Los requests de `64Mi` de memoria pueden ser insuficientes si el nodo tiene muy poca memoria libre.

**Solución:**

```bash
# Paso 1: Verificar recursos disponibles reales
kubectl describe nodes | grep -A 6 "Allocated resources"

# Paso 2: Revisar qué Pods están consumiendo más recursos
kubectl top pods -n troubleshooting-lab 2>/dev/null || \
  kubectl get pods -n troubleshooting-lab -o custom-columns=\
'NAME:.metadata.name,CPU:.spec.containers[0].resources.requests.cpu,MEM:.spec.containers[0].resources.requests.memory'

# Paso 3: Si el nodo tiene menos de 64Mi libre, reducir el request aún más
kubectl delete pod pod-a3-pending -n troubleshooting-lab
kubectl apply -n troubleshooting-lab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-a3-pending
  labels:
    scenario: a3
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
EOF

# Paso 4: Si Minikube tiene recursos muy limitados, agregar un nodo
minikube node add --worker
```

---

### Problema 2: `kubectl debug` falla con "ephemeral containers not supported"

**Síntoma:**
```
error: ephemeral containers are disabled for this cluster
```
o
```
Error from server (NotFound): the server could not find the requested resource
```

**Causa:**
La feature gate `EphemeralContainers` no está habilitada en la versión de Kubernetes del clúster, o la versión es anterior a 1.25 donde los contenedores efímeros son estables.

**Solución:**

```bash
# Verificar la versión de Kubernetes
kubectl version --short

# Si la versión es >= 1.25, los ephemeral containers están habilitados por defecto.
# Si el problema persiste en Minikube, verificar la feature gate:
minikube ssh -- cat /var/lib/kubelet/config.yaml | grep -A 5 "featureGates"

# Alternativa: usar kubectl exec con un pod de debug separado en lugar de debug efímero
kubectl run debug-alt --rm -it --restart=Never \
  --image=busybox:latest \
  -n troubleshooting-lab \
  -- sh

# Dentro del pod alternativo, ejecutar las mismas pruebas de diagnóstico
```

Si el clúster no soporta contenedores efímeros, usa siempre `kubectl run` con `--rm` para crear pods de diagnóstico temporales en lugar de `kubectl debug`.

---

## Limpieza del Entorno

```bash
# Opción 1: Eliminar solo el namespace del laboratorio (recomendado)
kubectl delete namespace troubleshooting-lab

# Verificar que el namespace fue eliminado
kubectl get namespace troubleshooting-lab

# Opción 2: Si deseas conservar el namespace pero eliminar recursos individuales
kubectl delete pods --all -n troubleshooting-lab
kubectl delete deployments --all -n troubleshooting-lab
kubectl delete services --all -n troubleshooting-lab

# Eliminar pods de diagnóstico temporales que pudieran haber quedado
kubectl delete pod test-b1 test-b2 test-b3 dns-diag final-test \
  -n troubleshooting-lab --ignore-not-found=true
```

> **Nota de persistencia:** Si planeas continuar con el Lab 09-00-01, **NO elimines el clúster Minikube**. Usa solo `kubectl delete namespace troubleshooting-lab` para limpiar los recursos de este laboratorio.

---

## Resumen

### Lo que Aprendiste

En este laboratorio aplicaste una **metodología sistemática de troubleshooting** en 8 escenarios reales distribuidos en tres categorías:

| Escenario | Síntoma | Causa Raíz | Herramienta Clave |
|-----------|---------|-----------|-------------------|
| A1 | ImagePullBackOff | Tag de imagen inválido | `kubectl describe` → Events |
| A2 | CrashLoopBackOff | Comando de inicio inexistente | `kubectl describe` + `kubectl logs --previous` |
| A3 | Pending | Requests de recursos imposibles | `kubectl describe` → Events + `kubectl describe node` |
| B1 | Sin tráfico al Service | Selector con typo | `kubectl get endpoints` + `--show-labels` |
| B2 | Connection refused | targetPort incorrecto | `kubectl describe service` + prueba con `wget` |
| B3 | 0 réplicas ready | Liveness probe fallida (404) | `kubectl describe pod` → Events `Unhealthy` |
| C1 | DNS no resuelve | dnsPolicy: None con nameserver falso | `kubectl exec` + `nslookup` + `cat /etc/resolv.conf` |
| C2 | Diagnóstico CoreDNS | Análisis de salud del DNS del clúster | `kubectl debug` + `kubectl logs` CoreDNS |

### Flujo de Diagnóstico Consolidado

```
OBSERVAR   → kubectl get pods/services/endpoints
DESCRIBIR  → kubectl describe pod/service/node  ← SIEMPRE PRIMERO
ANALIZAR   → kubectl logs [--previous] / kubectl get events --sort-by=.lastTimestamp
DEBUG      → kubectl exec / kubectl run --rm / kubectl debug
CORREGIR   → kubectl patch / kubectl apply / kubectl delete+recrear
VALIDAR    → kubectl get + prueba funcional (wget/nslookup)
```

### Comandos Esenciales del Módulo 8

```bash
# Inspección
kubectl describe pod <nombre> -n <ns>
kubectl describe node <nombre>
kubectl get events -n <ns> --sort-by=.lastTimestamp

# Logs
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -n <ns> --tail=50 -f

# Debug
kubectl exec -it <pod> -n <ns> -- sh
kubectl run debug --rm -it --restart=Never --image=busybox -- sh
kubectl debug -it <pod> --image=busybox --target=<container>

# Services
kubectl get endpoints <service> -n <ns>
kubectl get pods -n <ns> --show-labels
```

### Recursos Adicionales

- [Debugging Pods — Kubernetes.io](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Debugging Services — Kubernetes.io](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Debugging DNS Resolution — Kubernetes.io](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [kubectl describe Reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/)
- [Ephemeral Containers — Kubernetes.io](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/)
- [CoreDNS Troubleshooting Guide](https://coredns.io/plugins/kubernetes/)

---
