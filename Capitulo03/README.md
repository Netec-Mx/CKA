# Mantenimiento de nodos y reprogramación de workloads en Kubernetes

## Metadatos

| Campo         | Valor                                      |
|---------------|--------------------------------------------|
| **Duración**  | 67 minutos                                 |
| **Complejidad** | Media                                    |
| **Nivel Bloom** | Aplicar (Apply)                          |
| **Módulo**    | 3 — Gestión de Nodos y Mantenimiento       |
| **Lab ID**    | 03-00-01                                   |

---

## Descripción General

En este laboratorio simularás un escenario real de mantenimiento de nodos en un clúster Kubernetes multi-nodo. Ejecutarás el ciclo completo de operaciones `cordon → drain → uncordon` sobre un worker node, observando en tiempo real cómo el scheduler reprograma los workloads hacia los nodos disponibles. Además, crearás un **PodDisruptionBudget (PDB)** para experimentar cómo Kubernetes protege la disponibilidad mínima de una aplicación durante el drenado, y resolverás un escenario de troubleshooting donde el drain falla debido a restricciones del PDB.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Ejecutar el flujo completo de mantenimiento de nodos (`cordon`, `drain`, `uncordon`) y explicar el impacto de cada operación sobre el scheduling de Pods
- [ ] Verificar el estado del clúster antes y después de operaciones de mantenimiento usando `kubectl get nodes`, `kubectl describe node`, `kubectl get events` y `kubectl top nodes`
- [ ] Observar y analizar la reprogramación automática de workloads cuando un nodo es drenado, incluyendo el comportamiento de los DaemonSets
- [ ] Implementar un PodDisruptionBudget y demostrar cómo protege la disponibilidad mínima de una aplicación durante el drenado de un nodo
- [ ] Diagnosticar y resolver un fallo de `kubectl drain` causado por restricciones de un PodDisruptionBudget

---

## Prerrequisitos

### Conocimiento Previo

| Área | Nivel Requerido |
|------|----------------|
| Conceptos básicos de Pods y Deployments | Completo (Lab 02-00-01) |
| Uso de `kubectl get`, `describe`, `apply` | Básico |
| Comprensión del rol del Kubernetes Scheduler | Conceptual |
| Estructura de manifiestos YAML | Básico |

### Acceso y Herramientas

| Herramienta | Versión Mínima | Verificación |
|-------------|---------------|--------------|
| `kubectl`   | 1.28.x        | `kubectl version --client` |
| Minikube    | 1.31.x        | `minikube version` |
| Docker Engine | 24.x        | `docker version` |
| `curl`      | 7.x           | `curl --version` |

> **Prerrequisito crítico:** Este laboratorio requiere un clúster Minikube con **exactamente 3 nodos** (1 control-plane + 2 workers). Si tienes un clúster existente de laboratorios anteriores con esta configuración, puedes reutilizarlo. Si no, sigue las instrucciones de configuración del entorno a continuación.

---

## Entorno de Laboratorio

### Especificaciones de Hardware Recomendadas

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU (núcleos físicos) | 4 | 8 |
| RAM disponible | 8 GB | 16 GB |
| Almacenamiento libre | 40 GB | 60 GB |
| Conexión a Internet | 10 Mbps | 25 Mbps |

> **Nota para usuarios con 8 GB de RAM:** Cierra aplicaciones no esenciales (navegadores con múltiples pestañas, IDEs pesados) antes de iniciar. El clúster de 3 nodos consumirá aproximadamente 6 GB de RAM y 6 núcleos de CPU del sistema host.

### Configuración del Entorno

#### Paso de Configuración A: Verificar o Crear el Clúster Multi-Nodo

```bash
# Verificar si ya existe un clúster Minikube con 3 nodos
minikube status

# Si el clúster existe y tiene 3 nodos, simplemente asegúrate de que esté corriendo:
minikube start

# Si necesitas crear el clúster desde cero (o si solo tienes 1 nodo):
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que los 3 nodos están activos
kubectl get nodes
```

**Salida esperada después de la configuración:**
```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

#### Paso de Configuración B: Pre-descargar Imágenes (Opcional pero Recomendado)

```bash
# Pre-descargar imágenes para evitar timeouts durante el laboratorio
for img in nginx:1.25 nginx:1.26 busybox:latest; do
  docker pull $img
done
```

#### Paso de Configuración C: Crear el Namespace de Trabajo

```bash
# Crear un namespace dedicado para este laboratorio
kubectl create namespace lab03

# Verificar la creación
kubectl get namespace lab03
```

---

## Desarrollo del Laboratorio

### Parte 1: Inspección del Estado Inicial del Clúster

**Duración estimada:** 10 minutos

**Objetivo:** Establecer una línea base del estado del clúster antes de cualquier operación de mantenimiento, aplicando los comandos de diagnóstico aprendidos en la Lección 3.1.

---

#### Paso 1.1 — Inspección General de los Nodos

**Objetivo:** Obtener una visión completa del estado actual de todos los nodos y sus condiciones de salud.

**Instrucciones:**

1. Lista todos los nodos con información extendida:

```bash
kubectl get nodes -o wide
```

2. Examina las condiciones de cada nodo worker. Reemplaza `minikube-m02` con el nombre real de tu primer worker node:

```bash
kubectl describe node minikube-m02
```

3. Filtra específicamente las condiciones de salud y la capacidad del nodo:

```bash
# Ver solo las condiciones del nodo
kubectl describe node minikube-m02 | grep -A 20 "Conditions:"

# Ver capacidad y recursos asignables
kubectl describe node minikube-m02 | grep -A 10 "Capacity:\|Allocatable:"
```

4. Repite la inspección para el segundo worker node:

```bash
kubectl describe node minikube-m03 | grep -A 20 "Conditions:"
```

**Salida esperada (ejemplo):**
```
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP    OS-IMAGE
minikube       Ready    control-plane   10m   v1.28.3   192.168.49.2   Ubuntu 22.04
minikube-m02   Ready    <none>          8m    v1.28.3   192.168.49.3   Ubuntu 22.04
minikube-m03   Ready    <none>          7m    v1.28.3   192.168.49.4   Ubuntu 22.04
```

```
Conditions:
  Type             Status  LastHeartbeatTime   Reason
  ----             ------  -----------------   ------
  MemoryPressure   False   ...                 KubeletHasSufficientMemory
  DiskPressure     False   ...                 KubeletHasSufficientDisk
  PIDPressure      False   ...                 KubeletHasSufficientPID
  Ready            True    ...                 KubeletReady
```

**Verificación:** Todos los nodos deben mostrar `STATUS: Ready` y todas las condiciones de presión deben ser `False`. Si algún nodo muestra `NotReady`, espera 1-2 minutos y vuelve a ejecutar `kubectl get nodes`.

---

#### Paso 1.2 — Despliegue de Workloads de Prueba

**Objetivo:** Crear múltiples Deployments distribuidos entre los nodos para observar la reprogramación durante el mantenimiento.

**Instrucciones:**

1. Crea el archivo de manifiesto para los Deployments de prueba:

```bash
cat <<'EOF' > ~/lab03-deployments.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-web
  namespace: lab03
  labels:
    app: app-web
    lab: "03-00-01"
spec:
  replicas: 4
  selector:
    matchLabels:
      app: app-web
  template:
    metadata:
      labels:
        app: app-web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-backend
  namespace: lab03
  labels:
    app: app-backend
    lab: "03-00-01"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-backend
  template:
    metadata:
      labels:
        app: app-backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"
EOF
```

2. Aplica los manifiestos:

```bash
kubectl apply -f ~/lab03-deployments.yaml
```

3. Espera a que todos los Pods estén en estado `Running`:

```bash
# Esperar hasta que todos los Pods estén listos (timeout 90 segundos)
kubectl wait --for=condition=ready pod -l lab=03-00-01 -n lab03 --timeout=90s

# Verificar el estado de los Pods y en qué nodo se ejecutan
kubectl get pods -n lab03 -o wide
```

4. Registra mentalmente (o en un archivo de notas) la distribución inicial de Pods entre los nodos. Esto será tu **línea base** para comparar después del drain.

**Salida esperada:**
```
NAME                           READY   STATUS    NODE
app-web-xxxxx-aaaaa            1/1     Running   minikube-m02
app-web-xxxxx-bbbbb            1/1     Running   minikube-m03
app-web-xxxxx-ccccc            1/1     Running   minikube-m02
app-web-xxxxx-ddddd            1/1     Running   minikube-m03
app-backend-yyyyy-aaaaa        1/1     Running   minikube-m02
app-backend-yyyyy-bbbbb        1/1     Running   minikube-m03
app-backend-yyyyy-ccccc        1/1     Running   minikube-m02
```

**Verificación:** Debes observar que los Pods están distribuidos entre `minikube-m02` y `minikube-m03`. Es normal que la distribución no sea perfectamente equitativa.

---

#### Paso 1.3 — Añadir Etiquetas de Identificación a los Nodos

**Objetivo:** Practicar la gestión de etiquetas en nodos (Lección 3.1) para identificar claramente los roles durante el laboratorio.

**Instrucciones:**

1. Etiqueta los nodos worker para identificarlos fácilmente:

```bash
kubectl label node minikube-m02 lab03/role=target-maintenance
kubectl label node minikube-m03 lab03/role=active-worker
```

2. Verifica las etiquetas aplicadas:

```bash
kubectl get nodes --show-labels | grep -E "NAME|minikube-m0"
```

3. Añade una anotación de mantenimiento al nodo objetivo:

```bash
kubectl annotate node minikube-m02 \
  mantenimiento/motivo="actualizacion-kernel" \
  mantenimiento/responsable="equipo-infra" \
  mantenimiento/fecha-inicio="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

4. Verifica la anotación:

```bash
kubectl describe node minikube-m02 | grep -A 5 "Annotations:"
```

**Verificación:** El comando `kubectl get nodes --show-labels` debe mostrar las etiquetas `lab03/role=target-maintenance` y `lab03/role=active-worker` en los nodos correspondientes.

---

### Parte 2: Operación cordon — Marcar el Nodo como No Programable

**Duración estimada:** 8 minutos

**Objetivo:** Ejecutar `kubectl cordon` sobre el nodo de mantenimiento y verificar que el scheduler deja de asignar nuevos Pods a ese nodo, sin afectar los Pods existentes.

---

#### Paso 2.1 — Ejecutar cordon en el Nodo de Mantenimiento

**Objetivo:** Comprender qué hace `cordon` y verificar su efecto inmediato.

**Instrucciones:**

1. Ejecuta el cordon sobre el primer worker node:

```bash
kubectl cordon minikube-m02
```

2. Verifica inmediatamente el cambio de estado del nodo:

```bash
kubectl get nodes
```

3. Inspecciona el campo `Taints` en la descripción del nodo para entender el mecanismo interno:

```bash
kubectl describe node minikube-m02 | grep -A 5 "Taints:"
```

**Salida esperada:**
```
NAME           STATUS                     ROLES           AGE
minikube       Ready                      control-plane   Xm
minikube-m02   Ready,SchedulingDisabled   <none>          Xm
minikube-m03   Ready                      <none>          Xm
```

```
Taints: node.kubernetes.io/unschedulable:NoSchedule
```

> **Concepto clave:** `cordon` añade automáticamente el taint `node.kubernetes.io/unschedulable:NoSchedule` al nodo. Este taint impide que el scheduler asigne nuevos Pods al nodo. Los Pods **ya en ejecución no se ven afectados** — siguen corriendo normalmente.

4. Verifica que los Pods existentes siguen ejecutándose en el nodo cordoned:

```bash
kubectl get pods -n lab03 -o wide | grep minikube-m02
```

**Verificación:** El nodo `minikube-m02` debe aparecer con el estado `Ready,SchedulingDisabled`. Los Pods que ya estaban en ese nodo deben seguir en estado `Running`.

---

#### Paso 2.2 — Verificar que Nuevos Pods No Se Programan en el Nodo Cordoned

**Objetivo:** Confirmar experimentalmente el comportamiento del scheduler después del cordon.

**Instrucciones:**

1. Escala el Deployment `app-web` para forzar la creación de nuevos Pods:

```bash
kubectl scale deployment app-web -n lab03 --replicas=6
```

2. Observa dónde se programan los nuevos Pods:

```bash
kubectl get pods -n lab03 -o wide
```

3. Verifica que todos los Pods **nuevos** se asignaron a `minikube-m03` y no a `minikube-m02`:

```bash
# Contar Pods por nodo
kubectl get pods -n lab03 -o wide | awk 'NR>1 {print $7}' | sort | uniq -c
```

**Salida esperada:**
```
# Los 2 nuevos Pods deben estar en minikube-m03
NAME                       READY   STATUS    NODE
app-web-xxxxx-aaaaa        1/1     Running   minikube-m02  # Pod original
app-web-xxxxx-bbbbb        1/1     Running   minikube-m03  # Pod original
app-web-xxxxx-ccccc        1/1     Running   minikube-m02  # Pod original
app-web-xxxxx-ddddd        1/1     Running   minikube-m03  # Pod original
app-web-xxxxx-eeeee        1/1     Running   minikube-m03  # Pod NUEVO
app-web-xxxxx-fffff        1/1     Running   minikube-m03  # Pod NUEVO
```

4. Regresa el Deployment a 4 réplicas:

```bash
kubectl scale deployment app-web -n lab03 --replicas=4
```

**Verificación:** Los 2 nuevos Pods creados deben estar **exclusivamente** en `minikube-m03`. Si algún Pod nuevo apareció en `minikube-m02`, verifica que el cordon se ejecutó correctamente.

---

### Parte 3: Creación del PodDisruptionBudget

**Duración estimada:** 10 minutos

**Objetivo:** Implementar un PodDisruptionBudget para proteger la disponibilidad mínima de `app-web` durante el drenado del nodo.

---

#### Paso 3.1 — Crear el PodDisruptionBudget

**Objetivo:** Entender la estructura de un PDB y cómo `minAvailable` protege la disponibilidad durante disrupciones voluntarias.

**Instrucciones:**

1. Crea el manifiesto del PodDisruptionBudget:

```bash
cat <<'EOF' > ~/lab03-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-app-web
  namespace: lab03
  labels:
    lab: "03-00-01"
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: app-web
EOF
```

> **Explicación del PDB:** Este PDB garantiza que al menos **3 réplicas** de `app-web` estén disponibles en todo momento durante disrupciones voluntarias (como un drain). Con 4 réplicas totales, esto significa que como máximo 1 Pod puede ser eliminado a la vez.

2. Aplica el PDB:

```bash
kubectl apply -f ~/lab03-pdb.yaml
```

3. Verifica el estado del PDB:

```bash
kubectl get pdb -n lab03
```

4. Describe el PDB para ver su estado detallado:

```bash
kubectl describe pdb pdb-app-web -n lab03
```

**Salida esperada:**
```
NAME          MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
pdb-app-web   3               N/A               1                     Xs
```

```
Name:           pdb-app-web
Namespace:      lab03
Min available:  3
Selector:       app=app-web
Status:
    Allowed disruptions:  1
    Current:              4
    Desired:              3
    Total:                4
```

> **Dato clave:** `ALLOWED DISRUPTIONS: 1` significa que el drain puede eliminar como máximo 1 Pod de `app-web` a la vez. Si `minikube-m02` tiene 2 Pods de `app-web`, el drain se bloqueará al intentar eliminar el segundo.

**Verificación:** El campo `ALLOWED DISRUPTIONS` debe mostrar `1` (dado que tenemos 4 réplicas y `minAvailable: 3`). Si muestra `0`, verifica que todos los Pods estén en estado `Running`.

---

#### Paso 3.2 — Crear un PDB Más Restrictivo para el Escenario de Troubleshooting

**Objetivo:** Preparar el escenario donde el drain fallará, para practicar el troubleshooting en la Parte 5.

**Instrucciones:**

1. Crea un segundo PDB para `app-backend` con una restricción más agresiva:

```bash
cat <<'EOF' > ~/lab03-pdb-restrictivo.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-app-backend-strict
  namespace: lab03
  labels:
    lab: "03-00-01"
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: app-backend
EOF
```

> **¿Por qué fallará el drain?** `app-backend` tiene 3 réplicas y el PDB requiere `minAvailable: 3`. Esto significa `ALLOWED DISRUPTIONS: 0` — no se puede eliminar **ningún** Pod. El drain no podrá proceder con este Deployment.

2. Aplica el PDB restrictivo:

```bash
kubectl apply -f ~/lab03-pdb-restrictivo.yaml
```

3. Verifica el estado de ambos PDBs:

```bash
kubectl get pdb -n lab03
```

**Salida esperada:**
```
NAME                      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
pdb-app-web               3               N/A               1                     Xm
pdb-app-backend-strict    3               N/A               0                     Xs
```

**Verificación:** `pdb-app-backend-strict` debe mostrar `ALLOWED DISRUPTIONS: 0`. Este es el PDB que bloqueará el drain en la Parte 5.

---

### Parte 4: Operación drain — Drenado del Nodo

**Duración estimada:** 15 minutos

**Objetivo:** Ejecutar `kubectl drain` observando la migración de Pods y el comportamiento de los DaemonSets. Analizar los eventos generados durante el proceso.

---

#### Paso 4.1 — Preparar el Monitoreo en Tiempo Real

**Objetivo:** Establecer una ventana de monitoreo para observar la reprogramación de Pods durante el drain.

**Instrucciones:**

1. Abre una segunda terminal (o usa `tmux`/`screen`) y ejecuta el siguiente comando de monitoreo continuo:

```bash
# En una segunda terminal: monitoreo continuo de Pods
watch -n 2 "kubectl get pods -n lab03 -o wide"
```

2. En otra terminal (o pestaña), inicia el monitoreo de eventos:

```bash
# Monitoreo de eventos del namespace lab03
kubectl get events -n lab03 --watch
```

> **Nota:** Si no puedes abrir múltiples terminales, puedes ejecutar los comandos de monitoreo después del drain para revisar el estado resultante.

---

#### Paso 4.2 — Ejecutar el Drain (Intento 1 — Fallará por el PDB)

**Objetivo:** Observar el comportamiento del drain cuando un PDB bloquea la operación.

**Instrucciones:**

1. Intenta drenar el nodo `minikube-m02` con las flags estándar:

```bash
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data
```

2. Observa el mensaje de error que aparece. El drain se bloqueará debido al PDB restrictivo de `app-backend`.

**Salida esperada (el drain se bloqueará con un mensaje similar a):**
```
node/minikube-m02 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kindnet-xxxxx, kube-system/kube-proxy-xxxxx
evicting pod lab03/app-web-xxxxx-aaaaa
evicting pod lab03/app-backend-yyyyy-aaaaa
error when evicting pods/"app-backend-yyyyy-aaaaa" -n "lab03" (will retry after 5s): 
Cannot evict pod as it would violate the pod's disruption budget.
```

> **Análisis del error:** El drain intentó evictar el Pod de `app-backend` en `minikube-m02`, pero el PDB `pdb-app-backend-strict` tiene `ALLOWED DISRUPTIONS: 0`, lo que impide cualquier evicción. Kubernetes respeta este contrato de disponibilidad y detiene el drain.

3. Verifica el estado del nodo y los Pods después del intento fallido:

```bash
# El nodo sigue en SchedulingDisabled (el cordon persiste)
kubectl get nodes

# Algunos Pods pueden haber sido ya evictados (los de app-web)
kubectl get pods -n lab03 -o wide
```

> **Observación importante:** El drain es una operación **parcialmente idempotente**. Los Pods que ya fueron evictados exitosamente no vuelven al nodo original. El drain se detuvo en el primer Pod que no pudo ser evictado.

**Verificación:** El comando debe terminar con un error indicando violación del PDB. El nodo `minikube-m02` debe seguir en estado `Ready,SchedulingDisabled`.

---

#### Paso 4.3 — Resolver el PDB Restrictivo y Completar el Drain

**Objetivo:** Aplicar la solución al PDB bloqueante y completar el drain exitosamente.

> **Nota:** Esta sección simula la resolución del problema. En la Parte 5 (Troubleshooting) se analiza el proceso completo de diagnóstico. La solución correcta en producción sería escalar el Deployment antes del drain. Aquí eliminaremos temporalmente el PDB restrictivo para completar el flujo.

**Instrucciones:**

1. Elimina el PDB restrictivo (solución para este laboratorio):

```bash
kubectl delete pdb pdb-app-backend-strict -n lab03
```

2. Verifica que el PDB fue eliminado:

```bash
kubectl get pdb -n lab03
```

3. Ejecuta el drain nuevamente. Esta vez debería completarse (aunque puede tardar hasta 60 segundos):

```bash
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data
```

4. Monitorea los eventos generados durante el drain:

```bash
kubectl get events -n lab03 --sort-by='.lastTimestamp' | tail -20
```

**Salida esperada del drain exitoso:**
```
node/minikube-m02 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kindnet-xxxxx, kube-system/kube-proxy-xxxxx
evicting pod lab03/app-web-xxxxx-aaaaa
evicting pod lab03/app-backend-yyyyy-aaaaa
evicting pod lab03/app-backend-yyyyy-bbbbb
pod/app-web-xxxxx-aaaaa evicted
pod/app-backend-yyyyy-aaaaa evicted
pod/app-backend-yyyyy-bbbbb evicted
node/minikube-m02 drained
```

> **Sobre `--ignore-daemonsets`:** Esta flag es necesaria porque los DaemonSets (como `kube-proxy` y `kindnet`) se ejecutan en todos los nodos por diseño y no pueden ser reprogramados. Sin esta flag, el drain fallaría al encontrar esos Pods.

> **Sobre `--delete-emptydir-data`:** Los Pods que usan volúmenes `emptyDir` perderán sus datos al ser evictados. Esta flag confirma que aceptamos esa pérdida. Sin ella, el drain fallaría si algún Pod usa `emptyDir`.

**Verificación:** El drain debe terminar con el mensaje `node/minikube-m02 drained`. El nodo debe seguir en estado `Ready,SchedulingDisabled` pero sin Pods de usuario.

---

#### Paso 4.4 — Analizar la Reprogramación de Workloads

**Objetivo:** Verificar que todos los Pods fueron migrados exitosamente a `minikube-m03`.

**Instrucciones:**

1. Verifica el estado de los Pods después del drain:

```bash
kubectl get pods -n lab03 -o wide
```

2. Confirma que no quedan Pods de usuario en `minikube-m02`:

```bash
# Debe retornar vacío o solo DaemonSet pods
kubectl get pods -n lab03 -o wide | grep minikube-m02
```

3. Verifica que todos los Pods están en estado `Running` en `minikube-m03`:

```bash
kubectl get pods -n lab03 -o wide | grep -v minikube-m02
```

4. Revisa los eventos de reprogramación:

```bash
kubectl get events -n lab03 --sort-by='.lastTimestamp' | grep -E "Scheduled|Killing|Started"
```

5. Verifica el estado del PDB `pdb-app-web` después de la consolidación:

```bash
kubectl describe pdb pdb-app-web -n lab03
```

**Salida esperada:**
```
# Todos los Pods en minikube-m03
NAME                       READY   STATUS    NODE
app-web-xxxxx-bbbbb        1/1     Running   minikube-m03
app-web-xxxxx-ddddd        1/1     Running   minikube-m03
app-web-xxxxx-eeeee        1/1     Running   minikube-m03
app-web-xxxxx-fffff        1/1     Running   minikube-m03
app-backend-yyyyy-bbbbb    1/1     Running   minikube-m03
app-backend-yyyyy-ccccc    1/1     Running   minikube-m03
app-backend-yyyyy-ddddd    1/1     Running   minikube-m03
```

> **Observación sobre DaemonSets:** Si ejecutas `kubectl get pods -n kube-system -o wide | grep minikube-m02`, verás que los Pods de DaemonSet (`kube-proxy`, `kindnet`) siguen corriendo en `minikube-m02`. Esto es el comportamiento esperado — los DaemonSets no son afectados por el drain cuando se usa `--ignore-daemonsets`.

**Verificación:** No deben existir Pods de los Deployments `app-web` o `app-backend` en `minikube-m02`. El PDB `pdb-app-web` debe mostrar `Current: 4` y `Allowed disruptions: 1`.

---

### Parte 5: Troubleshooting — Diagnóstico y Resolución del Fallo del Drain

**Duración estimada:** 10 minutos

**Objetivo:** Aplicar una metodología sistemática de diagnóstico para identificar y resolver el fallo del drain causado por el PDB restrictivo (reproduciendo el escenario del Paso 4.2).

> **Contexto del escenario:** Imagina que eres un nuevo miembro del equipo de infraestructura. Recibes el reporte: *"El drain del nodo `minikube-m02` está fallando. No sabemos por qué."* Debes diagnosticar el problema desde cero.

---

#### Paso 5.1 — Recrear el Escenario de Fallo

**Instrucciones:**

1. Primero, vuelve a un estado donde el drain pueda fallar. Necesitamos restaurar el PDB restrictivo y asegurarnos de que hay Pods de `app-backend` en el nodo. Dado que ya drenamos el nodo, primero lo restauramos:

```bash
# Hacer uncordon temporalmente para redistribuir Pods
kubectl uncordon minikube-m02

# Esperar redistribución (30 segundos)
sleep 30
kubectl get pods -n lab03 -o wide

# Volver a hacer cordon para el ejercicio
kubectl cordon minikube-m02

# Recrear el PDB restrictivo
kubectl apply -f ~/lab03-pdb-restrictivo.yaml

# Verificar que hay Pods de app-backend en minikube-m02
kubectl get pods -n lab03 -o wide | grep app-backend
```

> **Nota:** Si no hay Pods de `app-backend` en `minikube-m02` después del uncordon/cordon, escala el deployment para forzar redistribución: `kubectl scale deployment app-backend -n lab03 --replicas=6 && sleep 10 && kubectl scale deployment app-backend -n lab03 --replicas=3`

---

#### Paso 5.2 — Metodología de Diagnóstico

**Instrucciones:**

1. **Paso de diagnóstico 1:** Reproduce el error para obtener el mensaje completo:

```bash
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  2>&1 | tee /tmp/drain-error.log
```

2. **Paso de diagnóstico 2:** Analiza el mensaje de error:

```bash
cat /tmp/drain-error.log
# Buscar: "Cannot evict pod as it would violate the pod's disruption budget"
# Identificar: el nombre del Pod y el Deployment afectado
```

3. **Paso de diagnóstico 3:** Identifica todos los PDBs en el namespace:

```bash
kubectl get pdb -n lab03
kubectl describe pdb -n lab03
```

4. **Paso de diagnóstico 4:** Identifica el PDB problemático:

```bash
# Buscar PDBs con ALLOWED DISRUPTIONS = 0
kubectl get pdb -n lab03 -o custom-columns=\
"NAME:.metadata.name,\
MIN-AVAIL:.spec.minAvailable,\
DISRUPTIONS-ALLOWED:.status.disruptionsAllowed,\
CURRENT:.status.currentHealthy,\
DESIRED:.status.desiredHealthy"
```

5. **Paso de diagnóstico 5:** Analiza la causa raíz:

```bash
# Ver cuántos Pods del Deployment están disponibles
kubectl get deployment app-backend -n lab03

# Calcular: minAvailable(3) == replicas(3) => ALLOWED DISRUPTIONS = 0
# Conclusión: El PDB es demasiado restrictivo para el número de réplicas actual
```

**Salida esperada del diagnóstico:**
```
NAME                      MIN-AVAIL   DISRUPTIONS-ALLOWED   CURRENT   DESIRED
pdb-app-web               3           1                     4         3
pdb-app-backend-strict    3           0                     3         3
```

> **Causa raíz identificada:** `pdb-app-backend-strict` tiene `minAvailable: 3` pero el Deployment `app-backend` solo tiene 3 réplicas. Matemáticamente, `3 (total) - 3 (minAvailable) = 0 disrupciones permitidas`. El scheduler no puede evictar ningún Pod sin violar el presupuesto.

---

#### Paso 5.3 — Aplicar la Solución

**Instrucciones:**

**Opción A (Recomendada en producción):** Escalar el Deployment antes del drain para que el PDB permita disrupciones:

```bash
# Escalar a 4 réplicas: 4 - 3 (minAvailable) = 1 disrupción permitida
kubectl scale deployment app-backend -n lab03 --replicas=4

# Esperar que el nuevo Pod esté Running
kubectl wait --for=condition=ready pod -l app=app-backend -n lab03 --timeout=60s

# Verificar que ahora hay disrupciones permitidas
kubectl get pdb pdb-app-backend-strict -n lab03
```

**Opción B (Para este laboratorio):** Eliminar el PDB restrictivo:

```bash
kubectl delete pdb pdb-app-backend-strict -n lab03
```

Aplica la **Opción A** para el ejercicio completo:

```bash
# Después de escalar, ejecutar el drain
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data

# Verificar resultado
kubectl get nodes
kubectl get pods -n lab03 -o wide
```

**Verificación:** El drain debe completarse exitosamente. `kubectl get pdb pdb-app-backend-strict -n lab03` debe mostrar `ALLOWED DISRUPTIONS: 1` después de escalar a 4 réplicas.

---

### Parte 6: Operación uncordon — Reincorporación del Nodo

**Duración estimada:** 8 minutos

**Objetivo:** Ejecutar `kubectl uncordon` para reincorporar el nodo al clúster y observar el comportamiento del scheduler respecto a la redistribución de Pods.

---

#### Paso 6.1 — Ejecutar uncordon

**Instrucciones:**

1. Reincorpora el nodo `minikube-m02` al clúster:

```bash
kubectl uncordon minikube-m02
```

2. Verifica inmediatamente el cambio de estado:

```bash
kubectl get nodes
```

3. Verifica que el taint de `unschedulable` fue eliminado:

```bash
kubectl describe node minikube-m02 | grep -A 3 "Taints:"
```

**Salida esperada:**
```
NAME           STATUS   ROLES           AGE
minikube       Ready    control-plane   Xm
minikube-m02   Ready    <none>          Xm   # Ya no tiene SchedulingDisabled
minikube-m03   Ready    <none>          Xm
```

```
Taints: <none>
```

**Verificación:** El nodo `minikube-m02` debe mostrar `STATUS: Ready` sin el sufijo `,SchedulingDisabled`.

---

#### Paso 6.2 — Observar el Comportamiento del Scheduler Post-uncordon

**Objetivo:** Entender un comportamiento crítico: el scheduler NO redistribuye automáticamente los Pods existentes al reincorporar un nodo.

**Instrucciones:**

1. Observa la distribución de Pods inmediatamente después del uncordon:

```bash
kubectl get pods -n lab03 -o wide
```

2. Espera 60 segundos y vuelve a verificar:

```bash
sleep 60
kubectl get pods -n lab03 -o wide
```

3. Analiza la distribución:

```bash
kubectl get pods -n lab03 -o wide | awk 'NR>1 {print $7}' | sort | uniq -c
```

**Salida esperada:**
```
# Los Pods existentes NO se mueven a minikube-m02 automáticamente
# Todos siguen en minikube-m03
      7 minikube-m03
```

> **Comportamiento crítico del Scheduler:** Kubernetes **no redistribuye** los Pods existentes al reincorporar un nodo. El scheduler solo asigna **nuevos** Pods (por escalado, fallos, etc.) al nodo reincorporado. Para redistribuir, debes forzar la recreación de Pods (por ejemplo, haciendo un rolling restart del Deployment).

4. Fuerza la redistribución mediante un rolling restart:

```bash
kubectl rollout restart deployment app-web -n lab03
kubectl rollout restart deployment app-backend -n lab03

# Esperar que el rollout complete
kubectl rollout status deployment app-web -n lab03
kubectl rollout status deployment app-backend -n lab03
```

5. Verifica la nueva distribución:

```bash
kubectl get pods -n lab03 -o wide
kubectl get pods -n lab03 -o wide | awk 'NR>1 {print $7}' | sort | uniq -c
```

**Verificación:** Después del rolling restart, los Pods deben estar distribuidos entre `minikube-m02` y `minikube-m03`. La distribución exacta depende del scheduler, pero ambos nodos deben tener al menos 1 Pod.

---

#### Paso 6.3 — Verificación Final del Estado del Clúster

**Instrucciones:**

1. Ejecuta una verificación completa del estado del clúster:

```bash
# Estado de los nodos
kubectl get nodes -o wide

# Estado de los Pods
kubectl get pods -n lab03 -o wide

# Estado de los Deployments
kubectl get deployments -n lab03

# Estado de los PDBs
kubectl get pdb -n lab03

# Eventos recientes del namespace
kubectl get events -n lab03 --sort-by='.lastTimestamp' | tail -15
```

2. Verifica los recursos de los nodos (si `metrics-server` está disponible):

```bash
# Habilitar metrics-server si no está activo
minikube addons enable metrics-server

# Esperar 30 segundos para que recopile métricas
sleep 30

# Ver uso de recursos por nodo
kubectl top nodes
```

**Verificación final:** Todos los nodos deben estar en `Ready`, todos los Pods en `Running`, y los Deployments deben mostrar el número correcto de réplicas disponibles.

---

## Validación y Pruebas

### Lista de Verificación Final

Ejecuta los siguientes comandos de validación para confirmar que completaste el laboratorio correctamente:

```bash
echo "=== VALIDACIÓN LAB 03-00-01 ==="

echo ""
echo "1. Estado de los nodos:"
kubectl get nodes

echo ""
echo "2. Todos los nodos deben estar Ready (sin SchedulingDisabled):"
kubectl get nodes | grep -v "SchedulingDisabled" | wc -l
# Esperado: 4 líneas (1 header + 3 nodos)

echo ""
echo "3. Todos los Pods en Running:"
kubectl get pods -n lab03 --no-headers | awk '{print $3}' | sort | uniq -c

echo ""
echo "4. Deployments con réplicas correctas:"
kubectl get deployments -n lab03

echo ""
echo "5. PDB activo:"
kubectl get pdb -n lab03

echo ""
echo "6. Distribución de Pods entre nodos:"
kubectl get pods -n lab03 -o wide --no-headers | awk '{print $7}' | sort | uniq -c

echo ""
echo "=== FIN DE VALIDACIÓN ==="
```

**Criterios de éxito:**

| Criterio | Valor Esperado |
|----------|---------------|
| Nodos en estado `Ready` | 3 (todos sin `SchedulingDisabled`) |
| Pods en estado `Running` | 7 (4 app-web + 3 app-backend) |
| `app-web` réplicas disponibles | 4/4 |
| `app-backend` réplicas disponibles | 3/3 o 4/4 (si escalaste) |
| PDB `pdb-app-web` activo | Sí |

---

## Troubleshooting

### Problema 1: El drain se bloquea indefinidamente sin mostrar error

**Síntomas:**
- El comando `kubectl drain` muestra mensajes de evicción pero nunca termina
- Aparece repetidamente: `evicting pod .../app-xxx (will retry after 5s)`
- Han pasado más de 5 minutos sin que el drain complete

**Causa:**
El drain está esperando que un PDB con `ALLOWED DISRUPTIONS: 0` libere al menos una disrupción. Esto ocurre cuando `minAvailable` es igual al número total de réplicas del Deployment. El drain reintenta indefinidamente por defecto (sin `--timeout`).

**Diagnóstico:**
```bash
# Identificar PDBs bloqueantes
kubectl get pdb -n lab03 -o custom-columns=\
"NAME:.metadata.name,DISRUPTIONS:.status.disruptionsAllowed"

# Ver el estado actual de los Pods del Deployment afectado
kubectl get pods -n lab03 -l app=app-backend -o wide

# Ver si hay Pods en estado no-Ready que reducen el conteo
kubectl get pods -n lab03 --field-selector=status.phase!=Running
```

**Solución:**
```bash
# Opción 1: Escalar el Deployment para liberar disrupciones
kubectl scale deployment app-backend -n lab03 --replicas=4
kubectl wait --for=condition=ready pod -l app=app-backend -n lab03 --timeout=60s
# Luego reintentar el drain

# Opción 2: Si el drain fue lanzado sin --timeout y está bloqueado, cancela con Ctrl+C
# y agrega un timeout explícito para el siguiente intento:
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=300s

# Opción 3 (solo en emergencias/mantenimiento crítico): usar --force
# ADVERTENCIA: --force elimina Pods aunque violen el PDB. Úsalo solo si aceptas
# la posible interrupción del servicio.
kubectl drain minikube-m02 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force
```

---

### Problema 2: Después del uncordon, el nodo aparece como `Ready` pero los Pods no se redistribuyen

**Síntomas:**
- `kubectl get nodes` muestra `minikube-m02` en estado `Ready`
- `kubectl get pods -n lab03 -o wide` muestra que todos los Pods siguen en `minikube-m03`
- Han pasado varios minutos y la situación no cambia

**Causa:**
Este es el **comportamiento esperado y correcto** de Kubernetes. El scheduler no redistribuye automáticamente los Pods existentes cuando un nodo vuelve a estar disponible. Solo asigna nuevos Pods (creados por escalado, fallos, rolling updates, etc.) al nodo reincorporado. No existe un mecanismo nativo de "rebalanceo automático" en Kubernetes estándar.

**Diagnóstico:**
```bash
# Confirmar que el nodo está realmente disponible para scheduling
kubectl describe node minikube-m02 | grep -E "Taints:|Unschedulable:"
# Esperado: Taints: <none> y Unschedulable: false

# Confirmar que los Pods existentes están Running (no hay problema real)
kubectl get pods -n lab03 -o wide

# Verificar que nuevos Pods SÍ se asignarían a minikube-m02
kubectl scale deployment app-web -n lab03 --replicas=8
kubectl get pods -n lab03 -o wide | grep app-web
# Los nuevos Pods deben aparecer en minikube-m02
kubectl scale deployment app-web -n lab03 --replicas=4
```

**Solución:**
```bash
# Para redistribuir los Pods existentes, forzar un rolling restart
kubectl rollout restart deployment app-web -n lab03
kubectl rollout restart deployment app-backend -n lab03

# Monitorear el progreso del rollout
kubectl rollout status deployment app-web -n lab03 --timeout=120s
kubectl rollout status deployment app-backend -n lab03 --timeout=120s

# Verificar la nueva distribución
kubectl get pods -n lab03 -o wide | awk 'NR>1 {print $7}' | sort | uniq -c
```

> **Lección aprendida:** En entornos de producción, el rebalanceo de cargas después de mantenimiento de nodos generalmente se maneja con herramientas especializadas como [Descheduler](https://github.com/kubernetes-sigs/descheduler) o mediante rolling restarts planificados durante ventanas de mantenimiento.

---

## Limpieza del Entorno

```bash
echo "=== LIMPIEZA LAB 03-00-01 ==="

# 1. Eliminar los Deployments del laboratorio
kubectl delete deployment app-web app-backend -n lab03

# 2. Eliminar los PodDisruptionBudgets
kubectl delete pdb --all -n lab03

# 3. Eliminar el namespace del laboratorio
kubectl delete namespace lab03

# 4. Eliminar las etiquetas y anotaciones añadidas a los nodos
kubectl label node minikube-m02 lab03/role-
kubectl label node minikube-m03 lab03/role-
kubectl annotate node minikube-m02 \
  mantenimiento/motivo- \
  mantenimiento/responsable- \
  mantenimiento/fecha-inicio-

# 5. Asegurarse de que todos los nodos están en estado Ready (sin cordon)
kubectl uncordon minikube-m02 2>/dev/null || true
kubectl uncordon minikube-m03 2>/dev/null || true

# 6. Eliminar los archivos de manifiesto locales
rm -f ~/lab03-deployments.yaml ~/lab03-pdb.yaml ~/lab03-pdb-restrictivo.yaml
rm -f /tmp/drain-error.log

# 7. Verificación final del estado del clúster
echo ""
echo "Estado final del clúster:"
kubectl get nodes
echo ""
echo "Namespaces restantes:"
kubectl get namespaces

echo ""
echo "=== LIMPIEZA COMPLETADA ==="
```

> **Nota de persistencia:** El clúster Minikube con 3 nodos debe **mantenerse activo** para laboratorios posteriores. Solo ejecuta `minikube stop` si necesitas liberar recursos del sistema. **No ejecutes `minikube delete`** ya que perderías la configuración multi-nodo.

---

## Resumen

### Conceptos Practicados

En este laboratorio ejecutaste el ciclo completo de mantenimiento de nodos en Kubernetes, aplicando los conceptos de la Lección 3.1 en un escenario realista:

| Operación | Efecto | Cuándo Usarla |
|-----------|--------|---------------|
| `kubectl cordon` | Marca el nodo como `SchedulingDisabled`; los Pods existentes continúan, nuevos Pods no se asignan | Primer paso de cualquier mantenimiento planificado |
| `kubectl drain` | Evicta todos los Pods del nodo (respetando PDBs); implica cordon automáticamente | Cuando necesitas vaciar el nodo para mantenimiento |
| `kubectl uncordon` | Elimina la marca `SchedulingDisabled`; el nodo vuelve a recibir Pods | Al finalizar el mantenimiento y verificar que el nodo está saludable |

### Flags Clave del Drain

| Flag | Propósito | Cuándo es Necesaria |
|------|-----------|---------------------|
| `--ignore-daemonsets` | Omite los Pods de DaemonSets (no pueden ser reprogramados) | Casi siempre requerida |
| `--delete-emptydir-data` | Acepta la pérdida de datos en volúmenes `emptyDir` | Cuando hay Pods con `emptyDir` |
| `--force` | Fuerza la evicción aunque viole PDBs | Solo en emergencias; puede causar indisponibilidad |
| `--timeout` | Establece un tiempo máximo de espera | Para evitar bloqueos indefinidos |

### Lecciones Clave

1. **`cordon` no migra Pods** — solo previene nuevas asignaciones. Los Pods existentes continúan ejecutándose.
2. **`drain` respeta los PDBs** — si un PDB tiene `ALLOWED DISRUPTIONS: 0`, el drain se bloquea. La solución correcta es escalar el Deployment, no eliminar el PDB.
3. **`uncordon` no redistribuye Pods** — el scheduler solo asigna nuevos Pods al nodo reincorporado. Para redistribuir, usa `kubectl rollout restart`.
4. **Los DaemonSets son inmunes al drain** — con `--ignore-daemonsets`, los Pods de DaemonSets permanecen en el nodo durante y después del drain.
5. **Las etiquetas y anotaciones son herramientas de organización** — etiqueta los nodos antes del mantenimiento para facilitar el seguimiento y la comunicación con el equipo.

### Recursos Adicionales

- [Documentación oficial: Drain de nodos de forma segura](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [PodDisruptionBudget — Referencia de la API](https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/pod-disruption-budget-v1/)
- [Conceptos: Disrupciones en Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [kubectl drain — Referencia de comandos](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/)
- [Descheduler para rebalanceo automático](https://github.com/kubernetes-sigs/descheduler)

---
*Lab 03-00-01 — Mantenimiento de nodos y reprogramación de workloads en Kubernetes*
