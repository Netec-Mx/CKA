# Gestión de Namespaces y Despliegue de Recursos

## 1. Metadatos

| Campo        | Detalle                                      |
|--------------|----------------------------------------------|
| **Duración** | 56 minutos                                   |
| **Complejidad** | Media                                     |
| **Nivel Bloom** | Aplicar (Apply)                           |
| **Módulo**   | 4 — Namespaces, ResourceQuotas y LimitRanges |
| **Lab ID**   | 04-00-01                                     |

---

## 2. Descripción General

En este laboratorio aplicarás los conceptos de Namespaces de Kubernetes para organizar recursos en tres ambientes simulados: `development`, `staging` y `production`. Crearás los Namespaces mediante manifiestos YAML y comandos imperativos, desplegarás la misma aplicación en cada uno para demostrar el aislamiento lógico, y configurarás una **ResourceQuota** y un **LimitRange** en el namespace `development` para controlar el consumo de recursos. Finalizarás explorando los Namespaces del sistema y practicando la eliminación controlada en cascada de un Namespace completo.

---

## 3. Objetivos de Aprendizaje

- [ ] Crear y gestionar Namespaces en Kubernetes usando manifiestos YAML y comandos imperativos, aplicando buenas prácticas de organización por ambiente.
- [ ] Desplegar la misma aplicación en múltiples Namespaces y verificar el aislamiento lógico entre ellos usando `-n` y `--all-namespaces`.
- [ ] Configurar una ResourceQuota en un Namespace para limitar CPU, memoria y número de Pods, y observar el comportamiento al exceder los límites.
- [ ] Crear un LimitRange para establecer valores por defecto de `requests` y `limits` en contenedores.
- [ ] Explorar los Namespaces del sistema y eliminar un Namespace verificando la eliminación en cascada de sus recursos.

---

## 4. Prerrequisitos

### Conocimientos previos
- Haber completado el laboratorio **01-00-01** (introducción a kubectl y Pods).
- Comprensión de Deployments y Services en Kubernetes.
- Familiaridad con la estructura de manifiestos YAML de Kubernetes.
- Conocimiento básico del concepto de Namespace (Lección 4.1).

### Acceso y herramientas requeridas
- Clúster Minikube operativo con kubectl configurado y acceso al contexto activo.
- `kubectl` versión 1.28.x o superior.
- Terminal con permisos de administrador sobre el clúster.
- Editor de texto (VS Code recomendado) para crear manifiestos YAML.

---

## 5. Entorno de Laboratorio

### Hardware recomendado

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU     | 4 núcleos | 8 núcleos |
| RAM     | 8 GB   | 16 GB       |
| Disco   | 40 GB libres | 60 GB SSD |

### Software requerido

| Herramienta | Versión mínima |
|-------------|----------------|
| Minikube    | 1.31.x         |
| kubectl     | 1.28.x         |
| Docker Engine | 24.x         |

### Preparación del entorno

Antes de comenzar, verifica que tu clúster Minikube esté activo. Si no lo tienes iniciado con múltiples nodos, ejecuta:

```bash
# Verificar si Minikube está corriendo
minikube status

# Si no está iniciado, arrancarlo con 3 nodos (recomendado para el curso)
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que kubectl apunta al clúster correcto
kubectl config current-context

# Verificar los nodos disponibles
kubectl get nodes
```

**Salida esperada de `kubectl get nodes`:**
```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

Crea un directorio de trabajo para este laboratorio:

```bash
mkdir -p ~/k8s-labs/lab-04 && cd ~/k8s-labs/lab-04
```

---

## 6. Instrucciones Paso a Paso

---

### Paso 1: Explorar los Namespaces del Sistema

**Objetivo:** Familiarizarse con los Namespaces predeterminados de Kubernetes y comprender el propósito de cada uno antes de crear los propios.

**Instrucciones:**

1. Lista todos los Namespaces existentes en el clúster:

```bash
kubectl get namespaces
```

2. Observa los cuatro Namespaces predeterminados. Ahora obtén información detallada del Namespace `kube-system`:

```bash
kubectl describe namespace kube-system
```

3. Lista los Pods que corren dentro de `kube-system` (componentes internos del clúster):

```bash
kubectl get pods -n kube-system
```

4. Explora el Namespace `kube-public` y su ConfigMap de información pública:

```bash
kubectl get configmaps -n kube-public
kubectl describe configmap cluster-info -n kube-public
```

5. Observa los objetos Lease en `kube-node-lease` (heartbeats de nodos):

```bash
kubectl get leases -n kube-node-lease
```

6. Verifica qué Namespace está configurado como activo en tu contexto actual:

```bash
kubectl config view --minify | grep namespace
```

> **Nota:** Si no aparece ningún namespace en la salida, significa que el contexto usa `default` implícitamente.

**Salida esperada de `kubectl get namespaces`:**
```
NAME              STATUS   AGE
default           Active   Xd
kube-node-lease   Active   Xd
kube-public       Active   Xd
kube-system       Active   Xd
```

**Salida esperada de `kubectl get pods -n kube-system`:**
```
NAME                               READY   STATUS    RESTARTS   AGE
coredns-...                        1/1     Running   0          Xd
etcd-minikube                      1/1     Running   0          Xd
kube-apiserver-minikube            1/1     Running   0          Xd
kube-controller-manager-minikube   1/1     Running   0          Xd
kube-proxy-...                     1/1     Running   0          Xd
kube-scheduler-minikube            1/1     Running   0          Xd
storage-provisioner                1/1     Running   0          Xd
```

**Verificación:**
```bash
# Confirmar que los 4 namespaces del sistema existen
kubectl get namespaces | grep -E "default|kube-system|kube-public|kube-node-lease"
```

---

### Paso 2: Crear Namespaces para los Tres Ambientes

**Objetivo:** Crear los Namespaces `development`, `staging` y `production` usando tanto el método imperativo como el declarativo (YAML).

**Instrucciones:**

1. Crea el Namespace `development` de forma **imperativa** (comando directo):

```bash
kubectl create namespace development
```

2. Crea el Namespace `staging` de forma **declarativa** usando un manifiesto YAML. Primero crea el archivo:

```bash
cat <<EOF > ~/k8s-labs/lab-04/namespace-staging.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: platform
    managed-by: kubectl
EOF
```

Aplica el manifiesto:

```bash
kubectl apply -f ~/k8s-labs/lab-04/namespace-staging.yaml
```

3. Crea el Namespace `production` con etiquetas descriptivas usando otro manifiesto:

```bash
cat <<EOF > ~/k8s-labs/lab-04/namespace-production.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    team: platform
    managed-by: kubectl
  annotations:
    description: "Namespace para el ambiente de produccion"
    contact: "ops-team@empresa.com"
EOF
```

```bash
kubectl apply -f ~/k8s-labs/lab-04/namespace-production.yaml
```

4. Agrega etiquetas al Namespace `development` que fue creado de forma imperativa:

```bash
kubectl label namespace development environment=development team=backend
```

5. Verifica que los tres Namespaces fueron creados correctamente:

```bash
kubectl get namespaces
```

6. Lista los Namespaces filtrando por etiqueta de equipo:

```bash
kubectl get namespaces -l team=platform
```

**Salida esperada de `kubectl get namespaces`:**
```
NAME              STATUS   AGE
default           Active   Xd
development       Active   Xs
kube-node-lease   Active   Xd
kube-public       Active   Xd
kube-system       Active   Xd
production        Active   Xs
staging           Active   Xs
```

**Verificación:**
```bash
# Verificar que los 3 namespaces existen y están en estado Active
kubectl get namespaces development staging production
```

**Salida esperada:**
```
NAME          STATUS   AGE
development   Active   Xs
staging       Active   Xs
production    Active   Xs
```

---

### Paso 3: Desplegar la Misma Aplicación en los Tres Namespaces

**Objetivo:** Demostrar el aislamiento lógico entre Namespaces desplegando la misma aplicación nginx con configuraciones diferentes en cada ambiente.

**Instrucciones:**

1. Crea el manifiesto del Deployment para el ambiente `development` (1 réplica, imagen nginx:1.25):

```bash
cat <<EOF > ~/k8s-labs/lab-04/deploy-development.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: development
  labels:
    app: webapp
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        environment: development
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: development
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

2. Crea el manifiesto para `staging` (2 réplicas, imagen nginx:1.25):

```bash
cat <<EOF > ~/k8s-labs/lab-04/deploy-staging.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: staging
  labels:
    app: webapp
    environment: staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        environment: staging
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: staging
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

3. Crea el manifiesto para `production` (3 réplicas, imagen nginx:1.26):

```bash
cat <<EOF > ~/k8s-labs/lab-04/deploy-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: production
  labels:
    app: webapp
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        environment: staging
    spec:
      containers:
      - name: nginx
        image: nginx:1.26
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: production
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

4. Aplica los tres manifiestos:

```bash
kubectl apply -f ~/k8s-labs/lab-04/deploy-development.yaml
kubectl apply -f ~/k8s-labs/lab-04/deploy-staging.yaml
kubectl apply -f ~/k8s-labs/lab-04/deploy-production.yaml
```

5. Verifica el aislamiento: el mismo nombre `webapp` existe en los tres Namespaces sin conflicto:

```bash
# Ver Deployments en cada namespace por separado
kubectl get deployments -n development
kubectl get deployments -n staging
kubectl get deployments -n production
```

6. Usa `--all-namespaces` para ver todos los recursos a la vez:

```bash
kubectl get deployments --all-namespaces
kubectl get pods --all-namespaces | grep webapp
kubectl get services --all-namespaces | grep webapp
```

**Salida esperada de `kubectl get deployments --all-namespaces`:**
```
NAMESPACE     NAME     READY   UP-TO-DATE   AVAILABLE   AGE
development   webapp   1/1     1            1           Xs
production    webapp   3/3     3            3           Xs
staging       webapp   2/2     2            2           Xs
```

**Verificación:**
```bash
# Confirmar que el mismo nombre 'webapp' existe en los 3 namespaces sin conflicto
kubectl get deployment webapp -n development -o jsonpath='{.metadata.namespace}'
kubectl get deployment webapp -n staging -o jsonpath='{.metadata.namespace}'
kubectl get deployment webapp -n production -o jsonpath='{.metadata.namespace}'
```

---

### Paso 4: Navegar entre Namespaces con kubectl config

**Objetivo:** Practicar el cambio del Namespace por defecto en el contexto activo de kubectl para evitar escribir `-n` en cada comando.

**Instrucciones:**

1. Verifica el contexto y Namespace actuales:

```bash
kubectl config current-context
kubectl config view --minify | grep namespace
```

2. Cambia el Namespace por defecto del contexto activo a `development`:

```bash
kubectl config set-context --current --namespace=development
```

3. Verifica el cambio. Ahora los comandos sin `-n` operarán en `development`:

```bash
kubectl config view --minify | grep namespace
```

4. Ejecuta comandos sin especificar Namespace y observa que apuntan a `development`:

```bash
kubectl get pods
kubectl get deployments
kubectl get services
```

5. Cambia al Namespace `staging` y repite la verificación:

```bash
kubectl config set-context --current --namespace=staging
kubectl get pods
```

6. Vuelve al Namespace `default` para continuar con el laboratorio:

```bash
kubectl config set-context --current --namespace=default
kubectl config view --minify | grep namespace
```

> **Tip CKA:** En el examen CKA, cambiar el namespace del contexto con `kubectl config set-context --current --namespace=<ns>` es una técnica muy común para trabajar eficientemente en un namespace específico durante un escenario. Recuerda siempre volver a `default` al terminar cada tarea.

**Salida esperada tras `kubectl config set-context --current --namespace=development`:**
```
Context "minikube" modified.
```

**Verificación:**
```bash
# Confirmar que el namespace por defecto es 'default' al final del paso
kubectl config view --minify | grep namespace
# Debe mostrar: namespace: default
```

---

### Paso 5: Configurar una ResourceQuota en el Namespace `development`

**Objetivo:** Limitar el consumo de recursos en el Namespace `development` usando una ResourceQuota, y verificar el comportamiento del clúster al intentar exceder los límites.

**Instrucciones:**

1. Crea el manifiesto de la ResourceQuota para `development`:

```bash
cat <<EOF > ~/k8s-labs/lab-04/resourcequota-development.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    pods: "5"
    services: "3"
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1000m"
    limits.memory: "1Gi"
    configmaps: "5"
    secrets: "5"
EOF
```

2. Aplica la ResourceQuota:

```bash
kubectl apply -f ~/k8s-labs/lab-04/resourcequota-development.yaml
```

3. Verifica que la ResourceQuota fue creada y observa el estado de uso actual:

```bash
kubectl describe resourcequota development-quota -n development
```

4. Escala el Deployment `webapp` en `development` para consumir más recursos y observar el contador:

```bash
kubectl scale deployment webapp -n development --replicas=2
sleep 5
kubectl describe resourcequota development-quota -n development
```

5. Intenta exceder el límite de Pods creando un Deployment adicional que requeriría más de 5 Pods en total. Primero, escala `webapp` al máximo permitido (4 pods), luego intenta crear un quinto Deployment:

```bash
# Escala webapp a 4 réplicas (ya tenemos 2 del paso anterior)
kubectl scale deployment webapp -n development --replicas=4
sleep 10
kubectl get pods -n development

# Intenta crear un deployment adicional que requeriría un 5to pod
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: extra-app
  namespace: development
spec:
  replicas: 2
  selector:
    matchLabels:
      app: extra-app
  template:
    metadata:
      labels:
        app: extra-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            cpu: "50m"
            memory: "32Mi"
          limits:
            cpu: "100m"
            memory: "64Mi"
EOF
```

6. Observa el estado del nuevo Deployment. El ReplicaSet intentará crear Pods pero fallará por la cuota:

```bash
kubectl get deployment extra-app -n development
kubectl describe replicaset -n development -l app=extra-app
```

7. Busca eventos de error relacionados con la cuota:

```bash
kubectl get events -n development --sort-by='.lastTimestamp' | tail -10
```

**Salida esperada de `kubectl describe resourcequota development-quota -n development` (con 4 pods corriendo):**
```
Name:            development-quota
Namespace:       development
Resource         Used    Hard
--------         ----    ----
configmaps       1       5
limits.cpu       800m    1000m
limits.memory    512Mi   1Gi
pods             4       5
requests.cpu     400m    500m
requests.memory  256Mi   512Mi
secrets          1       5
services         1       3
```

**Salida esperada en eventos al exceder la cuota:**
```
LAST SEEN   TYPE      REASON              OBJECT                         MESSAGE
Xs          Warning   FailedCreate        replicaset/extra-app-...       Error creating: pods "extra-app-..." is forbidden: exceeded quota: development-quota, requested: pods=1, used: pods=5, limited: pods=5
```

**Verificación:**
```bash
# Confirmar que la quota existe y tiene límites configurados
kubectl get resourcequota -n development
# Debe mostrar: development-quota
```

---

### Paso 6: Configurar un LimitRange en el Namespace `development`

**Objetivo:** Crear un LimitRange que establezca valores por defecto de `requests` y `limits` para contenedores en el Namespace `development`, garantizando que ningún contenedor se ejecute sin restricciones de recursos.

**Instrucciones:**

1. Limpia el Deployment extra del paso anterior para tener espacio:

```bash
kubectl delete deployment extra-app -n development
kubectl scale deployment webapp -n development --replicas=1
sleep 5
```

2. Crea el manifiesto del LimitRange:

```bash
cat <<EOF > ~/k8s-labs/lab-04/limitrange-development.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
  namespace: development
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "128Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
    max:
      cpu: "500m"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "32Mi"
  - type: Pod
    max:
      cpu: "1000m"
      memory: "1Gi"
EOF
```

3. Aplica el LimitRange:

```bash
kubectl apply -f ~/k8s-labs/lab-04/limitrange-development.yaml
```

4. Verifica la configuración del LimitRange:

```bash
kubectl describe limitrange development-limits -n development
```

5. Prueba el efecto del LimitRange creando un Pod **sin especificar resources** (el LimitRange debe asignar los valores por defecto automáticamente):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-limitrange
  namespace: development
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    # Sin resources definidos - el LimitRange los asignará automáticamente
EOF
```

6. Inspecciona el Pod creado y verifica que tiene `requests` y `limits` asignados automáticamente:

```bash
kubectl get pod test-limitrange -n development -o yaml | grep -A 10 "resources:"
```

7. Intenta crear un Pod que exceda el límite máximo del LimitRange:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-overlimit
  namespace: development
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    resources:
      requests:
        cpu: "600m"
        memory: "600Mi"
      limits:
        cpu: "600m"
        memory: "600Mi"
EOF
```

**Salida esperada de `kubectl describe limitrange development-limits -n development`:**
```
Name:       development-limits
Namespace:  development
Type        Resource  Min   Max    Default Request  Default Limit  Max Limit/Request Ratio
----        --------  ---   ---    ---------------  -------------  -----------------------
Container   cpu       50m   500m   100m             200m           -
Container   memory    32Mi  512Mi  64Mi             128Mi          -
Pod         cpu       -     1000m  -                -              -
Pod         memory    -     1Gi    -                -              -
```

**Salida esperada de `kubectl get pod test-limitrange -n development -o yaml | grep -A 10 "resources:"`:**
```yaml
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 64Mi
```

**Salida esperada al intentar crear `test-overlimit`:**
```
Error from server (Forbidden): error when creating "STDIN": pods "test-overlimit" is forbidden: [maximum cpu usage per Container is 500m, but limit is 600m, maximum memory usage per Container is 512Mi, but limit is 600Mi]
```

**Verificación:**
```bash
# Confirmar que el LimitRange existe
kubectl get limitrange -n development
# Confirmar que el pod test-limitrange tiene resources asignados por el LimitRange
kubectl get pod test-limitrange -n development -o jsonpath='{.spec.containers[0].resources}'
```

---

### Paso 7: Verificar el Aislamiento entre Namespaces

**Objetivo:** Confirmar que los recursos en diferentes Namespaces están lógicamente aislados y que los nombres pueden repetirse sin conflicto entre Namespaces.

**Instrucciones:**

1. Verifica que el Service `webapp-svc` existe en los tres Namespaces con el mismo nombre:

```bash
kubectl get service webapp-svc -n development
kubectl get service webapp-svc -n staging
kubectl get service webapp-svc -n production
```

2. Observa las IPs de ClusterIP asignadas a cada Service (serán diferentes):

```bash
kubectl get services --all-namespaces | grep webapp-svc
```

3. Lanza un Pod temporal en el Namespace `development` para verificar la resolución DNS interna:

```bash
kubectl run dns-test \
  --image=busybox:latest \
  --restart=Never \
  --namespace=development \
  -it --rm \
  -- sh -c "
    echo '=== DNS dentro del mismo namespace (development) ==='
    nslookup webapp-svc
    echo ''
    echo '=== DNS hacia otro namespace (staging) ==='
    nslookup webapp-svc.staging.svc.cluster.local
    echo ''
    echo '=== DNS hacia produccion ==='
    nslookup webapp-svc.production.svc.cluster.local
  "
```

> **Nota:** Este comando puede tardar 20-30 segundos mientras se descarga la imagen de busybox. Si el clúster no tiene conectividad, la imagen debe estar pre-descargada.

4. Confirma que desde `development` no puedes resolver `webapp-svc` sin el FQDN cuando el Pod está en otro Namespace:

```bash
# El nombre corto 'webapp-svc' resuelve al service en el namespace actual (development)
# Para acceder al de staging se necesita el nombre completo:
# webapp-svc.staging.svc.cluster.local
echo "El FQDN de webapp-svc en staging es: webapp-svc.staging.svc.cluster.local"
echo "El FQDN de webapp-svc en production es: webapp-svc.production.svc.cluster.local"
```

**Salida esperada de `kubectl get services --all-namespaces | grep webapp-svc`:**
```
development   webapp-svc   ClusterIP   10.96.X.X    <none>   80/TCP   Xm
production    webapp-svc   ClusterIP   10.96.X.X    <none>   80/TCP   Xm
staging       webapp-svc   ClusterIP   10.96.X.X    <none>   80/TCP   Xm
```
*(Las IPs de ClusterIP serán diferentes para cada Service)*

**Verificación:**
```bash
# Confirmar que los 3 services con el mismo nombre existen en namespaces distintos
kubectl get svc webapp-svc --all-namespaces
```

---

### Paso 8: Eliminar un Namespace y Verificar la Cascada

**Objetivo:** Demostrar que al eliminar un Namespace, todos sus recursos contenidos (Pods, Deployments, Services, ConfigMaps, etc.) son eliminados automáticamente en cascada.

**Instrucciones:**

1. Antes de eliminar, lista todos los recursos en el Namespace `staging`:

```bash
echo "=== Deployments en staging ==="
kubectl get deployments -n staging

echo "=== Pods en staging ==="
kubectl get pods -n staging

echo "=== Services en staging ==="
kubectl get services -n staging
```

2. Elimina el Namespace `staging`:

```bash
kubectl delete namespace staging
```

> **Nota:** La eliminación puede tardar 15-30 segundos mientras Kubernetes termina todos los Pods y limpia los recursos.

3. Verifica que el Namespace ya no existe:

```bash
kubectl get namespaces
```

4. Intenta acceder a los recursos que estaban en `staging` para confirmar que fueron eliminados:

```bash
kubectl get deployments -n staging 2>&1
kubectl get pods -n staging 2>&1
kubectl get services -n staging 2>&1
```

5. Confirma que los Namespaces `development` y `production` y sus recursos están intactos:

```bash
kubectl get deployments --all-namespaces | grep -v kube-system
kubectl get pods --all-namespaces | grep webapp
```

**Salida esperada de `kubectl get namespaces` (después de eliminar staging):**
```
NAME              STATUS   AGE
default           Active   Xd
development       Active   Xm
kube-node-lease   Active   Xd
kube-public       Active   Xd
kube-system       Active   Xd
production        Active   Xm
```

**Salida esperada al intentar acceder a recursos en `staging`:**
```
Error from server (NotFound): namespaces "staging" not found
```

**Verificación:**
```bash
# Confirmar que staging ya no existe
kubectl get namespace staging 2>&1 | grep "NotFound"
# Confirmar que development y production siguen intactos
kubectl get deployment webapp -n development
kubectl get deployment webapp -n production
```

---

## 7. Validación y Pruebas Finales

Ejecuta las siguientes verificaciones para confirmar que el laboratorio fue completado exitosamente:

```bash
echo "============================================"
echo "  VALIDACIÓN FINAL - Lab 04-00-01"
echo "============================================"

echo ""
echo "1. Namespaces activos:"
kubectl get namespaces development production | grep Active

echo ""
echo "2. Deployments en development y production:"
kubectl get deployments --all-namespaces | grep -E "development|production"

echo ""
echo "3. ResourceQuota en development:"
kubectl get resourcequota -n development

echo ""
echo "4. LimitRange en development:"
kubectl get limitrange -n development

echo ""
echo "5. Pods en development (con limits asignados por LimitRange):"
kubectl get pods -n development

echo ""
echo "6. Namespace staging eliminado (debe dar NotFound):"
kubectl get namespace staging 2>&1

echo ""
echo "7. Resumen de todos los namespaces:"
kubectl get namespaces

echo ""
echo "============================================"
echo "  FIN DE VALIDACIÓN"
echo "============================================"
```

**Criterios de éxito:**
- ✅ Los Namespaces `development` y `production` existen y están en estado `Active`.
- ✅ El Deployment `webapp` existe en ambos Namespaces con diferente número de réplicas.
- ✅ La ResourceQuota `development-quota` existe en el Namespace `development`.
- ✅ El LimitRange `development-limits` existe en el Namespace `development`.
- ✅ El Namespace `staging` ya no existe (NotFound).
- ✅ El Pod `test-limitrange` tiene `requests` y `limits` asignados automáticamente.

---

## 8. Troubleshooting

### Problema 1: El Pod no se crea y aparece el error `forbidden: exceeded quota`

**Síntomas:**
```
Error from server (Forbidden): pods "webapp-xxx" is forbidden: exceeded quota: development-quota,
requested: requests.cpu=100m, used: requests.cpu=500m, limited: requests.cpu=500m
```
El Deployment existe pero muestra `0/X` Pods disponibles. Al revisar los eventos del ReplicaSet con `kubectl describe replicaset -n development`, se ve el error de cuota.

**Causa:**
La ResourceQuota del Namespace `development` ha alcanzado el límite de `requests.cpu` (500m) o `requests.memory` (512Mi). Cada nuevo Pod que se intenta crear supera el total acumulado permitido.

**Solución:**
```bash
# 1. Verificar el uso actual de la quota
kubectl describe resourcequota development-quota -n development

# 2. Identificar qué deployments consumen más recursos
kubectl get pods -n development -o custom-columns=\
"NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory"

# 3. Opción A: Reducir réplicas de un deployment existente para liberar cuota
kubectl scale deployment webapp -n development --replicas=1

# 4. Opción B: Aumentar el límite de la ResourceQuota (requiere permisos de admin)
kubectl edit resourcequota development-quota -n development
# Modificar el valor de requests.cpu a "1000m" y requests.memory a "1Gi"

# 5. Verificar que la quota tiene espacio disponible
kubectl describe resourcequota development-quota -n development
```

---

### Problema 2: El Namespace queda en estado `Terminating` indefinidamente

**Síntomas:**
```
NAME          STATUS        AGE
staging       Terminating   5m
```
Después de ejecutar `kubectl delete namespace staging`, el Namespace permanece en estado `Terminating` por más de 2-3 minutos sin completar la eliminación.

**Causa:**
Existen recursos con **finalizers** que no han podido ser procesados, o hay un controlador que no responde para completar el ciclo de terminación. En Minikube esto puede ocurrir si hay recursos con finalizers personalizados o si el API Server está bajo carga.

**Solución:**
```bash
# 1. Verificar qué recursos están bloqueando la terminación
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -I{} kubectl get {} -n staging --ignore-not-found 2>/dev/null

# 2. Verificar si hay finalizers en el namespace
kubectl get namespace staging -o json | jq '.spec.finalizers'

# 3. Si hay finalizers, eliminarlos manualmente con un patch
kubectl patch namespace staging \
  -p '{"spec":{"finalizers":[]}}' \
  --type=merge

# 4. Si el problema persiste, usar el API Server directamente para forzar la eliminación
kubectl get namespace staging -o json > /tmp/staging-ns.json
# Editar el archivo y eliminar el array "finalizers" en spec.finalizers
# Luego aplicar via curl al API Server local:
kubectl proxy &
PROXY_PID=$!
curl -k -H "Content-Type: application/json" \
  -X PUT \
  --data-binary @/tmp/staging-ns.json \
  http://127.0.0.1:8001/api/v1/namespaces/staging/finalize
kill $PROXY_PID

# 5. Verificar que el namespace fue eliminado
kubectl get namespaces | grep staging
```

> **Nota preventiva:** En entornos de laboratorio con Minikube, la mayoría de eliminaciones de Namespace se completan en menos de 60 segundos. Si usas `kubectl delete namespace staging --grace-period=0 --force`, ten en cuenta que esto puede dejar recursos huérfanos.

---

## 9. Limpieza del Entorno

Ejecuta los siguientes comandos para limpiar los recursos creados durante este laboratorio. **Conserva el clúster Minikube** ya que será reutilizado en laboratorios posteriores.

```bash
echo "=== Iniciando limpieza del Lab 04-00-01 ==="

# 1. Eliminar el pod de prueba del LimitRange (si aún existe)
kubectl delete pod test-limitrange -n development --ignore-not-found

# 2. Restaurar el contexto al namespace 'default'
kubectl config set-context --current --namespace=default

# 3. Eliminar el namespace 'development' y todos sus recursos (en cascada)
kubectl delete namespace development

# 4. Eliminar el namespace 'production' y todos sus recursos (en cascada)
kubectl delete namespace production

# 5. Verificar que los namespaces de laboratorio fueron eliminados
echo "=== Namespaces restantes ==="
kubectl get namespaces

# 6. Limpiar archivos YAML del laboratorio (opcional)
# rm -rf ~/k8s-labs/lab-04/

echo "=== Limpieza completada ==="
echo "Namespaces del sistema intactos: kube-system, kube-public, kube-node-lease, default"
```

> **Importante:** Los Namespaces del sistema (`kube-system`, `kube-public`, `kube-node-lease`, `default`) **no deben eliminarse**. Son parte de la infraestructura del clúster.

---

## 10. Resumen

En este laboratorio aplicaste los conceptos fundamentales de Namespaces de Kubernetes en un escenario práctico de organización multi-ambiente:

| Concepto practicado | Comando / Recurso clave |
|---------------------|------------------------|
| Crear Namespace imperativo | `kubectl create namespace <name>` |
| Crear Namespace declarativo | `apiVersion: v1 / kind: Namespace` |
| Cambiar namespace del contexto | `kubectl config set-context --current --namespace=<ns>` |
| Ver recursos en todos los NS | `kubectl get <resource> --all-namespaces` |
| Operar en un NS específico | `kubectl get <resource> -n <namespace>` |
| Limitar recursos por NS | `kind: ResourceQuota` con `spec.hard` |
| Valores por defecto de recursos | `kind: LimitRange` con `default` / `defaultRequest` |
| Eliminación en cascada | `kubectl delete namespace <name>` |

### Conceptos clave reforzados

- Los **Namespaces** son particiones lógicas que permiten aislamiento de nombres, RBAC y políticas de recursos sin necesidad de clústeres separados.
- El mismo nombre de recurso puede existir en diferentes Namespaces sin conflicto (ej.: tres Deployments llamados `webapp`).
- Los Namespaces del sistema (`kube-system`, `kube-public`, `kube-node-lease`) tienen propósitos específicos y no deben usarse para aplicaciones de usuario.
- Una **ResourceQuota** controla el consumo máximo de CPU, memoria y número de objetos en un Namespace.
- Un **LimitRange** asigna automáticamente valores de `requests`/`limits` a contenedores que no los especifican explícitamente.
- Al eliminar un Namespace, **todos sus recursos son eliminados en cascada** de forma automática.

### Recursos adicionales

- [Documentación oficial: Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Documentación oficial: ResourceQuotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Documentación oficial: LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [kubectl Cheat Sheet — Namespaces](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-context-and-configuration)

---

---

# Práctica complementaria 4.1: Separación lógica por ambiente

## Metadatos

| Campo        | Detalle                          |
|--------------|----------------------------------|
| **Duración** | 22 minutos                       |
| **Complejidad** | Fácil                         |
| **Nivel Bloom** | Aplicar (Apply)               |
| **Módulo**   | 4 — Namespaces y organización    |
| **Lab ID**   | 04-00-02                         |

---

## Descripción General

En este laboratorio simularás un escenario empresarial real donde dos equipos —**backend** y **frontend**— comparten el mismo clúster Kubernetes. Crearás namespaces dedicados con `ResourceQuotas` diferenciadas, desplegarás microservicios en cada namespace y demostrarás que la comunicación entre namespaces requiere el uso del FQDN completo del servicio (`service.namespace.svc.cluster.local`). Finalizarás con una auditoría de recursos usando `kubectl get all --all-namespaces`, consolidando la comprensión de la separación lógica como estrategia de organización profesional.

---

## Objetivos de Aprendizaje

- [ ] Crear namespaces `team-backend` y `team-frontend` con `ResourceQuotas` diferenciadas que reflejen necesidades distintas por equipo
- [ ] Desplegar microservicios independientes en cada namespace y verificar el aislamiento de nombres entre ellos
- [ ] Demostrar que la comunicación entre namespaces requiere el FQDN completo del servicio DNS interno de Kubernetes
- [ ] Configurar el namespace por defecto del contexto activo usando `kubectl config set-context`
- [ ] Generar un resumen de auditoría de todos los recursos del clúster con `kubectl get all --all-namespaces`

---

## Prerrequisitos

### Conocimientos previos

- Haber completado el laboratorio **04-00-01** (creación y gestión básica de Namespaces)
- Comprensión del concepto de Namespace como partición lógica en Kubernetes (Lección 4.1)
- Familiaridad básica con Pods, Deployments y Services en Kubernetes
- Comprensión introductoria de DNS interno de Kubernetes (formato `service.namespace.svc.cluster.local`)

### Acceso y herramientas requeridas

- Clúster Minikube operativo con **mínimo 2 nodos** (idealmente 3)
- `kubectl` versión 1.28.x o superior instalado y configurado
- Acceso a Internet para descarga de imágenes (`nginx:1.25`, `busybox:latest`)
- Terminal con permisos de administrador sobre el clúster

---

## Entorno del Laboratorio

### Requisitos de hardware

| Recurso    | Mínimo           | Recomendado       |
|------------|------------------|-------------------|
| CPU        | 4 núcleos físicos | 8 núcleos         |
| RAM        | 8 GB             | 16 GB             |
| Disco      | 40 GB libres (SSD) | 60 GB libres (SSD) |
| Red        | 10 Mbps          | 25 Mbps           |

### Software requerido

| Herramienta | Versión mínima |
|-------------|----------------|
| Minikube    | 1.31.x         |
| kubectl     | 1.28.x         |
| Docker Engine | 24.x         |

### Configuración inicial del entorno

Antes de comenzar, verifica que tu clúster esté operativo. Si aún no tienes un clúster multi-nodo iniciado, ejecuta:

```bash
# Iniciar clúster Minikube con 3 nodos (si no está ya corriendo)
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048
```

Verifica el estado del clúster:

```bash
# Verificar que los nodos están en estado Ready
kubectl get nodes
```

Salida esperada:

```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

Pre-descarga de imágenes (opcional, para entornos con conectividad limitada):

```bash
# Pre-descargar imágenes necesarias para el laboratorio
for img in nginx:1.25 busybox:latest; do
  docker pull $img
done
```

---

## Pasos del Laboratorio

### Paso 1: Crear los Namespaces para cada equipo

**Objetivo:** Establecer la separación lógica inicial creando los namespaces `team-backend` y `team-frontend` mediante manifiestos YAML declarativos.

#### Instrucciones

**1.1.** Crea el directorio de trabajo para este laboratorio:

```bash
mkdir -p ~/lab-04-00-02 && cd ~/lab-04-00-02
```

**1.2.** Crea el manifiesto YAML para ambos namespaces en un solo archivo:

```bash
cat <<'EOF' > namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-backend
  labels:
    equipo: backend
    ambiente: desarrollo
    lab: "04-00-02"
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-frontend
  labels:
    equipo: frontend
    ambiente: desarrollo
    lab: "04-00-02"
EOF
```

**1.3.** Aplica el manifiesto para crear ambos namespaces:

```bash
kubectl apply -f namespaces.yaml
```

**Salida esperada:**

```
namespace/team-backend created
namespace/team-frontend created
```

**1.4.** Verifica que los namespaces fueron creados correctamente:

```bash
kubectl get namespaces --show-labels | grep -E "team-backend|team-frontend"
```

**Salida esperada:**

```
team-backend    Active   Xs    ambiente=desarrollo,equipo=backend,lab=04-00-02
team-frontend   Active   Xs    ambiente=desarrollo,equipo=frontend,lab=04-00-02
```

#### Verificación

```bash
# Confirmar que los dos namespaces existen y están en estado Active
kubectl get ns team-backend team-frontend
```

Ambos namespaces deben mostrar `STATUS: Active`.

---

### Paso 2: Aplicar ResourceQuotas diferenciadas por equipo

**Objetivo:** Simular políticas de recursos distintas para cada equipo, reflejando que el equipo de backend requiere más recursos computacionales que el de frontend.

#### Instrucciones

**2.1.** Crea la `ResourceQuota` para el equipo de backend (mayor capacidad de cómputo):

```bash
cat <<'EOF' > quota-backend.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota-team-backend
  namespace: team-backend
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    configmaps: "10"
    secrets: "10"
    services: "5"
EOF
```

**2.2.** Crea la `ResourceQuota` para el equipo de frontend (capacidad más limitada):

```bash
cat <<'EOF' > quota-frontend.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota-team-frontend
  namespace: team-frontend
spec:
  hard:
    pods: "6"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    configmaps: "5"
    secrets: "5"
    services: "3"
EOF
```

**2.3.** Aplica ambas quotas:

```bash
kubectl apply -f quota-backend.yaml
kubectl apply -f quota-frontend.yaml
```

**Salida esperada:**

```
resourcequota/quota-team-backend created
resourcequota/quota-team-frontend created
```

**2.4.** Describe las quotas para confirmar su configuración:

```bash
# Ver quota del equipo backend
kubectl describe resourcequota quota-team-backend -n team-backend

# Ver quota del equipo frontend
kubectl describe resourcequota quota-team-frontend -n team-frontend
```

**Salida esperada (ejemplo para backend):**

```
Name:            quota-team-backend
Namespace:       team-backend
Resource         Used  Hard
--------         ----  ----
configmaps       0     10
limits.cpu       0     4
limits.memory    0     4Gi
pods             0     10
requests.cpu     0     2
requests.memory  0     2Gi
secrets          1     10
services         0     5
```

> **Nota:** El valor `secrets: 1` en `Used` es normal — Kubernetes crea automáticamente un Secret de tipo `kubernetes.io/service-account-token` en cada namespace.

#### Verificación

```bash
# Listar ResourceQuotas en ambos namespaces
kubectl get resourcequota -n team-backend
kubectl get resourcequota -n team-frontend
```

Ambas deben aparecer con `AGE` reciente y sin errores.

---

### Paso 3: Desplegar microservicios en el namespace `team-backend`

**Objetivo:** Crear un Deployment y un Service para el microservicio de backend, demostrando que los recursos quedan encapsulados dentro de su namespace.

#### Instrucciones

**3.1.** Crea el manifiesto del Deployment y Service para el equipo backend:

```bash
cat <<'EOF' > backend-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: team-backend
  labels:
    app: api-server
    equipo: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
        equipo: backend
    spec:
      containers:
      - name: api-server
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: team-backend
spec:
  selector:
    app: api-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

**3.2.** Aplica el manifiesto:

```bash
kubectl apply -f backend-app.yaml
```

**Salida esperada:**

```
deployment.apps/api-server created
service/api-server created
```

**3.3.** Verifica que los Pods del backend están corriendo:

```bash
kubectl get pods -n team-backend -l app=api-server
```

**Salida esperada:**

```
NAME                          READY   STATUS    RESTARTS   AGE
api-server-xxxxxxxxx-xxxxx    1/1     Running   0          Xs
api-server-xxxxxxxxx-xxxxx    1/1     Running   0          Xs
```

**3.4.** Verifica el Service creado:

```bash
kubectl get service api-server -n team-backend
```

**Salida esperada:**

```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
api-server   ClusterIP   10.xxx.xxx.xxx  <none>        80/TCP    Xs
```

#### Verificación

```bash
# Confirmar recursos en team-backend
kubectl get all -n team-backend
```

Debes ver el Deployment, ReplicaSet, 2 Pods y el Service del backend.

---

### Paso 4: Desplegar microservicios en el namespace `team-frontend`

**Objetivo:** Crear recursos con el **mismo nombre** (`api-server`) en el namespace `team-frontend` para demostrar que los namespaces permiten reutilizar nombres sin conflicto.

#### Instrucciones

**4.1.** Crea el manifiesto del Deployment y Service para el equipo frontend. Observa que el Deployment y Service se llaman también `api-server`, igual que en backend:

```bash
cat <<'EOF' > frontend-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: team-frontend
  labels:
    app: api-server
    equipo: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
        equipo: frontend
    spec:
      containers:
      - name: api-server
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "50m"
            memory: "32Mi"
          limits:
            cpu: "100m"
            memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: team-frontend
spec:
  selector:
    app: api-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

**4.2.** Aplica el manifiesto:

```bash
kubectl apply -f frontend-app.yaml
```

**Salida esperada:**

```
deployment.apps/api-server created
service/api-server created
```

> **Punto clave:** Kubernetes acepta sin error la creación de un Deployment y Service llamados `api-server` en `team-frontend`, aunque ya existan recursos con ese mismo nombre en `team-backend`. Esto demuestra el **aislamiento de nombres** entre namespaces.

**4.3.** Verifica los recursos del frontend:

```bash
kubectl get all -n team-frontend
```

**Salida esperada:**

```
NAME                              READY   STATUS    RESTARTS   AGE
pod/api-server-xxxxxxxxx-xxxxx    1/1     Running   0          Xs

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/api-server   ClusterIP   10.xxx.xxx.xxx  <none>        80/TCP    Xs

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/api-server   1/1     1            1           Xs

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/api-server-xxxxxxxxx    1         1         1       Xs
```

#### Verificación

```bash
# Confirmar que existen dos Services llamados "api-server" en distintos namespaces
kubectl get service api-server -n team-backend
kubectl get service api-server -n team-frontend
```

Ambos comandos deben devolver un Service con IPs de clúster **diferentes**, demostrando que son recursos independientes.

---

### Paso 5: Demostrar comunicación entre namespaces mediante FQDN

**Objetivo:** Probar que un Pod en `team-frontend` **no puede resolver** el nombre corto `api-server` del backend, pero **sí puede** acceder a él usando el FQDN completo `api-server.team-backend.svc.cluster.local`.

#### Instrucciones

**5.1.** Lanza un Pod temporal de diagnóstico (`busybox`) en el namespace `team-frontend`:

```bash
kubectl run debug-pod \
  --image=busybox:latest \
  --restart=Never \
  --namespace=team-frontend \
  --command -- sleep 3600
```

**Salida esperada:**

```
pod/debug-pod created
```

**5.2.** Espera a que el Pod esté en estado `Running`:

```bash
kubectl wait --for=condition=Ready pod/debug-pod -n team-frontend --timeout=60s
```

**5.3.** Intenta resolver el nombre corto `api-server` desde `team-frontend`. Este nombre debería resolver al Service del **frontend**, no al del backend:

```bash
kubectl exec -n team-frontend debug-pod -- nslookup api-server
```

**Salida esperada (resuelve al Service del MISMO namespace):**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      api-server
Address 1: 10.xxx.xxx.xxx api-server.team-frontend.svc.cluster.local
```

> **Observación:** El nombre corto `api-server` resuelve al Service dentro del **mismo namespace** (`team-frontend`). Para acceder al backend, se debe usar el FQDN completo.

**5.4.** Ahora accede al Service del backend usando el FQDN completo:

```bash
kubectl exec -n team-frontend debug-pod -- nslookup api-server.team-backend.svc.cluster.local
```

**Salida esperada:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      api-server.team-backend.svc.cluster.local
Address 1: 10.xxx.xxx.xxx api-server.team-backend.svc.cluster.local
```

**5.5.** Confirma la conectividad HTTP al backend usando `wget` con el FQDN:

```bash
kubectl exec -n team-frontend debug-pod -- wget -qO- --timeout=5 http://api-server.team-backend.svc.cluster.local
```

**Salida esperada:**

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</head>
...
</html>
```

**5.6.** Para comparar, verifica también la conectividad al frontend (nombre corto):

```bash
kubectl exec -n team-frontend debug-pod -- wget -qO- --timeout=5 http://api-server
```

**Salida esperada:** La misma página de nginx, pero esta vez sirviendo desde el Service de `team-frontend`.

#### Verificación

```bash
# Resumen de la demostración DNS
echo "=== Resolución nombre corto (resuelve en namespace local) ==="
kubectl exec -n team-frontend debug-pod -- nslookup api-server 2>/dev/null | grep Address

echo "=== Resolución FQDN completo (acceso a otro namespace) ==="
kubectl exec -n team-frontend debug-pod -- nslookup api-server.team-backend.svc.cluster.local 2>/dev/null | grep Address
```

Las dos resoluciones deben devolver **IPs de clúster distintas**, confirmando que apuntan a Services diferentes.

---

### Paso 6: Configurar el namespace por defecto del contexto con `kubectl config`

**Objetivo:** Cambiar el namespace por defecto del contexto activo de `kubectl` para evitar escribir `-n team-backend` en cada comando, simulando el flujo de trabajo de un administrador dedicado a un equipo.

#### Instrucciones

**6.1.** Primero, visualiza el contexto actual de kubectl:

```bash
kubectl config current-context
```

**Salida esperada:**

```
minikube
```

**6.2.** Muestra la configuración completa del contexto actual:

```bash
kubectl config get-contexts
```

**Salida esperada:**

```
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   
```

El campo `NAMESPACE` está vacío, lo que significa que usa `default` por defecto.

**6.3.** Cambia el namespace por defecto del contexto activo a `team-backend`:

```bash
kubectl config set-context --current --namespace=team-backend
```

**Salida esperada:**

```
Context "minikube" modified.
```

**6.4.** Verifica el cambio:

```bash
kubectl config get-contexts
```

**Salida esperada:**

```
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   team-backend
```

**6.5.** Ahora, ejecuta comandos sin especificar `-n` y observa que operan en `team-backend` automáticamente:

```bash
# Sin -n, ahora opera en team-backend por defecto
kubectl get pods
kubectl get services
```

**Salida esperada:** Muestra los Pods y Services del namespace `team-backend` sin necesidad de `-n`.

**6.6.** Restaura el contexto al namespace `default` al finalizar esta sección:

```bash
kubectl config set-context --current --namespace=default
```

**Salida esperada:**

```
Context "minikube" modified.
```

#### Verificación

```bash
# Confirmar que el contexto volvió a default
kubectl config view --minify | grep namespace
```

**Salida esperada:**

```
    namespace: default
```

---

### Paso 7: Auditoría de recursos — vista global del clúster

**Objetivo:** Generar una vista completa de todos los recursos del clúster usando `kubectl get all --all-namespaces` y analizar el estado de utilización de las ResourceQuotas.

#### Instrucciones

**7.1.** Lista todos los recursos de todos los namespaces en el clúster:

```bash
kubectl get all --all-namespaces
```

**Salida esperada (extracto):**

```
NAMESPACE       NAME                                  READY   STATUS    RESTARTS   AGE
kube-system     pod/coredns-xxxxxxxxx-xxxxx           1/1     Running   0          Xd
kube-system     pod/etcd-minikube                     1/1     Running   0          Xd
team-backend    pod/api-server-xxxxxxxxx-xxxxx        1/1     Running   0          Xm
team-backend    pod/api-server-xxxxxxxxx-xxxxx        1/1     Running   0          Xm
team-frontend   pod/api-server-xxxxxxxxx-xxxxx        1/1     Running   0          Xm
team-frontend   pod/debug-pod                         1/1     Running   0          Xm
...

NAMESPACE       NAME                    TYPE        CLUSTER-IP      PORT(S)   AGE
team-backend    service/api-server      ClusterIP   10.xxx.xxx.xxx  80/TCP    Xm
team-frontend   service/api-server      ClusterIP   10.xxx.xxx.xxx  80/TCP    Xm
...
```

**7.2.** Filtra la vista para ver solo los recursos de los namespaces de equipo:

```bash
kubectl get all -n team-backend && echo "---" && kubectl get all -n team-frontend
```

**7.3.** Revisa el estado actual de utilización de las ResourceQuotas para cada equipo:

```bash
# Estado de utilización de recursos - Backend
echo "=== QUOTA TEAM-BACKEND ==="
kubectl describe resourcequota quota-team-backend -n team-backend | grep -A 20 "Resource"

# Estado de utilización de recursos - Frontend
echo "=== QUOTA TEAM-FRONTEND ==="
kubectl describe resourcequota quota-team-frontend -n team-frontend | grep -A 20 "Resource"
```

**Salida esperada (backend con 2 Pods corriendo):**

```
=== QUOTA TEAM-BACKEND ===
Resource         Used    Hard
--------         ----    ----
configmaps       1       10
limits.cpu       400m    4
limits.memory    256Mi   4Gi
pods             2       10
requests.cpu     200m    2
requests.memory  128Mi   2Gi
secrets          1       10
services         1       5
```

**7.4.** Genera un resumen de namespaces con sus quotas en formato tabular:

```bash
echo "=== RESUMEN DE UTILIZACIÓN DE RECURSOS POR NAMESPACE ==="
echo ""
for ns in team-backend team-frontend; do
  echo "Namespace: $ns"
  kubectl get resourcequota -n "$ns" -o custom-columns=\
'NOMBRE:.metadata.name,PODS-USADOS:.status.used.pods,PODS-LIMITE:.spec.hard.pods,CPU-USADA:.status.used["requests.cpu"],CPU-LIMITE:.spec.hard["requests.cpu"]'
  echo ""
done
```

**7.5.** Lista todos los namespaces del clúster con sus labels para una visión completa:

```bash
kubectl get namespaces --show-labels
```

**Salida esperada:**

```
NAME              STATUS   AGE   LABELS
default           Active   Xd    kubernetes.io/metadata.name=default
kube-node-lease   Active   Xd    kubernetes.io/metadata.name=kube-node-lease
kube-public       Active   Xd    kubernetes.io/metadata.name=kube-public
kube-system       Active   Xd    kubernetes.io/metadata.name=kube-system
team-backend      Active   Xm    ambiente=desarrollo,equipo=backend,kubernetes.io/metadata.name=team-backend,lab=04-00-02
team-frontend     Active   Xm    ambiente=desarrollo,equipo=frontend,kubernetes.io/metadata.name=team-frontend,lab=04-00-02
```

#### Verificación

```bash
# Contar total de Pods por namespace de equipo
echo "Pods en team-backend: $(kubectl get pods -n team-backend --no-headers 2>/dev/null | wc -l)"
echo "Pods en team-frontend: $(kubectl get pods -n team-frontend --no-headers 2>/dev/null | wc -l)"
```

**Salida esperada:**

```
Pods en team-backend: 2
Pods en team-frontend: 2
```

---

## Validación y Pruebas

Ejecuta la siguiente secuencia de validación para confirmar que todos los objetivos del laboratorio se han cumplido correctamente:

```bash
#!/bin/bash
echo "============================================"
echo "  VALIDACIÓN LAB 04-00-02"
echo "============================================"
echo ""

# Verificación 1: Namespaces creados
echo "[1/5] Verificando namespaces..."
for ns in team-backend team-frontend; do
  STATUS=$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$STATUS" = "Active" ]; then
    echo "  ✅ Namespace $ns: Active"
  else
    echo "  ❌ Namespace $ns: NO encontrado o inactivo"
  fi
done
echo ""

# Verificación 2: ResourceQuotas aplicadas
echo "[2/5] Verificando ResourceQuotas..."
for ns in team-backend team-frontend; do
  COUNT=$(kubectl get resourcequota -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$COUNT" -ge 1 ]; then
    echo "  ✅ ResourceQuota en $ns: encontrada"
  else
    echo "  ❌ ResourceQuota en $ns: NO encontrada"
  fi
done
echo ""

# Verificación 3: Pods corriendo
echo "[3/5] Verificando Pods en ejecución..."
BACKEND_PODS=$(kubectl get pods -n team-backend -l app=api-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
FRONTEND_PODS=$(kubectl get pods -n team-frontend -l app=api-server --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
echo "  Pods Running en team-backend: $BACKEND_PODS (esperado: 2)"
echo "  Pods Running en team-frontend: $FRONTEND_PODS (esperado: 1)"
[ "$BACKEND_PODS" -eq 2 ] && echo "  ✅ Backend OK" || echo "  ❌ Backend: revisar Pods"
[ "$FRONTEND_PODS" -eq 1 ] && echo "  ✅ Frontend OK" || echo "  ❌ Frontend: revisar Pods"
echo ""

# Verificación 4: Services con mismo nombre en distintos namespaces
echo "[4/5] Verificando aislamiento de nombres (Services)..."
IP_BACK=$(kubectl get svc api-server -n team-backend -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
IP_FRONT=$(kubectl get svc api-server -n team-frontend -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$IP_BACK" ] && [ -n "$IP_FRONT" ] && [ "$IP_BACK" != "$IP_FRONT" ]; then
  echo "  ✅ Mismo nombre 'api-server' en diferentes namespaces con IPs distintas"
  echo "     team-backend:  $IP_BACK"
  echo "     team-frontend: $IP_FRONT"
else
  echo "  ❌ Error en aislamiento de Services"
fi
echo ""

# Verificación 5: Resolución DNS entre namespaces
echo "[5/5] Verificando resolución FQDN entre namespaces..."
DNS_RESULT=$(kubectl exec -n team-frontend debug-pod -- nslookup api-server.team-backend.svc.cluster.local 2>/dev/null | grep "Address" | tail -1)
if [ -n "$DNS_RESULT" ]; then
  echo "  ✅ FQDN resuelto correctamente: $DNS_RESULT"
else
  echo "  ❌ No se pudo resolver el FQDN. Verifica que debug-pod esté Running."
fi
echo ""
echo "============================================"
echo "  FIN DE VALIDACIÓN"
echo "============================================"
```

Guarda el script y ejecútalo:

```bash
chmod +x validate.sh 2>/dev/null || true
bash validate.sh
```

**Resultado esperado:** Todos los ítems deben mostrar `✅`.

---

## Resolución de Problemas

### Problema 1: Los Pods no inician por exceder la ResourceQuota

**Síntomas:**
```
Error from server (Forbidden): pods "api-server-xxx" is forbidden:
exceeded quota: quota-team-backend, requested: limits.cpu=200m,
have: limits.cpu=3800m, limited: limits.cpu=4
```
O bien, el Deployment muestra `0/2` Pods disponibles y al describir el ReplicaSet aparece el mensaje de quota excedida.

**Causa:**
Los contenedores del manifiesto no especifican `resources.requests` y `resources.limits`, o los valores especificados superan el límite de la `ResourceQuota`. Cuando una `ResourceQuota` está activa en un namespace, **todos los Pods deben declarar explícitamente sus recursos**, de lo contrario son rechazados.

**Solución:**
```bash
# 1. Verifica el estado actual de utilización de la quota
kubectl describe resourcequota -n team-backend

# 2. Edita el Deployment para asegurarte de que los recursos estén definidos
kubectl edit deployment api-server -n team-backend
# Asegúrate de que cada contenedor tenga:
# resources:
#   requests:
#     cpu: "100m"
#     memory: "64Mi"
#   limits:
#     cpu: "200m"
#     memory: "128Mi"

# 3. Verifica que los Pods se crean tras la corrección
kubectl rollout status deployment/api-server -n team-backend
```

---

### Problema 2: La resolución DNS del FQDN falla desde el Pod de diagnóstico

**Síntomas:**
```
nslookup: can't resolve 'api-server.team-backend.svc.cluster.local'
```
O el comando `wget` al FQDN devuelve `wget: bad address`.

**Causa:**
Existen dos causas comunes: (a) el Pod `debug-pod` no está en estado `Running` (está en `Pending` o `ContainerCreating`), o (b) CoreDNS no está operativo en el namespace `kube-system`, lo que impide la resolución de nombres internos.

**Solución:**
```bash
# 1. Verifica el estado del Pod de diagnóstico
kubectl get pod debug-pod -n team-frontend

# Si está en Pending, describe el Pod para ver el motivo
kubectl describe pod debug-pod -n team-frontend

# 2. Si el Pod está Running pero el DNS falla, verifica CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 3. Si CoreDNS no está Running, reinícialo
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system

# 4. Si el Pod debug-pod no existe, recréalo
kubectl delete pod debug-pod -n team-frontend --ignore-not-found
kubectl run debug-pod \
  --image=busybox:latest \
  --restart=Never \
  --namespace=team-frontend \
  --command -- sleep 3600
kubectl wait --for=condition=Ready pod/debug-pod -n team-frontend --timeout=60s

# 5. Reintenta la resolución DNS
kubectl exec -n team-frontend debug-pod -- nslookup api-server.team-backend.svc.cluster.local
```

---

## Limpieza del Entorno

> **Nota importante:** Los recursos creados en este laboratorio pueden ser reutilizados en laboratorios posteriores del módulo 4. Si deseas conservarlos, omite los pasos de limpieza. Si necesitas liberar recursos, ejecuta los siguientes comandos.

```bash
# 1. Eliminar el Pod de diagnóstico
kubectl delete pod debug-pod -n team-frontend --ignore-not-found

# 2. Eliminar los recursos de aplicación (Deployments y Services)
kubectl delete -f backend-app.yaml --ignore-not-found
kubectl delete -f frontend-app.yaml --ignore-not-found

# 3. Eliminar las ResourceQuotas
kubectl delete -f quota-backend.yaml --ignore-not-found
kubectl delete -f quota-frontend.yaml --ignore-not-found

# 4. Eliminar los Namespaces (esto elimina TODOS los recursos dentro de ellos)
kubectl delete -f namespaces.yaml --ignore-not-found

# 5. Asegurarse de que el contexto volvió al namespace default
kubectl config set-context --current --namespace=default

# 6. Verificar limpieza
echo "Namespaces restantes:"
kubectl get namespaces
```

**Salida esperada tras limpieza:**

```
Namespaces restantes:
NAME              STATUS   AGE
default           Active   Xd
kube-node-lease   Active   Xd
kube-public       Active   Xd
kube-system       Active   Xd
```

```bash
# 7. (Opcional) Limpiar archivos del directorio de trabajo
cd ~ && rm -rf ~/lab-04-00-02
```

---

## Resumen

En este laboratorio aplicaste una estrategia de organización por namespaces que simula un entorno empresarial real con múltiples equipos. Los conceptos clave demostrados fueron:

| Concepto | Lo que demostraste |
|---|---|
| **Aislamiento de nombres** | Dos recursos llamados `api-server` coexisten sin conflicto en `team-backend` y `team-frontend` |
| **ResourceQuota diferenciada** | El equipo de backend recibe el doble de capacidad de cómputo que el de frontend |
| **DNS entre namespaces** | El nombre corto resuelve en el namespace local; el FQDN completo permite cruzar namespaces |
| **`kubectl config set-context`** | Cambiar el namespace por defecto agiliza el trabajo operativo por equipo |
| **Auditoría global** | `kubectl get all --all-namespaces` ofrece una vista completa del estado del clúster |

### Conceptos clave a recordar

- Los **Namespaces son particiones lógicas** — comparten la infraestructura física pero aíslan nombres, permisos y cuotas.
- El **FQDN completo** `<service>.<namespace>.svc.cluster.local` es el mecanismo estándar para comunicación entre namespaces.
- Las **ResourceQuotas** requieren que todos los Pods declaren `requests` y `limits` de CPU/memoria cuando están activas.
- `kubectl config set-context --current --namespace=<ns>` modifica el contexto activo y persiste entre comandos.
- `kubectl get all --all-namespaces` es la herramienta de auditoría rápida más útil para administradores de clúster.

### Recursos adicionales

- [Documentación oficial: Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Documentación oficial: Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Documentación oficial: DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Documentación oficial: Configurar acceso a múltiples clústeres](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

---
