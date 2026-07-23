# Gestión de Deployments con escalamiento, rolling updates y rollback

## Metadatos

| Campo            | Valor                          |
|------------------|-------------------------------|
| **Duración**     | 67 minutos                    |
| **Complejidad**  | Alta                          |
| **Nivel Bloom**  | Aplicar (Apply)               |
| **Módulo**       | 2 — Objetos Core de Kubernetes |

---

## Descripción General

En este laboratorio gestionarás el ciclo de vida completo de un Deployment de Kubernetes: desde su creación con manifiestos YAML hasta operaciones avanzadas de escalamiento, rolling updates y rollback. Inspeccionarás los ReplicaSets generados automáticamente para comprender el mecanismo subyacente de actualización, y explorarás recursos adicionales de scheduling como DaemonSets, Jobs y CronJobs. Al finalizar, tendrás experiencia práctica con los patrones de gestión de workloads más utilizados en entornos Kubernetes reales y en el examen CKA.

---

## Objetivos de Aprendizaje

- [ ] Crear y gestionar Deployments comprendiendo su relación con ReplicaSets y Pods mediante la inspección de recursos generados automáticamente
- [ ] Ejecutar operaciones de escalamiento horizontal y rolling updates controlando parámetros de estrategia (`maxSurge`, `maxUnavailable`)
- [ ] Realizar rollback de Deployments a revisiones anteriores con `kubectl rollout undo` y verificar el historial de revisiones
- [ ] Aplicar labels y selectores para organizar recursos y demostrar cómo los controladores los utilizan para gestionar Pods
- [ ] Desplegar DaemonSets, Jobs y CronJobs, y aplicar `nodeSelector` con taints/tolerations para scheduling básico

---

## Prerrequisitos

### Conocimiento previo

- Haber completado el Laboratorio 01-00-01 (Pods, namespaces y comandos básicos de kubectl)
- Comprensión de la estructura YAML de Kubernetes: campos `apiVersion`, `kind`, `metadata` y `spec`
- Familiaridad con `kubectl get`, `kubectl describe` y `kubectl apply`
- Entender el modelo declarativo de Kubernetes y el concepto de estado deseado vs. estado actual

### Acceso requerido

- Clúster Minikube con **mínimo 2 nodos activos** (se recomienda 3 para DaemonSet)
- `kubectl` configurado y apuntando al clúster correcto
- Acceso a Internet para descargar imágenes `nginx:1.25` y `nginx:1.26`
- Directorio de trabajo con permisos de escritura para crear archivos YAML

---

## Entorno de Laboratorio

### Hardware recomendado

| Recurso    | Mínimo          | Recomendado     |
|------------|-----------------|-----------------|
| CPU        | 4 núcleos       | 8 núcleos       |
| RAM        | 8 GB            | 16 GB           |
| Disco      | 40 GB libres    | 60 GB libres    |
| Red        | 10 Mbps         | 25 Mbps         |

### Software requerido

| Herramienta | Versión mínima | Verificación                     |
|-------------|----------------|----------------------------------|
| Minikube    | 1.31.x         | `minikube version`               |
| kubectl     | 1.28.x         | `kubectl version --client`       |
| Docker      | 24.x           | `docker --version`               |

### Preparación del entorno

Ejecuta los siguientes comandos antes de comenzar el laboratorio. Si ya tienes un clúster de laboratorios anteriores con 2+ nodos, puedes omitir el paso de inicio.

```bash
# Verificar si Minikube ya está corriendo con los nodos necesarios
minikube status

# Si NO tienes clúster o necesitas uno nuevo con 3 nodos:
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que los nodos están Ready
kubectl get nodes

# Pre-descargar imágenes para evitar problemas de conectividad durante el lab
docker pull nginx:1.25
docker pull nginx:1.26
docker pull busybox:latest

# Cargar imágenes en los nodos de Minikube
minikube image load nginx:1.25
minikube image load nginx:1.26
minikube image load busybox:latest

# Crear directorio de trabajo para este laboratorio
mkdir -p ~/k8s-lab-02 && cd ~/k8s-lab-02
```

**Salida esperada de `kubectl get nodes`:**
```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

---

## Pasos del Laboratorio

---

### Paso 1: Crear un Deployment con manifiesto YAML y explorar los recursos generados

**Objetivo:** Crear un Deployment con 3 réplicas de `nginx:1.25` usando un manifiesto YAML y comprender la jerarquía Deployment → ReplicaSet → Pod.

**Instrucciones:**

1. Crea el archivo de manifiesto del Deployment:

```bash
cat > ~/k8s-lab-02/deployment-webapp.yaml << 'EOF'
# Deployment de aplicación web v1 con estrategia RollingUpdate explícita
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: default
  labels:
    app: webapp
    version: v1
    environment: lab
  annotations:
    kubernetes.io/change-cause: "Versión inicial v1 con nginx:1.25"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Máximo 1 Pod adicional durante la actualización
      maxUnavailable: 1     # Máximo 1 Pod no disponible durante la actualización
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
EOF
```

2. Aplica el manifiesto al clúster:

```bash
kubectl apply -f ~/k8s-lab-02/deployment-webapp.yaml
```

3. Observa la creación de los Pods en tiempo real:

```bash
kubectl get pods -l app=webapp -w
# Presiona Ctrl+C cuando todos los Pods estén en estado Running
```

4. Inspecciona la jerarquía completa de recursos creados:

```bash
# Ver el Deployment
kubectl get deployment webapp -o wide

# Ver el ReplicaSet generado automáticamente
kubectl get replicaset -l app=webapp

# Ver los Pods con sus nodos asignados
kubectl get pods -l app=webapp -o wide

# Describir el Deployment para ver eventos y configuración
kubectl describe deployment webapp
```

5. Examina la relación entre el Deployment y su ReplicaSet:

```bash
# Obtener el nombre del ReplicaSet (tendrá un hash al final)
RS_NAME=$(kubectl get rs -l app=webapp -o jsonpath='{.items[0].metadata.name}')
echo "ReplicaSet: $RS_NAME"

# Ver las anotaciones del ReplicaSet (contiene la spec del Pod template)
kubectl describe rs $RS_NAME

# Verificar que los Pods tienen el hash del ReplicaSet en su nombre
kubectl get pods -l app=webapp --show-labels
```

**Salida esperada:**

```
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
webapp                    3/3     3            3           60s

NAME                         DESIRED   CURRENT   READY   AGE
webapp-<hash>                3         3         3       60s

NAME                           READY   STATUS    RESTARTS   NODE
webapp-<hash>-<pod-hash-1>     1/1     Running   0          minikube
webapp-<hash>-<pod-hash-2>     1/1     Running   0          minikube-m02
webapp-<hash>-<pod-hash-3>     1/1     Running   0          minikube-m03
```

**Verificación:**

```bash
# Confirmar que el Deployment tiene 3/3 réplicas disponibles
kubectl get deployment webapp

# Confirmar que existe exactamente 1 ReplicaSet activo con 3 Pods
kubectl get rs -l app=webapp

# Verificar que el campo spec del Deployment coincide con lo definido
kubectl get deployment webapp -o yaml | grep -A 10 "strategy:"
```

> **Concepto clave:** El Deployment no gestiona Pods directamente. Crea un ReplicaSet con un hash basado en el template del Pod, y es el ReplicaSet quien mantiene el número deseado de réplicas. Este diseño es lo que permite el rolling update: durante una actualización coexisten dos ReplicaSets con diferentes versiones.

---

### Paso 2: Escalamiento horizontal — aumentar y reducir réplicas

**Objetivo:** Escalar el Deployment de 3 a 6 réplicas usando `kubectl scale`, y luego reducir a 2 réplicas actualizando el manifiesto YAML.

**Instrucciones:**

1. Escala el Deployment a 6 réplicas con el comando imperativo:

```bash
kubectl scale deployment webapp --replicas=6
```

2. Observa el escalamiento en tiempo real:

```bash
kubectl get pods -l app=webapp -w
# Espera hasta ver 6 Pods en Running, luego Ctrl+C
```

3. Verifica el estado del Deployment y el ReplicaSet:

```bash
kubectl get deployment webapp
kubectl get rs -l app=webapp
```

4. Ahora escala a 2 réplicas actualizando el manifiesto YAML (enfoque declarativo):

```bash
# Editar el manifiesto para cambiar replicas: 3 a replicas: 2
sed -i 's/replicas: 3/replicas: 2/' ~/k8s-lab-02/deployment-webapp.yaml

# Verificar el cambio en el archivo
grep "replicas:" ~/k8s-lab-02/deployment-webapp.yaml

# Aplicar el manifiesto actualizado
kubectl apply -f ~/k8s-lab-02/deployment-webapp.yaml
```

5. Confirma que el escalamiento descendente ocurrió:

```bash
kubectl get pods -l app=webapp
kubectl get deployment webapp
```

**Salida esperada tras escalar a 6:**
```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
webapp   6/6     6            6           3m
```

**Salida esperada tras reducir a 2:**
```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
webapp   2/2     2            2           5m
```

**Verificación:**

```bash
# Contar exactamente cuántos Pods están Running
kubectl get pods -l app=webapp --field-selector=status.phase=Running | grep -c Running

# Verificar que el ReplicaSet tiene DESIRED=2
kubectl get rs -l app=webapp
```

> **Nota:** Al escalar hacia abajo, Kubernetes termina Pods de forma ordenada respetando el `terminationGracePeriodSeconds`. El ReplicaSet siempre mantiene el estado deseado. Observa que el número de ReplicaSets no cambia con el escalamiento — solo cambia el campo `replicas` del ReplicaSet existente.

---

### Paso 3: Rolling Update — actualizar a nginx:1.26 y observar el proceso

**Objetivo:** Realizar una rolling update de `nginx:1.25` a `nginx:1.26`, observar el proceso en tiempo real e inspeccionar los ReplicaSets creados durante la transición.

**Instrucciones:**

1. Antes de actualizar, escala el Deployment a 4 réplicas para observar mejor el proceso:

```bash
kubectl scale deployment webapp --replicas=4
kubectl get pods -l app=webapp
```

2. En una terminal separada (o usa `tmux`/`screen`), inicia la observación en tiempo real:

```bash
# Terminal 2: observar Pods durante la actualización
kubectl get pods -l app=webapp -w
```

3. En la terminal principal, ejecuta la rolling update con `kubectl set image`:

```bash
# Actualizar la imagen del contenedor "nginx" a la versión 1.26
kubectl set image deployment/webapp nginx=nginx:1.26

# Inmediatamente observar el estado del rollout
kubectl rollout status deployment/webapp
```

4. Mientras el rollout ocurre (o después), inspecciona los dos ReplicaSets coexistentes:

```bash
# Ver TODOS los ReplicaSets del Deployment (el viejo y el nuevo)
kubectl get rs -l app=webapp

# Describir ambos ReplicaSets para ver qué imagen usa cada uno
kubectl describe rs -l app=webapp | grep -E "Name:|Image:|Replicas:"
```

5. Actualiza también el manifiesto YAML para mantener sincronía entre código y clúster:

```bash
# Actualizar el manifiesto con la nueva imagen y anotación
cat > ~/k8s-lab-02/deployment-webapp.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: default
  labels:
    app: webapp
    version: v2
    environment: lab
  annotations:
    kubernetes.io/change-cause: "Actualización a nginx:1.26 - versión v2"
spec:
  replicas: 4
  selector:
    matchLabels:
      app: webapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: webapp
        version: v2
    spec:
      containers:
        - name: nginx
          image: nginx:1.26
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
EOF
```

6. Verifica la imagen activa en los Pods:

```bash
# Confirmar que todos los Pods usan nginx:1.26
kubectl get pods -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

**Salida esperada de `kubectl rollout status`:**
```
Waiting for deployment "webapp" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "webapp" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "webapp" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "webapp" rollout to finish: 3 of 4 updated replicas are available...
deployment "webapp" successfully rolled out
```

**Salida esperada de `kubectl get rs`:**
```
NAME                    DESIRED   CURRENT   READY   AGE
webapp-<hash-v1>        0         0         0       8m    ← ReplicaSet v1 (retenido)
webapp-<hash-v2>        4         4         4       2m    ← ReplicaSet v2 (activo)
```

**Verificación:**

```bash
# Verificar que el Deployment reporta la imagen correcta
kubectl describe deployment webapp | grep Image

# Verificar que el ReplicaSet v1 tiene 0 réplicas (retenido para rollback)
kubectl get rs -l app=webapp

# Confirmar que el rollout está completo
kubectl rollout status deployment/webapp
```

> **Concepto clave:** Durante el rolling update, el Deployment crea un **nuevo ReplicaSet** para la versión v2 y va aumentando sus réplicas mientras reduce las del ReplicaSet v1. Los parámetros `maxSurge: 1` y `maxUnavailable: 1` controlan la velocidad y disponibilidad durante la transición. El ReplicaSet v1 se conserva con 0 réplicas para posibilitar el rollback.

---

### Paso 4: Historial de revisiones y Rollback a v1

**Objetivo:** Inspeccionar el historial de revisiones del Deployment y ejecutar un rollback a la versión anterior usando `kubectl rollout undo`.

**Instrucciones:**

1. Consulta el historial completo de revisiones del Deployment:

```bash
# Ver todas las revisiones disponibles
kubectl rollout history deployment/webapp
```

2. Inspecciona el detalle de cada revisión:

```bash
# Ver la revisión 1 (nginx:1.25)
kubectl rollout history deployment/webapp --revision=1

# Ver la revisión 2 (nginx:1.26)
kubectl rollout history deployment/webapp --revision=2
```

3. Ejecuta el rollback a la revisión anterior (v1 con nginx:1.25):

```bash
kubectl rollout undo deployment/webapp
```

4. Observa el proceso de rollback:

```bash
kubectl rollout status deployment/webapp
```

5. Verifica que el rollback fue exitoso:

```bash
# Confirmar imagen activa
kubectl get pods -l app=webapp -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Ver el historial actualizado (la revisión anterior ahora es la más reciente)
kubectl rollout history deployment/webapp

# Ver los ReplicaSets: ahora el RS de v1 tiene réplicas activas
kubectl get rs -l app=webapp
```

6. (Opcional) Practica rollback a una revisión específica:

```bash
# Volver a aplicar la versión v2 para tener más revisiones en el historial
kubectl set image deployment/webapp nginx=nginx:1.26
kubectl rollout status deployment/webapp

# Ahora hacer rollback a una revisión específica (la 1)
kubectl rollout undo deployment/webapp --to-revision=1
kubectl rollout status deployment/webapp

# Verificar historial final
kubectl rollout history deployment/webapp
```

**Salida esperada de `kubectl rollout history`:**
```
REVISION  CHANGE-CAUSE
1         Versión inicial v1 con nginx:1.25
2         Actualización a nginx:1.26 - versión v2
```

> **Nota:** El campo `CHANGE-CAUSE` se llena gracias a la anotación `kubernetes.io/change-cause` definida en el manifiesto. Sin esta anotación, el historial mostrará `<none>`.

**Verificación:**

```bash
# Confirmar que la imagen activa es nginx:1.25 (rollback exitoso)
kubectl describe deployment webapp | grep "Image:"

# Confirmar que el RS de v1 ahora tiene 4 réplicas activas
kubectl get rs -l app=webapp

# Confirmar que el Deployment está healthy
kubectl get deployment webapp
```

---

### Paso 5: Labels, selectores y organización de recursos

**Objetivo:** Demostrar cómo los labels y selectores permiten a los controladores gestionar Pods, y practicar consultas avanzadas con `matchExpressions`.

**Instrucciones:**

1. Crea un segundo Deployment con labels diferenciados para simular múltiples servicios:

```bash
cat > ~/k8s-lab-02/deployment-api.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: default
  labels:
    app: api-service
    tier: backend
    environment: lab
  annotations:
    kubernetes.io/change-cause: "API service inicial"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-service
      tier: backend
  template:
    metadata:
      labels:
        app: api-service
        tier: backend
        version: v1
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

kubectl apply -f ~/k8s-lab-02/deployment-api.yaml
```

2. Practica consultas con diferentes selectores de labels:

```bash
# Listar todos los Pods con label app=webapp
kubectl get pods -l app=webapp

# Listar todos los Pods con label tier=backend
kubectl get pods -l tier=backend

# Listar todos los Pods con label environment=lab (ambos Deployments)
kubectl get pods -l environment=lab

# Listar Pods que NO son del tier frontend (usando operador !=)
kubectl get pods -l 'tier!=frontend'

# Listar Pods cuyo app esté en un conjunto de valores (operador In)
kubectl get pods -l 'app in (webapp, api-service)'

# Listar todos los recursos con label environment=lab en todos los tipos
kubectl get all -l environment=lab
```

3. Crea un Service que use `matchExpressions` para selección avanzada:

```bash
cat > ~/k8s-lab-02/service-webapp.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: default
  labels:
    app: webapp
spec:
  selector:
    app: webapp          # Solo los Pods con este label recibirán tráfico
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

kubectl apply -f ~/k8s-lab-02/service-webapp.yaml
```

4. Verifica que el Service seleccionó los Pods correctos:

```bash
# Ver los Endpoints del Service (IPs de los Pods seleccionados)
kubectl get endpoints webapp-svc

# Comparar con las IPs de los Pods del Deployment webapp
kubectl get pods -l app=webapp -o wide
```

**Verificación:**

```bash
# Confirmar que los Endpoints del Service coinciden con las IPs de los Pods
kubectl describe service webapp-svc | grep -A 5 "Endpoints:"

# Verificar que los Pods del api-service NO aparecen como endpoints
kubectl get endpoints webapp-svc -o yaml | grep -c "ip:"
```

> **Concepto clave:** Los selectores son el mecanismo fundamental que conecta los controladores (Deployments, ReplicaSets) con sus Pods, y los Services con sus Pods destino. Un Pod que pierda sus labels deja de ser gestionado por el controlador — útil para debugging en producción.

---

### Paso 6: DaemonSet — despliegue en todos los nodos

**Objetivo:** Crear un DaemonSet y observar cómo despliega automáticamente un Pod en cada nodo del clúster.

**Instrucciones:**

1. Crea el manifiesto del DaemonSet:

```bash
cat > ~/k8s-lab-02/daemonset-monitor.yaml << 'EOF'
# DaemonSet que despliega un agente de monitoreo en cada nodo del clúster
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
  namespace: default
  labels:
    app: node-monitor
    tier: monitoring
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
        tier: monitoring
    spec:
      tolerations:
        # Permite que el DaemonSet se ejecute también en el nodo control-plane
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: monitor
          image: busybox:latest
          command: ["/bin/sh", "-c", "while true; do echo 'Monitoring node: '$(hostname) && sleep 30; done"]
          resources:
            requests:
              cpu: "10m"
              memory: "16Mi"
            limits:
              cpu: "50m"
              memory: "32Mi"
EOF

kubectl apply -f ~/k8s-lab-02/daemonset-monitor.yaml
```

2. Observa que se crea un Pod por nodo:

```bash
# Esperar a que los Pods estén Running
kubectl get pods -l app=node-monitor -w
# Ctrl+C cuando estén todos Running
```

3. Verifica la distribución en los nodos:

```bash
# Ver en qué nodo está cada Pod del DaemonSet
kubectl get pods -l app=node-monitor -o wide

# Contar nodos y comparar con número de Pods del DaemonSet
echo "Nodos en el clúster:"
kubectl get nodes --no-headers | wc -l

echo "Pods del DaemonSet:"
kubectl get pods -l app=node-monitor --no-headers | wc -l

# Describir el DaemonSet
kubectl describe daemonset node-monitor
```

4. Verifica los logs de un Pod del DaemonSet:

```bash
# Obtener nombre del primer Pod
DS_POD=$(kubectl get pods -l app=node-monitor -o jsonpath='{.items[0].metadata.name}')
kubectl logs $DS_POD
```

**Salida esperada:**
```
NAME                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
node-monitor        3         3         3       3            3           <none>          60s
```

**Verificación:**

```bash
# Confirmar que el número de Pods del DaemonSet = número de nodos
NODES=$(kubectl get nodes --no-headers | wc -l)
DS_PODS=$(kubectl get pods -l app=node-monitor --no-headers | grep Running | wc -l)
echo "Nodos: $NODES | Pods DaemonSet: $DS_PODS"
[ "$NODES" -eq "$DS_PODS" ] && echo "✓ DaemonSet correcto" || echo "✗ Revisar DaemonSet"
```

---

### Paso 7: Job y CronJob — tareas batch

**Objetivo:** Crear un Job de cómputo simple y un CronJob programado, observando su comportamiento de ejecución hasta completar.

**Instrucciones:**

1. Crea un Job que ejecuta un cálculo simple:

```bash
cat > ~/k8s-lab-02/job-compute.yaml << 'EOF'
# Job que ejecuta un cálculo y termina exitosamente
apiVersion: batch/v1
kind: Job
metadata:
  name: compute-pi
  namespace: default
  labels:
    app: compute-pi
    type: batch-job
spec:
  completions: 3          # Ejecutar 3 veces hasta completar
  parallelism: 2          # Máximo 2 ejecuciones en paralelo
  backoffLimit: 2         # Reintentos en caso de fallo
  template:
    metadata:
      labels:
        app: compute-pi
    spec:
      restartPolicy: Never   # Los Jobs usan Never o OnFailure, nunca Always
      containers:
        - name: pi-calculator
          image: busybox:latest
          command:
            - /bin/sh
            - -c
            - |
              echo "Iniciando cálculo en $(hostname)"
              # Simular cómputo con una pausa
              sleep 5
              echo "Resultado: Pi ≈ 3.14159265358979"
              echo "Cálculo completado exitosamente"
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
EOF

kubectl apply -f ~/k8s-lab-02/job-compute.yaml
```

2. Observa la ejecución del Job:

```bash
# Ver el estado del Job
kubectl get job compute-pi -w
# Ctrl+C cuando COMPLETIONS muestre 3/3

# Ver los Pods creados por el Job
kubectl get pods -l app=compute-pi

# Ver los logs del Job
kubectl logs -l app=compute-pi --prefix
```

3. Crea un CronJob que se ejecuta cada minuto:

```bash
cat > ~/k8s-lab-02/cronjob-report.yaml << 'EOF'
# CronJob que genera un reporte cada minuto (para demostración)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-report
  namespace: default
  labels:
    app: health-report
    type: scheduled-job
spec:
  schedule: "*/1 * * * *"          # Cada minuto
  successfulJobsHistoryLimit: 3    # Conservar últimos 3 Jobs exitosos
  failedJobsHistoryLimit: 1        # Conservar último Job fallido
  concurrencyPolicy: Forbid        # No ejecutar si ya hay uno corriendo
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: health-report
        spec:
          restartPolicy: OnFailure
          containers:
            - name: reporter
              image: busybox:latest
              command:
                - /bin/sh
                - -c
                - echo "Health Report - $(date) - Clúster OK"
              resources:
                requests:
                  cpu: "10m"
                  memory: "16Mi"
EOF

kubectl apply -f ~/k8s-lab-02/cronjob-report.yaml
```

4. Espera y observa la ejecución del CronJob:

```bash
# Ver el CronJob creado
kubectl get cronjob health-report

# Esperar ~1 minuto y ver los Jobs generados
kubectl get jobs -l app=health-report

# Ver los Pods creados por el CronJob
kubectl get pods -l app=health-report
```

**Salida esperada del Job:**
```
NAME          COMPLETIONS   DURATION   AGE
compute-pi    3/3           25s        45s
```

**Salida esperada del CronJob:**
```
NAME            SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
health-report   */1 * * * *   False     0        45s             2m
```

**Verificación:**

```bash
# Verificar que el Job completó las 3 ejecuciones
kubectl get job compute-pi -o jsonpath='{.status.succeeded}'

# Verificar que el CronJob ha generado al menos 1 Job
kubectl get jobs -l app=health-report --no-headers | wc -l
```

---

### Paso 8: nodeSelector, Taints y Tolerations para scheduling básico

**Objetivo:** Aplicar `nodeSelector` para dirigir Pods a nodos específicos y configurar taints/tolerations para controlar qué Pods pueden ejecutarse en qué nodos.

**Instrucciones:**

1. Añade un label personalizado a uno de los worker nodes:

```bash
# Listar nodos y sus labels actuales
kubectl get nodes --show-labels

# Añadir label al segundo nodo (worker)
kubectl label node minikube-m02 disk-type=ssd

# Verificar el label
kubectl get node minikube-m02 --show-labels | grep disk-type
```

2. Crea un Deployment que use `nodeSelector` para correr solo en nodos con `disk-type=ssd`:

```bash
cat > ~/k8s-lab-02/deployment-nodeselector.yaml << 'EOF'
# Deployment que requiere nodos con label disk-type=ssd
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ssd-webapp
  namespace: default
  labels:
    app: ssd-webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ssd-webapp
  template:
    metadata:
      labels:
        app: ssd-webapp
    spec:
      nodeSelector:
        disk-type: ssd        # Solo en nodos con este label
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
EOF

kubectl apply -f ~/k8s-lab-02/deployment-nodeselector.yaml
```

3. Verifica que los Pods se programaron en el nodo correcto:

```bash
# Todos los Pods deben estar en minikube-m02
kubectl get pods -l app=ssd-webapp -o wide
```

4. Aplica un taint al tercer nodo para demostrar la exclusión:

```bash
# Aplicar taint al nodo m03: ningún Pod sin toleration podrá ejecutarse aquí
kubectl taint node minikube-m03 workload=gpu:NoSchedule

# Verificar el taint
kubectl describe node minikube-m03 | grep -A 3 "Taints:"
```

5. Crea un Deployment sin toleration (los Pods NO deben ir a minikube-m03):

```bash
kubectl create deployment no-toleration --image=nginx:1.25 --replicas=3
kubectl get pods -l app=no-toleration -o wide
# Verificar: ningún Pod debe estar en minikube-m03
```

6. Crea un Deployment CON toleration que sí puede ir a minikube-m03:

```bash
cat > ~/k8s-lab-02/deployment-toleration.yaml << 'EOF'
# Deployment que tolera el taint workload=gpu:NoSchedule
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-webapp
  namespace: default
  labels:
    app: gpu-webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gpu-webapp
  template:
    metadata:
      labels:
        app: gpu-webapp
    spec:
      tolerations:
        - key: "workload"
          operator: "Equal"
          value: "gpu"
          effect: "NoSchedule"    # Tolera el taint específico
      containers:
        - name: nginx
          image: nginx:1.25
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
EOF

kubectl apply -f ~/k8s-lab-02/deployment-toleration.yaml
```

7. Verifica que los Pods con toleration pueden ejecutarse en minikube-m03:

```bash
# Estos Pods SÍ pueden ir a minikube-m03 (aunque también pueden ir a otros nodos)
kubectl get pods -l app=gpu-webapp -o wide
```

**Verificación:**

```bash
# Confirmar que ssd-webapp solo está en minikube-m02
kubectl get pods -l app=ssd-webapp -o wide | grep -v "minikube-m02" | grep -v "NAME"
# La salida debe estar vacía (todos en m02)

# Confirmar que no-toleration no tiene Pods en minikube-m03
kubectl get pods -l app=no-toleration -o wide | grep "minikube-m03"
# La salida debe estar vacía

# Confirmar que gpu-webapp puede tener Pods en minikube-m03
kubectl get pods -l app=gpu-webapp -o wide
```

---

## Validación y Pruebas Finales

Ejecuta esta secuencia de comandos de validación completa para confirmar que todos los objetivos del laboratorio fueron cumplidos:

```bash
echo "============================================"
echo "VALIDACIÓN FINAL - LAB 02-00-01"
echo "============================================"

echo ""
echo "--- 1. Deployment webapp con rolling update completado ---"
kubectl get deployment webapp -o jsonpath='Image: {.spec.template.spec.containers[0].image}{"\n"}'
kubectl get deployment webapp -o jsonpath='Replicas: {.status.readyReplicas}/{.spec.replicas}{"\n"}'

echo ""
echo "--- 2. ReplicaSets del Deployment webapp ---"
kubectl get rs -l app=webapp

echo ""
echo "--- 3. Historial de revisiones ---"
kubectl rollout history deployment/webapp

echo ""
echo "--- 4. DaemonSet ejecutando en todos los nodos ---"
kubectl get daemonset node-monitor
kubectl get pods -l app=node-monitor -o wide

echo ""
echo "--- 5. Job completado ---"
kubectl get job compute-pi -o jsonpath='Completions: {.status.succeeded}/3{"\n"}'

echo ""
echo "--- 6. CronJob activo ---"
kubectl get cronjob health-report

echo ""
echo "--- 7. nodeSelector - Pods en nodo con label disk-type=ssd ---"
kubectl get pods -l app=ssd-webapp -o wide

echo ""
echo "--- 8. Taint en minikube-m03 ---"
kubectl describe node minikube-m03 | grep "Taints:"

echo ""
echo "--- 9. Todos los Deployments en el namespace default ---"
kubectl get deployments

echo ""
echo "============================================"
echo "VALIDACIÓN COMPLETADA"
echo "============================================"
```

### Prueba de conectividad del Service

```bash
# Verificar que el Service webapp-svc tiene Endpoints activos
kubectl get endpoints webapp-svc

# Probar conectividad desde un Pod temporal al Service
kubectl run test-curl --image=busybox:latest --rm -it --restart=Never -- \
  wget -qO- http://webapp-svc:80 2>/dev/null | head -5 || \
  echo "Nota: Respuesta recibida del Service webapp-svc"
```

---

## Troubleshooting

### Problema 1: Los Pods del Deployment quedan en estado `Pending` indefinidamente

**Síntomas:**
```
NAME                      READY   STATUS    RESTARTS   AGE
webapp-<hash>-<id>        0/1     Pending   0          5m
```
Al ejecutar `kubectl describe pod <nombre-pod>`, el campo `Events` muestra:
```
Warning  FailedScheduling  ...  0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector
```

**Causa:**
El `nodeSelector` especificado en el Pod template no coincide con ningún nodo disponible. Esto ocurre cuando se aplica un label a un nodo y luego se elimina, o cuando el nombre del nodo en el `nodeSelector` tiene un typo. También puede ocurrir si el nodo con el label requerido tiene taints que el Pod no tolera.

**Solución:**

```bash
# 1. Verificar qué nodeSelector tiene el Pod
kubectl describe pod <nombre-pod> | grep -A 3 "Node-Selectors:"

# 2. Verificar los labels actuales de los nodos
kubectl get nodes --show-labels

# 3. Si falta el label, volver a añadirlo al nodo correcto
kubectl label node minikube-m02 disk-type=ssd

# 4. Si el problema persiste, verificar taints en los nodos
kubectl describe nodes | grep -A 3 "Taints:"

# 5. Verificar que el Deployment no tiene un nodeSelector incorrecto
kubectl get deployment ssd-webapp -o yaml | grep -A 5 "nodeSelector:"

# 6. Corregir el manifiesto si es necesario y volver a aplicar
kubectl apply -f ~/k8s-lab-02/deployment-nodeselector.yaml
```

---

### Problema 2: El rolling update se queda atascado y `kubectl rollout status` no avanza

**Síntomas:**
```
Waiting for deployment "webapp" rollout to finish: 1 out of 4 new replicas have been updated...
# El comando no avanza después de varios minutos
```
Al ejecutar `kubectl get pods -l app=webapp`, aparecen Pods en estado `ImagePullBackOff` o `ErrImagePull`.

**Causa:**
La imagen especificada en el `set image` no existe en el registro, tiene un tag incorrecto o no hay conectividad para descargarla. El Deployment intenta crear Pods con la nueva imagen pero fallan al arrancar, y como `maxUnavailable: 1`, no puede terminar los Pods viejos hasta que los nuevos estén disponibles — creando un bloqueo.

**Solución:**

```bash
# 1. Identificar el Pod con error
kubectl get pods -l app=webapp

# 2. Describir el Pod fallido para ver el error exacto
kubectl describe pod <nombre-pod-fallido> | grep -A 10 "Events:"

# 3. Verificar que la imagen existe y está accesible
docker pull nginx:1.26   # Probar descarga manual

# 4. Si la imagen es incorrecta, hacer rollback inmediato
kubectl rollout undo deployment/webapp

# 5. Verificar que el rollback fue exitoso
kubectl rollout status deployment/webapp

# 6. Corregir el nombre/tag de la imagen y volver a aplicar
kubectl set image deployment/webapp nginx=nginx:1.26
# O aplicar el manifiesto corregido:
kubectl apply -f ~/k8s-lab-02/deployment-webapp.yaml

# 7. Si el rollout sigue atascado y necesitas forzar la cancelación:
kubectl rollout pause deployment/webapp
kubectl rollout undo deployment/webapp
kubectl rollout resume deployment/webapp
```

---

## Limpieza del Entorno

Ejecuta los siguientes comandos para limpiar los recursos creados en este laboratorio. **Omite este paso si planeas continuar con el Laboratorio 03-00-01**, ya que algunos recursos pueden ser reutilizados.

```bash
echo "Iniciando limpieza del Lab 02-00-01..."

# Eliminar Deployments creados
kubectl delete deployment webapp api-service ssd-webapp gpu-webapp no-toleration --ignore-not-found

# Eliminar DaemonSet
kubectl delete daemonset node-monitor --ignore-not-found

# Eliminar Job y CronJob
kubectl delete job compute-pi --ignore-not-found
kubectl delete cronjob health-report --ignore-not-found

# Eliminar Service
kubectl delete service webapp-svc --ignore-not-found

# Eliminar labels añadidos a los nodos
kubectl label node minikube-m02 disk-type- --ignore-not-found

# Eliminar taint del nodo m03
kubectl taint node minikube-m03 workload=gpu:NoSchedule- --ignore-not-found

# Verificar que no quedan recursos del lab
echo ""
echo "Recursos restantes en namespace default:"
kubectl get all -n default

# Opcional: limpiar directorio de trabajo
# rm -rf ~/k8s-lab-02

echo "Limpieza completada."
```

> **Importante:** NO ejecutes `minikube delete`. Usa `minikube stop` si necesitas detener el clúster temporalmente para conservar la configuración para laboratorios futuros.

---

## Resumen

En este laboratorio completaste el ciclo de vida completo de gestión de Deployments en Kubernetes:

| Operación | Comando/Recurso clave | Concepto aprendido |
|---|---|---|
| Crear Deployment | `kubectl apply -f deployment.yaml` | Relación Deployment → ReplicaSet → Pod |
| Escalar réplicas | `kubectl scale` / `replicas:` en YAML | Escalamiento imperativo vs. declarativo |
| Rolling Update | `kubectl set image` / `kubectl rollout status` | Coexistencia de ReplicaSets durante actualización |
| Rollback | `kubectl rollout undo` | Retención de ReplicaSets para reversión |
| Historial | `kubectl rollout history` | Anotación `change-cause` |
| DaemonSet | `apiVersion: apps/v1, kind: DaemonSet` | Un Pod por nodo, tolerations para control-plane |
| Job | `completions`, `parallelism`, `restartPolicy: Never` | Tareas batch con ejecución garantizada |
| CronJob | `schedule: "*/1 * * * *"` | Programación de tareas recurrentes |
| nodeSelector | `spec.nodeSelector:` | Afinidad de nodo por label |
| Taints/Tolerations | `kubectl taint` / `spec.tolerations:` | Exclusión y admisión selectiva de Pods |

### Puntos clave para recordar

- Un **Deployment** nunca gestiona Pods directamente — siempre lo hace a través de un **ReplicaSet**
- Durante un rolling update coexisten **dos ReplicaSets**: el antiguo escala a 0 pero se conserva para posibilitar el rollback
- Los parámetros `maxSurge` y `maxUnavailable` controlan el balance entre velocidad de actualización y disponibilidad del servicio
- Los **labels** son el mecanismo universal de selección en Kubernetes: los usan Deployments, Services, NetworkPolicies y más
- Un **DaemonSet** garantiza exactamente un Pod por nodo elegible; los **Jobs** garantizan que una tarea se complete N veces
- Los **taints** repelen Pods; las **tolerations** permiten que Pods específicos ignoren esos taints

### Recursos adicionales

- [Documentación oficial: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Documentación oficial: DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Documentación oficial: Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Documentación oficial: Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [kubectl Cheat Sheet — Rollout commands](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#interacting-with-deployments-and-services)
- [The Kubernetes Book — Nigel Poulton (2024)](https://nigelpoulton.com/books/)

---

---

# Práctica complementaria 2.1: Labels, Selectors y ReplicaSets

## 1. Metadatos

| Campo | Valor |
|---|---|
| **Duración estimada** | 22 minutos |
| **Complejidad** | Fácil |
| **Nivel Bloom** | Aplicar |
| **Módulo** | 2 — Objetos fundamentales de Kubernetes |
| **Lab ID** | 02-00-02 |

---

## 2. Descripción General

En este laboratorio explorarás la mecánica de **labels y selectores**, el mecanismo central que Kubernetes utiliza para vincular controladores con los recursos que gestionan. Crearás Pods y un ReplicaSet standalone con múltiples labels, practicarás consultas con operadores de igualdad y de conjunto, y realizarás un experimento clave: modificar manualmente el label de un Pod gestionado por un ReplicaSet para observar cómo el controlador de reconciliación reacciona en tiempo real. También explorarás la diferencia conceptual y práctica entre labels y annotations.

---

## 3. Objetivos de Aprendizaje

- [ ] Aplicar labels múltiples a Pods y recursos Kubernetes, y filtrarlos con `kubectl get -l` usando operadores de igualdad (`=`, `!=`) y de conjunto (`in`, `notin`, `exists`)
- [ ] Crear un ReplicaSet standalone (sin Deployment) y comprender cómo usa `matchLabels` y `matchExpressions` para seleccionar sus Pods
- [ ] Demostrar el bucle de reconciliación del ReplicaSet al remover y restaurar manualmente el label selector de un Pod gestionado
- [ ] Distinguir el propósito y las restricciones de uso de labels versus annotations en manifiestos Kubernetes

---

## 4. Prerrequisitos

### Conocimiento previo

| Requisito | Descripción |
|---|---|
| Lab 02-00-01 completado | Familiaridad con Pods, Deployments y ReplicaSets básicos |
| Estructura de manifiestos YAML | Comprensión de `apiVersion`, `kind`, `metadata`, `spec` |
| Uso básico de `kubectl` | `apply`, `get`, `describe`, `delete` |
| Clúster Minikube operativo | Iniciado con al menos 1 nodo (idealmente 3) |

### Acceso requerido

| Recurso | Estado requerido |
|---|---|
| Clúster Minikube | Running (`minikube status`) |
| Namespace `lab-labels` | Se crea en el paso 1 |
| Conexión a Internet | Necesaria si `nginx:1.25` y `busybox:latest` no están en caché local |

---

## 5. Entorno de Laboratorio

### Hardware recomendado

| Componente | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 núcleos | 8 núcleos |
| RAM | 8 GB | 16 GB |
| Almacenamiento libre | 40 GB | 60 GB |

### Software requerido

| Herramienta | Versión mínima | Verificación |
|---|---|---|
| `kubectl` | 1.28.x | `kubectl version --client` |
| Minikube | 1.31.x | `minikube version` |
| Docker Engine | 24.x | `docker version` |

### Preparación del entorno

Antes de comenzar, verifica que el clúster esté operativo y pre-descarga las imágenes necesarias:

```bash
# 1. Verificar estado del clúster
minikube status

# 2. Verificar conectividad con el API Server
kubectl cluster-info

# 3. Pre-descargar imágenes para evitar demoras durante el lab
# (ejecutar en el contexto de Minikube si usas driver Docker)
docker pull nginx:1.25
docker pull busybox:latest

# Si usas Minikube con driver Docker, cargar imágenes al nodo:
minikube image load nginx:1.25
minikube image load busybox:latest
```

> **Nota para macOS/Windows con WSL2:** Si usas el driver Docker de Minikube, los comandos `kubectl` funcionan igual. El acceso a NodePort requiere `minikube service <name> --url`, pero en este laboratorio no se exponen servicios externos.

---

## 6. Pasos del Laboratorio

---

### Paso 1: Crear el Namespace de trabajo y Pods con múltiples labels

**Objetivo:** Establecer un namespace aislado y crear Pods con múltiples labels que representen distintas dimensiones de clasificación (`app`, `version`, `env`, `tier`).

#### Instrucciones

**1.1** Crea el namespace `lab-labels` donde trabajarás durante todo el laboratorio:

```bash
kubectl create namespace lab-labels
```

**1.2** Crea el archivo `pods-multi-label.yaml` con tres Pods, cada uno con una combinación diferente de labels:

```yaml
# pods-multi-label.yaml
# Tres Pods con combinaciones variadas de labels para practicar selectores
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-frontend-v1
  namespace: lab-labels
  labels:
    app: tienda          # Nombre de la aplicación
    version: "v1"        # Versión del componente
    env: production      # Entorno de ejecución
    tier: frontend       # Capa de la aplicación
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-frontend-v2
  namespace: lab-labels
  labels:
    app: tienda
    version: "v2"
    env: staging
    tier: frontend
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-backend-v1
  namespace: lab-labels
  labels:
    app: tienda
    version: "v1"
    env: production
    tier: backend
spec:
  containers:
    - name: busybox
      image: busybox:latest
      command: ["sh", "-c", "while true; do sleep 3600; done"]
```

**1.3** Aplica el manifiesto:

```bash
kubectl apply -f pods-multi-label.yaml
```

**1.4** Verifica que los tres Pods estén en estado `Running`:

```bash
kubectl get pods -n lab-labels --show-labels
```

#### Salida esperada

```
NAME               READY   STATUS    RESTARTS   AGE   LABELS
pod-backend-v1     1/1     Running   0          30s   app=tienda,env=production,tier=backend,version=v1
pod-frontend-v1    1/1     Running   0          30s   app=tienda,env=production,tier=frontend,version=v1
pod-frontend-v2    1/1     Running   0          30s   app=tienda,env=staging,tier=frontend,version=v2
```

#### Verificación

```bash
# Confirmar que los 3 Pods tienen exactamente 4 labels cada uno
kubectl get pods -n lab-labels --show-labels | grep -c "app=tienda"
# Resultado esperado: 3
```

---

### Paso 2: Practicar selectores de igualdad (equality-based)

**Objetivo:** Utilizar los operadores de igualdad `=` (o `==`) y `!=` para filtrar Pods según sus labels con `kubectl get -l`.

#### Instrucciones

**2.1** Selecciona todos los Pods con `env=production`:

```bash
kubectl get pods -n lab-labels -l env=production
```

**2.2** Selecciona todos los Pods con `tier=frontend`:

```bash
kubectl get pods -n lab-labels -l tier=frontend
```

**2.3** Combina dos condiciones de igualdad (AND lógico separando con coma):

```bash
# Pods que son frontend Y están en production
kubectl get pods -n lab-labels -l tier=frontend,env=production
```

**2.4** Usa el operador de desigualdad `!=` para excluir Pods en staging:

```bash
# Pods cuyo env NO es staging
kubectl get pods -n lab-labels -l env!=staging
```

**2.5** Combina igualdad y desigualdad:

```bash
# Pods de la app "tienda" que NO son backend
kubectl get pods -n lab-labels -l app=tienda,tier!=backend
```

#### Salida esperada

```bash
# Paso 2.1 — env=production
NAME               READY   STATUS    RESTARTS   AGE
pod-backend-v1     1/1     Running   0          2m
pod-frontend-v1    1/1     Running   0          2m

# Paso 2.2 — tier=frontend
NAME               READY   STATUS    RESTARTS   AGE
pod-frontend-v1    1/1     Running   0          2m
pod-frontend-v2    1/1     Running   0          2m

# Paso 2.3 — tier=frontend,env=production
NAME               READY   STATUS    RESTARTS   AGE
pod-frontend-v1    1/1     Running   0          2m

# Paso 2.4 — env!=staging
NAME               READY   STATUS    RESTARTS   AGE
pod-backend-v1     1/1     Running   0          2m
pod-frontend-v1    1/1     Running   0          2m

# Paso 2.5 — app=tienda,tier!=backend
NAME               READY   STATUS    RESTARTS   AGE
pod-frontend-v1    1/1     Running   0          2m
pod-frontend-v2    1/1     Running   0          2m
```

#### Verificación

```bash
# El selector combinado debe retornar exactamente 1 Pod
kubectl get pods -n lab-labels -l tier=frontend,env=production --no-headers | wc -l
# Resultado esperado: 1
```

---

### Paso 3: Practicar selectores de conjunto (set-based)

**Objetivo:** Utilizar los operadores `in`, `notin` y `exists` para consultas más expresivas que los operadores de igualdad.

#### Instrucciones

**3.1** Usa `in` para seleccionar Pods cuyo `env` sea `production` o `staging`:

```bash
kubectl get pods -n lab-labels -l 'env in (production, staging)'
```

**3.2** Usa `notin` para excluir Pods cuya `version` sea `v2`:

```bash
kubectl get pods -n lab-labels -l 'version notin (v2)'
```

**3.3** Usa `exists` para seleccionar todos los Pods que tengan el label `tier` (sin importar su valor):

```bash
kubectl get pods -n lab-labels -l 'tier'
```

**3.4** Combina `in` y `exists` en una misma consulta:

```bash
# Pods que tienen el label "tier" Y cuyo "env" sea production o staging
kubectl get pods -n lab-labels -l 'tier,env in (production, staging)'
```

**3.5** Verifica que los operadores de conjunto funcionan también con `kubectl delete` (sin ejecutar el delete, solo observa la sintaxis):

```bash
# SOLO LECTURA — no ejecutar el delete; sirve para ver qué Pods se eliminarían
kubectl get pods -n lab-labels -l 'env in (staging)' --show-labels
```

#### Salida esperada

```bash
# Paso 3.1 — env in (production, staging) → los 3 Pods
NAME               READY   STATUS    RESTARTS   AGE
pod-backend-v1     1/1     Running   0          4m
pod-frontend-v1    1/1     Running   0          4m
pod-frontend-v2    1/1     Running   0          4m

# Paso 3.2 — version notin (v2) → los 2 Pods v1
NAME               READY   STATUS    RESTARTS   AGE
pod-backend-v1     1/1     Running   0          4m
pod-frontend-v1    1/1     Running   0          4m

# Paso 3.3 — exists "tier" → los 3 Pods
NAME               READY   STATUS    RESTARTS   AGE
pod-backend-v1     1/1     Running   0          4m
pod-frontend-v1    1/1     Running   0          4m
pod-frontend-v2    1/1     Running   0          4m

# Paso 3.5 — env in (staging) → solo pod-frontend-v2
NAME               READY   STATUS    RESTARTS   AGE   LABELS
pod-frontend-v2    1/1     Running   0          4m    app=tienda,env=staging,...
```

#### Verificación

```bash
# El operador "notin" debe retornar exactamente 2 Pods
kubectl get pods -n lab-labels -l 'version notin (v2)' --no-headers | wc -l
# Resultado esperado: 2
```

---

### Paso 4: Agregar y modificar labels con kubectl label

**Objetivo:** Modificar labels en recursos existentes usando el subcomando `kubectl label` sin necesidad de editar manifiestos YAML.

#### Instrucciones

**4.1** Agrega el label `team=alpha` al Pod `pod-frontend-v1`:

```bash
kubectl label pod pod-frontend-v1 -n lab-labels team=alpha
```

**4.2** Agrega el label `monitored=true` a todos los Pods del namespace de una sola vez:

```bash
kubectl label pods --all -n lab-labels monitored=true
```

**4.3** Verifica los labels actualizados:

```bash
kubectl get pods -n lab-labels --show-labels
```

**4.4** Modifica el valor de un label existente (requiere `--overwrite`):

```bash
# Cambiar env de "staging" a "qa" en pod-frontend-v2
kubectl label pod pod-frontend-v2 -n lab-labels env=qa --overwrite
```

**4.5** Elimina un label de un Pod usando el sufijo `-` en el nombre del label:

```bash
# Eliminar el label "monitored" del pod-backend-v1
kubectl label pod pod-backend-v1 -n lab-labels monitored-
```

**4.6** Verifica el resultado final:

```bash
kubectl get pods -n lab-labels --show-labels
```

#### Salida esperada

```
# Después del paso 4.6
NAME               READY   STATUS    RESTARTS   AGE   LABELS
pod-backend-v1     1/1     Running   0          6m    app=tienda,env=production,tier=backend,version=v1
pod-frontend-v1    1/1     Running   0          6m    app=tienda,env=production,monitored=true,team=alpha,tier=frontend,version=v1
pod-frontend-v2    1/1     Running   0          6m    app=tienda,env=qa,monitored=true,tier=frontend,version=v2
```

#### Verificación

```bash
# Confirmar que pod-backend-v1 ya NO tiene el label "monitored"
kubectl get pod pod-backend-v1 -n lab-labels --show-labels | grep -v "monitored"
# La línea del pod debe aparecer sin "monitored" en su lista de labels
```

---

### Paso 5: Crear un ReplicaSet standalone con matchLabels y matchExpressions

**Objetivo:** Crear un ReplicaSet directamente (sin Deployment) para entender cómo funciona el controlador de forma independiente, usando tanto `matchLabels` como `matchExpressions` en el selector.

#### Instrucciones

**5.1** Crea el archivo `replicaset-web.yaml`:

```yaml
# replicaset-web.yaml
# ReplicaSet standalone que gestiona 3 réplicas de un Pod nginx
# Usa matchLabels y matchExpressions combinados en el selector
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: rs-web
  namespace: lab-labels
  labels:
    app: tienda-rs        # Label del propio objeto ReplicaSet
    managed-by: lab
spec:
  replicas: 3             # Estado deseado: 3 Pods corriendo
  selector:
    matchLabels:
      app: tienda-rs      # Condición 1: debe tener app=tienda-rs
    matchExpressions:
      - key: tier
        operator: In
        values:
          - frontend      # Condición 2: tier debe ser "frontend"
      - key: env
        operator: Exists  # Condición 3: debe existir el label "env" (cualquier valor)
  template:               # Plantilla para crear nuevos Pods
    metadata:
      labels:
        app: tienda-rs    # DEBE coincidir con el selector
        tier: frontend    # DEBE coincidir con el selector
        env: production   # DEBE coincidir con el selector (Exists)
        version: "v1"
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

> **Punto clave:** Los labels en `spec.template.metadata.labels` **deben ser un superconjunto** de los labels definidos en `spec.selector`. Si no coinciden, el API Server rechazará el manifiesto.

**5.2** Aplica el manifiesto:

```bash
kubectl apply -f replicaset-web.yaml
```

**5.3** Verifica que el ReplicaSet creó 3 Pods:

```bash
kubectl get replicaset rs-web -n lab-labels
kubectl get pods -n lab-labels -l app=tienda-rs
```

**5.4** Inspecciona los detalles del ReplicaSet para ver el selector completo:

```bash
kubectl describe replicaset rs-web -n lab-labels
```

#### Salida esperada

```bash
# kubectl get replicaset rs-web -n lab-labels
NAME     DESIRED   CURRENT   READY   AGE
rs-web   3         3         3       45s

# kubectl get pods -n lab-labels -l app=tienda-rs
NAME           READY   STATUS    RESTARTS   AGE
rs-web-xxxxx   1/1     Running   0          45s
rs-web-yyyyy   1/1     Running   0          45s
rs-web-zzzzz   1/1     Running   0          45s
```

```
# Fragmento relevante de kubectl describe replicaset rs-web
Selector:   app=tienda-rs,env,tier in (frontend)
Replicas:   3 current / 3 desired
```

#### Verificación

```bash
# El ReplicaSet debe reportar 3/3 réplicas listas
kubectl get rs rs-web -n lab-labels --no-headers | awk '{print $2, $4}'
# Resultado esperado: 3 3
```

---

### Paso 6: Experimento de reconciliación — remover el label selector de un Pod

**Objetivo:** Observar el bucle de reconciliación del ReplicaSet en acción: al quitar el label que el selector requiere de un Pod gestionado, el controlador lo "abandona" y crea un reemplazo para mantener el estado deseado de 3 réplicas.

#### Instrucciones

**6.1** Identifica el nombre exacto de uno de los Pods gestionados por el ReplicaSet:

```bash
kubectl get pods -n lab-labels -l app=tienda-rs --no-headers | head -1
# Anota el nombre del primer Pod (ejemplo: rs-web-abc12)
```

**6.2** Guarda el nombre en una variable de shell para facilitar los siguientes comandos:

```bash
# Sustituye "rs-web-abc12" por el nombre real de tu Pod
POD_TARGET=$(kubectl get pods -n lab-labels -l app=tienda-rs --no-headers | head -1 | awk '{print $1}')
echo "Pod objetivo: $POD_TARGET"
```

**6.3** En una terminal separada (o con `watch`), observa el estado de los Pods en tiempo real:

```bash
# Abre una segunda terminal y ejecuta este comando ANTES del paso 6.4
watch -n 1 kubectl get pods -n lab-labels -l app=tienda-rs
```

**6.4** Remueve el label `app=tienda-rs` del Pod objetivo. Esto hace que el Pod salga del control del ReplicaSet:

```bash
kubectl label pod $POD_TARGET -n lab-labels app-
```

**6.5** Observa inmediatamente el efecto. En tu terminal de `watch` deberías ver un nuevo Pod creándose. En la terminal principal, lista todos los Pods del namespace:

```bash
# Lista TODOS los pods del namespace (incluyendo el Pod "huérfano")
kubectl get pods -n lab-labels --show-labels
```

**6.6** Analiza lo que ocurrió:

```bash
# Verifica cuántos Pods tiene ahora el ReplicaSet (debe seguir siendo 3)
kubectl get rs rs-web -n lab-labels

# Verifica que el Pod huérfano sigue corriendo (sin el label app=tienda-rs)
kubectl get pods -n lab-labels -l 'app!=tienda-rs' --show-labels | grep rs-web
```

**6.7** Ahora restaura el label en el Pod huérfano y observa la reconciliación inversa:

```bash
# Restaurar el label app=tienda-rs al Pod huérfano
kubectl label pod $POD_TARGET -n lab-labels app=tienda-rs
```

**6.8** Observa qué sucede: ahora hay 4 Pods con el selector correcto, pero el ReplicaSet solo desea 3. El controlador **terminará uno de los Pods** para volver al estado deseado:

```bash
# Espera 5-10 segundos y luego verifica
sleep 10
kubectl get pods -n lab-labels -l app=tienda-rs
kubectl get rs rs-web -n lab-labels
```

#### Salida esperada

```bash
# Después del paso 6.4 — el Pod huérfano ya no tiene app=tienda-rs
# y el ReplicaSet crea un reemplazo inmediatamente

# kubectl get pods -n lab-labels --show-labels (paso 6.5)
NAME              READY   STATUS              LABELS
rs-web-abc12      1/1     Running             env=production,tier=frontend,version=v1  ← huérfano (sin app=tienda-rs)
rs-web-yyyyy      1/1     Running             app=tienda-rs,env=production,tier=frontend,version=v1
rs-web-zzzzz      1/1     Running             app=tienda-rs,env=production,tier=frontend,version=v1
rs-web-NUEVO      1/1     ContainerCreating   app=tienda-rs,env=production,tier=frontend,version=v1  ← nuevo Pod

# kubectl get rs rs-web -n lab-labels (paso 6.6)
NAME     DESIRED   CURRENT   READY   AGE
rs-web   3         3         3       5m

# Después del paso 6.8 — el controlador termina 1 Pod para volver a 3
NAME              READY   STATUS        
rs-web-abc12      0/1     Terminating   ← el controlador elige 1 para eliminar
rs-web-yyyyy      1/1     Running
rs-web-zzzzz      1/1     Running
rs-web-NUEVO      1/1     Running
```

#### Verificación

```bash
# El ReplicaSet debe volver a reportar exactamente 3/3 réplicas
kubectl get rs rs-web -n lab-labels --no-headers | awk '{print $2, $3, $4}'
# Resultado esperado: 3 3 3  (DESIRED CURRENT READY)
```

> **Reflexión:** Este experimento demuestra visualmente el **bucle de reconciliación** descrito en la lección 2.1: Kubernetes observa continuamente la diferencia entre el estado deseado (`spec.replicas: 3`) y el estado actual, y actúa para corregirla. El selector de labels es el único mecanismo que el ReplicaSet usa para "reconocer" sus Pods.

---

### Paso 7: Labels vs. Annotations — diferencia práctica

**Objetivo:** Comprender cuándo usar labels (para selección y organización operacional) versus annotations (para metadatos informativos que no participan en selección).

#### Instrucciones

**7.1** Agrega annotations al ReplicaSet con información descriptiva que no necesita ser consultada como selector:

```bash
kubectl annotate replicaset rs-web -n lab-labels \
  description="ReplicaSet para el frontend de la tienda online" \
  contact="equipo-plataforma@empresa.com" \
  last-reviewed="2024-01-15" \
  documentation="https://wiki.empresa.com/tienda/frontend"
```

**7.2** Verifica las annotations en el objeto:

```bash
kubectl describe replicaset rs-web -n lab-labels | grep -A 10 "Annotations:"
```

**7.3** Intenta usar una annotation como selector (esto debe fallar o retornar 0 resultados, demostrando la diferencia):

```bash
# Las annotations NO pueden usarse como selectores
kubectl get replicaset -n lab-labels -l description="ReplicaSet para el frontend de la tienda online"
# Resultado esperado: No resources found — las annotations no son queryables con -l
```

**7.4** Compara la diferencia en el YAML del objeto:

```bash
# Observa cómo labels y annotations aparecen en secciones separadas de metadata
kubectl get replicaset rs-web -n lab-labels -o yaml | grep -A 20 "metadata:"
```

**7.5** Crea el archivo `pod-con-annotations.yaml` para ver la diferencia estructural en un manifiesto:

```yaml
# pod-con-annotations.yaml
# Ejemplo que muestra la diferencia entre labels (para selección)
# y annotations (para metadatos informativos)
apiVersion: v1
kind: Pod
metadata:
  name: pod-annotated
  namespace: lab-labels
  labels:
    app: tienda          # Usable como selector: kubectl get pods -l app=tienda
    tier: utility        # Usable como selector
  annotations:
    # Las annotations NO son usables como selectores
    # Permiten caracteres y longitudes que los labels no permiten
    build-version: "commit-sha-a1b2c3d4e5f6"
    deployment-date: "2024-01-15T10:30:00Z"
    team-contact: "plataforma@empresa.com"
    notes: |
      Este Pod es parte del experimento de labels del laboratorio 02-00-02.
      Puede contener texto largo y caracteres especiales sin restricciones.
spec:
  containers:
    - name: busybox
      image: busybox:latest
      command: ["sh", "-c", "while true; do sleep 3600; done"]
```

```bash
kubectl apply -f pod-con-annotations.yaml
```

**7.6** Consulta las annotations del Pod recién creado:

```bash
kubectl get pod pod-annotated -n lab-labels -o jsonpath='{.metadata.annotations}' | jq .
```

#### Salida esperada

```bash
# Paso 7.3 — intento de usar annotation como selector
No resources found in lab-labels namespace.

# Paso 7.6 — annotations del pod-annotated
{
  "build-version": "commit-sha-a1b2c3d4e5f6",
  "deployment-date": "2024-01-15T10:30:00Z",
  "kubectl.kubernetes.io/last-applied-configuration": "...",
  "notes": "Este Pod es parte del experimento...\n",
  "team-contact": "plataforma@empresa.com"
}
```

#### Verificación

```bash
# Confirmar que los labels SÍ funcionan como selector pero las annotations NO
# Labels: debe retornar pod-annotated
kubectl get pods -n lab-labels -l app=tienda,tier=utility --no-headers | wc -l
# Resultado esperado: 1 (el pod-annotated)

# Annotations: debe retornar 0 resultados
kubectl get pods -n lab-labels -l 'build-version' --no-headers | wc -l
# Resultado esperado: 0
```

> **Regla práctica:** Usa **labels** para cualquier dato que necesites consultar, filtrar o usar en selectores. Usa **annotations** para metadatos informativos: URLs de documentación, contactos, hashes de commits, fechas, notas de operación. Las annotations permiten valores más largos y caracteres especiales que los labels no admiten.

---

## 7. Validación y Pruebas Finales

Ejecuta la siguiente secuencia de verificaciones para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
# ── VERIFICACIÓN 1: Namespace y Pods base ──────────────────────────────────
echo "=== VERIFICACIÓN 1: Pods base ==="
kubectl get pods -n lab-labels --show-labels

# ── VERIFICACIÓN 2: Selectores de igualdad ────────────────────────────────
echo ""
echo "=== VERIFICACIÓN 2: Selector tier=frontend (debe retornar ≥2 Pods) ==="
kubectl get pods -n lab-labels -l tier=frontend --no-headers | wc -l

# ── VERIFICACIÓN 3: Selectores de conjunto ────────────────────────────────
echo ""
echo "=== VERIFICACIÓN 3: Selector 'env in (production)' ==="
kubectl get pods -n lab-labels -l 'env in (production)' --no-headers

# ── VERIFICACIÓN 4: ReplicaSet operativo ──────────────────────────────────
echo ""
echo "=== VERIFICACIÓN 4: ReplicaSet rs-web con 3/3 réplicas ==="
kubectl get rs rs-web -n lab-labels

# ── VERIFICACIÓN 5: Annotations presentes ────────────────────────────────
echo ""
echo "=== VERIFICACIÓN 5: Annotations en rs-web ==="
kubectl get rs rs-web -n lab-labels -o jsonpath='{.metadata.annotations.description}'
echo ""

# ── VERIFICACIÓN 6: Resumen del namespace ─────────────────────────────────
echo ""
echo "=== VERIFICACIÓN 6: Todos los recursos en lab-labels ==="
kubectl get all -n lab-labels
```

**Resultado esperado del resumen final:**

```
=== VERIFICACIÓN 4: ReplicaSet rs-web con 3/3 réplicas ===
NAME     DESIRED   CURRENT   READY   AGE
rs-web   3         3         3       15m

=== VERIFICACIÓN 5: Annotations en rs-web ===
ReplicaSet para el frontend de la tienda online

=== VERIFICACIÓN 6: Todos los recursos en lab-labels ===
NAME                 READY   STATUS    RESTARTS   AGE
pod/pod-annotated    1/1     Running   0          5m
pod/pod-backend-v1   1/1     Running   0          15m
pod/pod-frontend-v1  1/1     Running   0          15m
pod/pod-frontend-v2  1/1     Running   0          15m
pod/rs-web-xxxxx     1/1     Running   0          10m
pod/rs-web-yyyyy     1/1     Running   0          10m
pod/rs-web-zzzzz     1/1     Running   0          10m

NAME                       DESIRED   CURRENT   READY   AGE
replicaset.apps/rs-web     3         3         3       10m
```

---

## 8. Resolución de Problemas

### Problema 1: El ReplicaSet no crea Pods después de `kubectl apply`

**Síntomas:**
```bash
kubectl get rs rs-web -n lab-labels
# NAME     DESIRED   CURRENT   READY   AGE
# rs-web   3         0         0       2m
```
El ReplicaSet existe pero `CURRENT` y `READY` permanecen en 0. Los Pods no aparecen con `kubectl get pods -n lab-labels -l app=tienda-rs`.

**Causa probable:**
El selector del ReplicaSet no coincide con los labels de la plantilla `spec.template.metadata.labels`, o los labels de la plantilla son un subconjunto incompleto del selector. También puede ocurrir si el namespace especificado en el manifiesto no existe al momento de aplicar.

**Solución:**

```bash
# 1. Verificar eventos del ReplicaSet para ver el error exacto
kubectl describe rs rs-web -n lab-labels | grep -A 20 "Events:"

# 2. Verificar que el namespace existe
kubectl get namespace lab-labels

# 3. Comparar el selector con los labels de la plantilla
kubectl get rs rs-web -n lab-labels -o yaml | grep -A 20 "selector:"
kubectl get rs rs-web -n lab-labels -o yaml | grep -A 10 "template:"

# 4. Si hay discrepancia, eliminar el ReplicaSet y recrearlo con el manifiesto corregido
# (los ReplicaSets no permiten modificar el selector una vez creados)
kubectl delete rs rs-web -n lab-labels
kubectl apply -f replicaset-web.yaml
```

> **Regla de oro:** En un ReplicaSet, los labels de `spec.template.metadata.labels` deben satisfacer **todas** las condiciones del `spec.selector`. Si el selector pide `app=tienda-rs` y `tier=frontend`, la plantilla debe tener ambos labels como mínimo.

---

### Problema 2: Después del experimento del Paso 6, el ReplicaSet no vuelve a 3 réplicas tras restaurar el label

**Síntomas:**
```bash
kubectl get pods -n lab-labels -l app=tienda-rs
# Se muestran 4 Pods en Running y ninguno en Terminating
# kubectl get rs rs-web -n lab-labels muestra DESIRED=3 CURRENT=4 READY=4
```
El controlador del ReplicaSet no está terminando el Pod extra.

**Causa probable:**
El API Server o el controller manager puede estar experimentando un retraso de reconciliación. También puede ocurrir si el Pod restaurado tiene un `ownerReference` diferente (porque fue creado antes del ReplicaSet actual), lo que hace que el controlador no lo considere "suyo" para eliminarlo.

**Solución:**

```bash
# 1. Verificar los ownerReferences de todos los Pods del selector
kubectl get pods -n lab-labels -l app=tienda-rs \
  -o custom-columns="NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name"

# 2. Esperar 30 segundos — el bucle de reconciliación puede tener latencia
sleep 30
kubectl get pods -n lab-labels -l app=tienda-rs

# 3. Si el problema persiste, verificar que el controller manager está activo
kubectl get pods -n kube-system | grep controller-manager

# 4. Si el Pod restaurado no tiene ownerReference del rs-web actual,
# eliminarlo manualmente (el ReplicaSet creará uno nuevo si count < 3)
ORPHAN_POD=$(kubectl get pods -n lab-labels -l app=tienda-rs \
  -o custom-columns="NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name" \
  --no-headers | grep "<none>" | awk '{print $1}')
if [ -n "$ORPHAN_POD" ]; then
  kubectl delete pod $ORPHAN_POD -n lab-labels
fi
```

---

## 9. Limpieza del Entorno

Una vez completado el laboratorio, elimina los recursos creados para liberar recursos del clúster. **Nota:** Si planeas continuar con laboratorios posteriores que reutilicen el namespace `lab-labels`, omite el paso de eliminación del namespace.

```bash
# Opción A: Eliminar solo los recursos creados en este lab (conserva el namespace)
kubectl delete -f pods-multi-label.yaml --ignore-not-found
kubectl delete -f replicaset-web.yaml --ignore-not-found
kubectl delete -f pod-con-annotations.yaml --ignore-not-found

# Opción B: Eliminar el namespace completo (elimina TODOS los recursos dentro)
kubectl delete namespace lab-labels

# Verificar que el namespace fue eliminado
kubectl get namespace lab-labels
# Resultado esperado: Error from server (NotFound): namespaces "lab-labels" not found
```

> **Recomendación:** Si vas a continuar directamente con el Lab 02-00-03 u otros laboratorios del módulo 2, usa la **Opción A** para conservar el namespace y evitar recrear recursos de contexto.

---

## 10. Resumen

### Conceptos demostrados

En este laboratorio aplicaste los mecanismos de labels y selectores que son fundamentales en la arquitectura de Kubernetes:

| Concepto | Lo que practicaste |
|---|---|
| **Labels múltiples** | Creación de Pods con 4 labels simultáneos (`app`, `version`, `env`, `tier`) |
| **Selectores de igualdad** | Filtrado con `=`, `!=` y combinaciones AND con coma |
| **Selectores de conjunto** | Uso de `in`, `notin`, `exists` para consultas más expresivas |
| **`kubectl label`** | Agregar, modificar (`--overwrite`) y eliminar (`key-`) labels en tiempo real |
| **ReplicaSet standalone** | Creación con `matchLabels` + `matchExpressions` combinados |
| **Bucle de reconciliación** | Experimento de remoción y restauración de label para observar la acción del controlador |
| **Annotations** | Diferencia con labels: metadatos informativos no usables como selectores |

### Puntos clave para recordar

1. **Los labels son el "pegamento" de Kubernetes**: Services, ReplicaSets, Deployments y otros controladores usan selectores de labels para identificar los recursos que gestionan. Sin labels correctos, los controladores no pueden funcionar.

2. **El selector es inmutable en ReplicaSets**: Una vez creado un ReplicaSet, no puedes modificar su `spec.selector`. Para cambiar el selector, debes eliminar y recrear el ReplicaSet.

3. **La reconciliación es continua**: Como demostró el experimento del Paso 6, el controlador del ReplicaSet observa constantemente cuántos Pods satisfacen su selector y actúa para mantener el número deseado, ya sea creando o terminando Pods.

4. **Labels para selección, annotations para información**: Los labels tienen restricciones de caracteres y longitud precisamente porque son indexados para búsquedas eficientes. Las annotations son libres de estas restricciones porque no participan en selección.

### Recursos adicionales

- [Documentación oficial: Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Documentación oficial: ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [Documentación oficial: Annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)
- [kubectl Cheat Sheet — Label operations](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#updating-resources)

---
