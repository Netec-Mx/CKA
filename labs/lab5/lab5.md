---
course_id: kubeadmin
lab_id: l005
tracking: true
position: 5
layout: lab
title: "Práctica 3: Mantenimiento de nodos y reprogramación de workloads en Kubernetes"
permalink: /lab5/lab5/
images_base: /labs/lab5/img
duration: "60 minutos"
objective:
  - Preparar y validar un clúster Minikube de tres nodos para realizar operaciones de mantenimiento.
  - Ejecutar el flujo cordon, drain y uncordon sobre un worker node y observar el efecto sobre los workloads.
  - Verificar la reprogramación automática de Pods administrados por Deployments después del drenado de un nodo.
  - Crear y analizar un PodDisruptionBudget para proteger la disponibilidad de una aplicación durante una disrupción voluntaria.
  - Diagnosticar un drain bloqueado por un PodDisruptionBudget y restaurar correctamente el nodo al servicio.
prerequisites:
  - Haber completado la Práctica 2 y la Práctica complementaria 2.1.
  - Tener Docker Desktop instalado y en ejecución.
  - Tener Minikube y kubectl instalados y disponibles desde Git Bash.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Comprender Deployments, ReplicaSets, Pods, labels y selectors.
  - Disponer de recursos suficientes para ejecutar un clúster Minikube de tres nodos.
introduction:
  - En esta práctica simularás una ventana de mantenimiento de infraestructura en Kubernetes. Prepararás un clúster Minikube con un control plane y dos workers, desplegarás workloads de prueba y ejecutarás el ciclo cordon → drain → uncordon sobre uno de los nodos. Observarás cómo Kubernetes reprograma Pods administrados por Deployments y utilizarás un PodDisruptionBudget para comprobar cómo se protege la disponibilidad durante una disrupción voluntaria. Finalmente resolverás un escenario donde el drain queda bloqueado por una política demasiado restrictiva.
slug: lab5
lab_number: 5
final_result: >
  Al finalizar la práctica tendrás un clúster Minikube de tres nodos operativo, habrás realizado el mantenimiento controlado de un worker mediante cordon, drain y uncordon, observado la reprogramación automática de workloads y diagnosticado un bloqueo de drain provocado por un PodDisruptionBudget.
notes:
  - Esta práctica requiere tres nodos Minikube porque el objetivo principal es observar la reprogramación de Pods entre workers durante una operación real de mantenimiento.
  - El clúster creado en esta práctica debe conservarse para laboratorios posteriores relacionados con nodos, scheduling y troubleshooting.
  - El PodDisruptionBudget se utilizará únicamente para demostrar el comportamiento de las disrupciones voluntarias; no reemplaza una estrategia completa de alta disponibilidad.
  - No uses kubectl drain con --force durante las actividades guiadas, porque el objetivo es respetar y analizar las protecciones definidas por Kubernetes.
references:
  - text: Safely Drain a Node
    url: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
  - text: Disruptions
    url: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
  - text: PodDisruptionBudget
    url: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
  - text: kubectl drain
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/
prev: /lab4/lab4/
next: /lab6/lab6/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio y del clúster

En esta práctica crearás el directorio `lab3` y prepararás un clúster Minikube con tres nodos. La topología multinodo es necesaria para observar cómo Kubernetes reprograma workloads cuando un worker queda fuera de servicio.

### 🗂️ Crear el subdirectorio de la práctica


{% assign tracking_task_id = "t001" %}

- {% include step_label.html id="s001" %} Abre **Docker Desktop** y confirma que el motor está activo, porque Minikube utilizará Docker para ejecutar los tres nodos del clúster.

- {% include step_label.html id="s002" %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el subdirectorio destinado a esta práctica.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab3
  ```

- {% include step_label.html id="s003" %} Cambia la ubicación activa de Git Bash al nuevo directorio para mantener separados los manifiestos y evidencias del laboratorio.

  ```bash
  cd /c/LABS/kubernetes/lab3
  ```

- {% include step_label.html id="s004" %} Ejecuta `pwd` y confirma que la ruta activa corresponde exactamente al directorio de la práctica antes de continuar.

  ```bash
  pwd
  ```

  **Salida esperada:**

  ```text
  /c/LABS/kubernetes/lab3
  ```

### 🧱 Preparar el clúster de tres nodos

- {% include step_label.html id="s005" %} Ejecuta el comando siguiente para conocer la topología actual del clúster y determinar si ya dispones de tres nodos activos.

  ```bash
  kubectl get nodes
  ```

- {% include step_label.html id="s006" %} Si el clúster actual tiene un solo nodo, elimina únicamente el perfil Minikube local para recrearlo con la topología requerida por este laboratorio.

  ```bash
  minikube delete
  ```

  > **IMPORTANTE:** Este paso elimina los recursos de las prácticas anteriores almacenados dentro de Minikube. Los archivos YAML permanecen en `C:\LABS\kubernetes` y podrán reutilizarse si fueran necesarios.
  {: .lab-note .important .compact}

- {% include step_label.html id="s007" %} Ejecuta el comando siguiente para crear un clúster Minikube con un control plane y dos nodos adicionales utilizando Docker como driver.

  ```bash
  minikube start \
    --nodes=3 \
    --driver=docker \
    --cpus=2 \
    --memory=2048
  ```

- {% include step_label.html id="s008" %} Comprueba que los tres nodos aparecen en estado `Ready` antes de desplegar workloads para el ejercicio de mantenimiento.

  ```bash
  kubectl get nodes -o wide
  ```

  **Salida esperada aproximada:**

  ```text
  NAME           STATUS   ROLES           AGE   VERSION
  minikube       Ready    control-plane   ...   ...
  minikube-m02   Ready    <none>          ...   ...
  minikube-m03   Ready    <none>          ...   ...
  ```

  > **IMPORTANTE:** No continúes si alguno de los nodos aparece como `NotReady`. El comportamiento de cordon, drain y reprogramación requiere que los tres nodos estén disponibles al inicio.
  {: .lab-note .important .compact}

---

## 🧭 Tarea 1. Preparar workloads y establecer una línea base

En esta tarea desplegarás dos aplicaciones de prueba dentro de un namespace dedicado. Después observarás en qué nodos fueron programados los Pods para comparar su distribución antes y después del mantenimiento.

### Tarea 1.1. Crear el namespace y los manifiestos


{% assign tracking_task_id = "t002" %}

- {% include step_label.html id="s009" %} Ejecuta el comando siguiente para crear el namespace `lab3`, aislando los workloads de esta práctica respecto de los recursos del sistema.

  ```bash
  kubectl create namespace lab3
  ```

- {% include step_label.html id="s010" %} Crea el archivo donde almacenarás los dos Deployments utilizados durante las operaciones de mantenimiento.

  ```bash
  touch deployments.yaml
  ```

- {% include step_label.html id="s011" %} Abre `deployments.yaml` en VS Code y agrega los dos Deployments siguientes con suficientes réplicas para observar la reprogramación entre workers.

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: app-web
    namespace: lab3
    labels:
      app: app-web
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
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
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
    namespace: lab3
    labels:
      app: app-backend
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
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
            resources:
              requests:
                cpu: "50m"
                memory: "64Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
  ```

### Tarea 1.2. Desplegar y observar la distribución

- {% include step_label.html id="s012" %} Valida el archivo antes de aplicarlo para confirmar que ambos Deployments tienen una estructura aceptada por kubectl.

  ```bash
  kubectl apply --dry-run=client -f deployments.yaml
  ```

- {% include step_label.html id="s013" %} Aplica los manifiestos para crear los dos workloads dentro del namespace utilizado por esta práctica.

  ```bash
  kubectl apply -f deployments.yaml
  ```

- {% include step_label.html id="s014" %} Espera a que los Deployments indiquen que todas sus réplicas se encuentran disponibles antes de registrar la distribución inicial.

  ```bash
  kubectl rollout status deployment/app-web -n lab3
  kubectl rollout status deployment/app-backend -n lab3
  ```

- {% include step_label.html id="s015" %} Ejecuta la consulta siguiente para identificar exactamente en qué nodo está ejecutándose cada Pod.

  ```bash
  kubectl get pods -n lab3 -o wide
  ```

  **Resultado esperado:**

  Debes observar siete Pods en estado `Running`, distribuidos entre los nodos disponibles del clúster.

  > **NOTA:** El scheduler no garantiza una distribución perfectamente equilibrada. Lo importante es registrar qué Pods se encuentran en `minikube-m02`, porque ese será el nodo sometido a mantenimiento.
  {: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🚧 Tarea 2. Ejecutar cordon y comprobar el efecto sobre scheduling

En esta tarea marcarás `minikube-m02` como no programable. Los Pods existentes continuarán ejecutándose, pero el scheduler dejará de colocar nuevos Pods sobre ese nodo.

### Tarea 2.1. Marcar el nodo como SchedulingDisabled


{% assign tracking_task_id = "t003" %}

- {% include step_label.html id="s016" %} Ejecuta `kubectl cordon` sobre `minikube-m02` para impedir que el scheduler asigne nuevos Pods durante la ventana de mantenimiento.

  ```bash
  kubectl cordon minikube-m02
  ```

- {% include step_label.html id="s017" %} Comprueba inmediatamente el estado de los nodos y localiza la indicación `SchedulingDisabled` junto al worker seleccionado.

  ```bash
  kubectl get nodes
  ```

  **Salida esperada aproximada:**

  ```text
  NAME           STATUS                     ROLES           AGE
  minikube       Ready                      control-plane   ...
  minikube-m02   Ready,SchedulingDisabled   <none>          ...
  minikube-m03   Ready                      <none>          ...
  ```

- {% include step_label.html id="s018" %} Ejecuta el comando siguiente para comprobar que los Pods que ya estaban en `minikube-m02` continúan ejecutándose después del cordon.

  ```bash
  kubectl get pods -n lab3 -o wide | grep minikube-m02
  ```

### Tarea 2.2. Confirmar que los nuevos Pods evitan el nodo

- {% include step_label.html id="s019" %} Escala temporalmente `app-web` de cuatro a seis réplicas para forzar al scheduler a crear dos Pods nuevos mientras `minikube-m02` está cordoned.

  ```bash
  kubectl scale deployment app-web \
    -n lab3 \
    --replicas=6
  ```

- {% include step_label.html id="s020" %} Observa la ubicación de los seis Pods y verifica que las nuevas instancias no hayan sido programadas en `minikube-m02`.

  ```bash
  kubectl get pods -n lab3 -l app=app-web -o wide
  ```

- {% include step_label.html id="s021" %} Regresa `app-web` a cuatro réplicas para continuar con el escenario de mantenimiento definido para el resto del laboratorio.

  ```bash
  kubectl scale deployment app-web \
    -n lab3 \
    --replicas=4
  ```

  > **Concepto clave:** `cordon` no expulsa ni reinicia Pods existentes. Únicamente evita nuevas asignaciones sobre el nodo hasta que vuelva a ser habilitado.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🛡️ Tarea 3. Crear un PodDisruptionBudget y preparar el escenario de bloqueo

En esta tarea crearás dos PodDisruptionBudgets. Uno permitirá una disrupción controlada y el segundo bloqueará cualquier evicción para generar un escenario real de troubleshooting.

### Tarea 3.1. Crear el PDB de app-web


{% assign tracking_task_id = "t004" %}

- {% include step_label.html id="s022" %} Crea el archivo `pdb.yaml`, donde definirás las políticas de disponibilidad utilizadas durante el drain.

  ```bash
  touch pdb.yaml
  ```

- {% include step_label.html id="s023" %} Abre `pdb.yaml` en VS Code y agrega un presupuesto para `app-web` que conserve al menos tres de sus cuatro réplicas disponibles.

  ```yaml
  apiVersion: policy/v1
  kind: PodDisruptionBudget
  metadata:
    name: pdb-app-web
    namespace: lab3
  spec:
    minAvailable: 3
    selector:
      matchLabels:
        app: app-web
  ```

- {% include step_label.html id="s024" %} Aplica el manifiesto y consulta el presupuesto para comprobar cuántas disrupciones voluntarias están permitidas actualmente.

  ```bash
  kubectl apply -f pdb.yaml
  kubectl get pdb -n lab3
  ```

  **Salida esperada aproximada:**

  ```text
  NAME          MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS
  pdb-app-web   3               N/A               1
  ```

### Tarea 3.2. Crear un PDB restrictivo para app-backend

- {% include step_label.html id="s025" %} Agrega al final de `pdb.yaml` el recurso siguiente, que exige mantener disponibles las tres réplicas actuales de `app-backend`.

  ```yaml
  ---
  apiVersion: policy/v1
  kind: PodDisruptionBudget
  metadata:
    name: pdb-app-backend-strict
    namespace: lab3
  spec:
    minAvailable: 3
    selector:
      matchLabels:
        app: app-backend
  ```

- {% include step_label.html id="s026" %} Aplica nuevamente el archivo y confirma que el segundo PDB no permite ninguna disrupción mientras el Deployment tenga solamente tres réplicas.

  ```bash
  kubectl apply -f pdb.yaml
  kubectl get pdb -n lab3
  ```

  **Salida esperada aproximada:**

  ```text
  NAME                     MIN AVAILABLE   ALLOWED DISRUPTIONS
  pdb-app-web              3               1
  pdb-app-backend-strict   3               0
  ```

  > **IMPORTANTE:** `ALLOWED DISRUPTIONS: 0` significa que una evicción voluntaria de cualquier Pod protegido por ese PDB será rechazada mientras no aumente la disponibilidad.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔄 Tarea 4. Ejecutar drain, diagnosticar el bloqueo y reprogramar workloads

En esta tarea intentarás vaciar `minikube-m02`. El primer intento quedará bloqueado por el PDB restrictivo de `app-backend`; después corregirás la condición y completarás el mantenimiento.

### Tarea 4.1. Intentar el drain y analizar el error


{% assign tracking_task_id = "t005" %}

- {% include step_label.html id="s027" %} Ejecuta el drain con un timeout controlado para evitar que el comando permanezca reintentando indefinidamente cuando encuentre el PDB restrictivo.

  ```bash
  kubectl drain minikube-m02 \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=60s
  ```

  **Salida esperada aproximada:**

  ```text
  error when evicting pods/...:
  Cannot evict pod as it would violate the pod's disruption budget.
  ```

- {% include step_label.html id="s028" %} Ejecuta la consulta siguiente para identificar qué PDB tiene cero disrupciones permitidas y relacionarlo con el workload que bloqueó el drain.

  ```bash
  kubectl get pdb -n lab3
  ```

- {% include step_label.html id="s029" %} Comprueba la cantidad de réplicas disponibles de `app-backend` para relacionar el valor `minAvailable: 3` con sus tres Pods actuales.

  ```bash
  kubectl get deployment app-backend -n lab3
  ```

### Tarea 4.2. Resolver correctamente la restricción

- {% include step_label.html id="s030" %} Escala `app-backend` a cuatro réplicas para disponer de una instancia adicional y permitir que el PDB autorice una disrupción durante el mantenimiento.

  ```bash
  kubectl scale deployment app-backend \
    -n lab3 \
    --replicas=4
  ```

- {% include step_label.html id="s031" %} Espera hasta que el Deployment confirme las cuatro réplicas disponibles antes de volver a intentar el drenado.

  ```bash
  kubectl rollout status deployment/app-backend -n lab3
  ```

- {% include step_label.html id="s032" %} Comprueba nuevamente el PDB y confirma que ahora existe al menos una disrupción permitida.

  ```bash
  kubectl get pdb -n lab3
  ```

### Tarea 4.3. Completar el drain

- {% include step_label.html id="s033" %} Ejecuta nuevamente el comando de drain para evacuar los Pods administrados que todavía permanecen en `minikube-m02`.

  ```bash
  kubectl drain minikube-m02 \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=120s
  ```

  **Salida esperada final:**

  ```text
  node/minikube-m02 drained
  ```

- {% include step_label.html id="s034" %} Ejecuta la consulta siguiente para comprobar que los Pods del namespace `lab3` fueron reprogramados en nodos disponibles y ya no permanecen en el worker drenado.

  ```bash
  kubectl get pods -n lab3 -o wide
  ```

- {% include step_label.html id="s035" %} Ejecuta el filtro siguiente para confirmar que ningún Pod de usuario del laboratorio continúa ejecutándose en `minikube-m02`.

  ```bash
  kubectl get pods -n lab3 -o wide | grep minikube-m02
  ```

  **Resultado esperado:**

  La última consulta no debe devolver Pods del namespace `lab3`.

  > **NOTA:** Los Pods administrados por DaemonSets del sistema pueden continuar visibles en `minikube-m02`. El parámetro `--ignore-daemonsets` indica precisamente que no deben impedir el drenado.
  {: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Reincorporar el nodo y validar el estado final

En esta tarea ejecutarás `uncordon` para habilitar nuevamente el worker y comprobarás un comportamiento importante: Kubernetes no redistribuye automáticamente los Pods existentes cuando un nodo vuelve a estar disponible.

### Tarea 5.1. Ejecutar uncordon


{% assign tracking_task_id = "t006" %}

- {% include step_label.html id="s036" %} Ejecuta el comando siguiente para reincorporar `minikube-m02` al conjunto de nodos disponibles para nuevas asignaciones.

  ```bash
  kubectl uncordon minikube-m02
  ```

- {% include step_label.html id="s037" %} Comprueba que el nodo volvió al estado `Ready` y que ya no aparece la indicación `SchedulingDisabled`.

  ```bash
  kubectl get nodes
  ```

  **Salida esperada aproximada:**

  ```text
  NAME           STATUS   ROLES           AGE
  minikube       Ready    control-plane   ...
  minikube-m02   Ready    <none>          ...
  minikube-m03   Ready    <none>          ...
  ```

### Tarea 5.2. Observar el comportamiento después del uncordon

- {% include step_label.html id="s038" %} Ejecuta la consulta siguiente inmediatamente después del uncordon y observa que los Pods existentes permanecen donde fueron reprogramados durante el drain.

  ```bash
  kubectl get pods -n lab3 -o wide
  ```

  > **Concepto clave:** `uncordon` permite que el nodo vuelva a recibir Pods nuevos, pero no provoca un rebalanceo automático de los Pods que ya están ejecutándose correctamente en otros nodos.
  {: .lab-note .important .compact}

- {% include step_label.html id="s039" %} Ejecuta un rolling restart sobre ambos Deployments para provocar la recreación progresiva de Pods y permitir que el scheduler vuelva a considerar todos los nodos disponibles.

  ```bash
  kubectl rollout restart deployment/app-web -n lab3
  kubectl rollout restart deployment/app-backend -n lab3
  ```

- {% include step_label.html id="s040" %} Espera hasta que ambos rollouts terminen correctamente antes de revisar nuevamente la distribución de los Pods.

  ```bash
  kubectl rollout status deployment/app-web -n lab3
  kubectl rollout status deployment/app-backend -n lab3
  ```

- {% include step_label.html id="s041" %} Ejecuta la consulta siguiente para observar la nueva ubicación de los Pods después de su recreación.

  ```bash
  kubectl get pods -n lab3 -o wide
  ```

### Tarea 5.3. Ejecutar la verificación final

- {% include step_label.html id="s045" %} Ejecuta el siguiente script para validar la configuracion.

  ```bash
  curl -sSL https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab5/scripts/validacion.sh -o validacion.sh
  chmod +x validacion.sh
  ./validacion.sh
  ```

  **Salida esperada aproximada:**

  ```text
  === Verificacion final de la Practica 3 ===
  ✅ Todos los nodos estan disponibles
  ✅ Todos los nodos aceptan scheduling
  ✅ app-web disponible: 4/4
  ✅ app-backend disponible: 4/4
  ...
  === Fin de verificacion ===
  ```

  > **IMPORTANTE:** Conserva el clúster Minikube de tres nodos. Esta topología será útil para las siguientes prácticas relacionadas con namespaces, scheduling y troubleshooting.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}