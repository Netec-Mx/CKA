---
layout: lab
title: "Práctica 4: Gestión de namespaces y despliegue de recursos"
permalink: /lab6/lab6/
images_base: /labs/lab6/img
duration: "50 minutos"
objective:
  - Explorar los namespaces predeterminados de Kubernetes e identificar su propósito dentro del clúster.
  - Crear namespaces para representar ambientes de development, staging y production mediante métodos imperativos y declarativos.
  - Desplegar recursos con el mismo nombre en diferentes namespaces y comprobar su aislamiento lógico.
  - Configurar una ResourceQuota y un LimitRange para controlar el consumo de recursos en un namespace.
  - Eliminar un namespace y verificar la eliminación en cascada de los recursos contenidos.
prerequisites:
  - Haber completado la Práctica 3 y conservar el clúster Minikube de tres nodos operativo.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Comprender Deployments, Pods, Services y manifiestos YAML.
  - Tener permisos administrativos sobre el clúster utilizado para las prácticas.
introduction:
  - En esta práctica utilizarás namespaces para organizar recursos Kubernetes en tres ambientes simulados: development, staging y production. Desplegarás una aplicación con el mismo nombre en cada ambiente para comprobar el aislamiento lógico, aplicarás ResourceQuota y LimitRange en development y finalizarás eliminando staging para observar la eliminación en cascada de sus recursos. La práctica se concentra en administración de namespaces; la separación lógica avanzada entre equipos se trabajará posteriormente en una práctica complementaria.
slug: lab6
lab_number: 6
final_result: >
  Al finalizar la práctica habrás creado y administrado namespaces para tres ambientes, desplegado recursos con nombres repetidos sin conflicto, configurado límites de consumo mediante ResourceQuota y LimitRange y comprobado que la eliminación de un namespace elimina también los recursos contenidos.
notes:
  - Esta práctica reutiliza el clúster Minikube de tres nodos creado en el Lab 5.
  - Los namespaces development y production se conservarán al finalizar para servir como referencia en actividades posteriores.
  - La comunicación DNS entre namespaces y la separación por equipos se profundizarán en la práctica complementaria 4.1.
  - No elimines los namespaces del sistema default, kube-system, kube-public ni kube-node-lease.
references:
  - text: Namespaces
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
  - text: Resource Quotas
    url: https://kubernetes.io/docs/concepts/policy/resource-quotas/
  - text: Limit Ranges
    url: https://kubernetes.io/docs/concepts/policy/limit-range/
  - text: kubectl Cheat Sheet
    url: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
prev: /lab5/lab5/
next: /lab7/lab7/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio de trabajo

En esta práctica crearás el directorio `lab6` y comprobarás que el clúster Minikube conserva los tres nodos utilizados durante el laboratorio anterior.

### 🗂️ Crear el subdirectorio de la práctica

- {% include step_label.html %} Abre **Docker Desktop** y confirma que el motor se encuentra activo antes de interactuar con el clúster Minikube.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio correspondiente al Lab 6.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab6
  ```

- {% include step_label.html %} Cambia la ubicación activa de Git Bash al directorio de trabajo para almacenar los manifiestos de namespaces y aplicaciones.

  ```bash
  cd /c/LABS/kubernetes/lab6
  ```

- {% include step_label.html %} Confirma que la terminal se encuentra en la ruta correcta antes de crear los archivos de esta práctica.

  ```bash
  pwd
  ```

**Salida esperada:**

```text
/c/LABS/kubernetes/lab6
```

- {% include step_label.html %} Ejecuta los comandos siguientes para confirmar que Minikube está activo y que los nodos continúan disponibles.

  ```bash
  minikube status
  kubectl get nodes
  ```

**Resultado esperado:**

Los tres nodos del clúster deben aparecer en estado `Ready`.

---

## 🔎 Tarea 1. Explorar namespaces del sistema

En esta tarea identificarás los namespaces creados automáticamente por Kubernetes y revisarás algunos recursos internos antes de crear namespaces propios.

### Tarea 1.1. Listar namespaces existentes

- {% include step_label.html %} Ejecuta el comando siguiente para obtener la lista completa de namespaces disponibles en el clúster.

  ```bash
  kubectl get namespaces
  ```

**Salida esperada aproximada:**

```text
NAME              STATUS   AGE
default           Active   ...
kube-node-lease   Active   ...
kube-public       Active   ...
kube-system       Active   ...
```

- {% include step_label.html %} Ejecuta `kubectl describe` para revisar los metadatos y estado del namespace utilizado por los componentes internos de Kubernetes.

  ```bash
  kubectl describe namespace kube-system
  ```

- {% include step_label.html %} Lista los Pods de `kube-system` para comprobar que los componentes del clúster se encuentran aislados de los workloads de usuario.

  ```bash
  kubectl get pods -n kube-system
  ```

- {% include step_label.html %} Consulta los objetos Lease del namespace `kube-node-lease` para observar los recursos utilizados para mantener información de heartbeat de los nodos.

  ```bash
  kubectl get leases -n kube-node-lease
  ```

> **IMPORTANTE:** Los namespaces `kube-system`, `kube-public` y `kube-node-lease` forman parte de la infraestructura del clúster. No deben utilizarse para desplegar aplicaciones de usuario ni eliminarse durante las prácticas.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🗂️ Tarea 2. Crear namespaces para tres ambientes

En esta tarea crearás `development`, `staging` y `production`, utilizando tanto comandos imperativos como manifiestos declarativos.

### Tarea 2.1. Crear development de forma imperativa

- {% include step_label.html %} Ejecuta el comando siguiente para crear directamente el namespace `development` mediante kubectl.

  ```bash
  kubectl create namespace development
  ```

- {% include step_label.html %} Agrega labels descriptivos al namespace para identificar el ambiente y el equipo responsable.

  ```bash
  kubectl label namespace development \
    environment=development \
    team=backend
  ```

### Tarea 2.2. Crear staging y production mediante YAML

- {% include step_label.html %} Crea el archivo `namespaces.yaml`, donde almacenarás la definición declarativa de los otros dos ambientes.

  ```bash
  touch namespaces.yaml
  ```

- {% include step_label.html %} Abre `namespaces.yaml` en VS Code y agrega los manifiestos siguientes para crear `staging` y `production`.

  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: staging
    labels:
      environment: staging
      team: platform
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: production
    labels:
      environment: production
      team: platform
    annotations:
      description: "Namespace para el ambiente de produccion"
  ```

- {% include step_label.html %} Valida el archivo antes de aplicarlo para comprobar que ambos recursos tienen una estructura YAML válida.

  ```bash
  kubectl apply --dry-run=client -f namespaces.yaml
  ```

- {% include step_label.html %} Aplica el manifiesto para crear los dos namespaces declarativos en el clúster.

  ```bash
  kubectl apply -f namespaces.yaml
  ```

### Tarea 2.3. Verificar los tres ambientes

- {% include step_label.html %} Ejecuta la consulta siguiente para confirmar que los tres namespaces están activos y disponibles.

  ```bash
  kubectl get namespaces development staging production
  ```

**Salida esperada:**

```text
NAME          STATUS   AGE
development   Active   ...
staging       Active   ...
production    Active   ...
```

- {% include step_label.html %} Consulta los labels de los namespaces para comprobar que las etiquetas añadidas permiten clasificarlos por ambiente o equipo.

  ```bash
  kubectl get namespaces --show-labels
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. Desplegar la misma aplicación en diferentes namespaces

En esta tarea desplegarás recursos llamados `webapp` y `webapp-svc` en los tres ambientes. Kubernetes permitirá utilizar los mismos nombres porque cada recurso pertenece a un namespace diferente.

### Tarea 3.1. Crear los manifiestos de aplicación

- {% include step_label.html %} Crea tres archivos independientes para conservar la definición correspondiente a cada ambiente.

  ```bash
  touch deploy-development.yaml
  touch deploy-staging.yaml
  touch deploy-production.yaml
  ```

- {% include step_label.html %} Abre `deploy-development.yaml` y agrega una réplica de NGINX junto con un Service interno para el ambiente de desarrollo.

  ```yaml
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
            image: nginx:1.27-alpine
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
  ```

- {% include step_label.html %} Abre `deploy-staging.yaml` y agrega la misma aplicación con dos réplicas para representar un ambiente intermedio.

  ```yaml
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
            image: nginx:1.27-alpine
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
  ```

- {% include step_label.html %} Abre `deploy-production.yaml` y agrega tres réplicas para representar el ambiente de producción con mayor disponibilidad.

  ```yaml
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
          environment: production
      spec:
        containers:
          - name: nginx
            image: nginx:1.27-alpine
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
  ```

### Tarea 3.2. Aplicar los manifiestos

- {% include step_label.html %} Valida los tres archivos antes de crear los recursos para detectar errores de sintaxis o estructura.

  ```bash
  kubectl apply --dry-run=client -f deploy-development.yaml
  kubectl apply --dry-run=client -f deploy-staging.yaml
  kubectl apply --dry-run=client -f deploy-production.yaml
  ```

- {% include step_label.html %} Aplica los tres manifiestos para crear Deployments y Services independientes en cada namespace.

  ```bash
  kubectl apply -f deploy-development.yaml
  kubectl apply -f deploy-staging.yaml
  kubectl apply -f deploy-production.yaml
  ```

- {% include step_label.html %} Espera a que los tres Deployments queden disponibles antes de comprobar el aislamiento entre ambientes.

  ```bash
  kubectl rollout status deployment/webapp -n development
  kubectl rollout status deployment/webapp -n staging
  kubectl rollout status deployment/webapp -n production
  ```

### Tarea 3.3. Comprobar el aislamiento lógico

- {% include step_label.html %} Ejecuta las consultas siguientes para observar que el Deployment `webapp` existe simultáneamente en los tres namespaces sin conflicto de nombres.

  ```bash
  kubectl get deployment webapp -n development
  kubectl get deployment webapp -n staging
  kubectl get deployment webapp -n production
  ```

- {% include step_label.html %} Utiliza `--all-namespaces` para obtener una vista global y comparar los mismos recursos dentro de ambientes diferentes.

  ```bash
  kubectl get deployments --all-namespaces | grep webapp
  kubectl get services --all-namespaces | grep webapp-svc
  ```

**Salida esperada aproximada:**

```text
development   webapp   1/1   ...
production    webapp   3/3   ...
staging       webapp   2/2   ...
```

> **Concepto clave:** Los namespaces proporcionan aislamiento lógico de nombres. Un Deployment llamado `webapp` puede existir en varios namespaces porque cada combinación `namespace + nombre` identifica un recurso diferente.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 📊 Tarea 4. Controlar recursos con ResourceQuota y LimitRange

En esta tarea aplicarás controles de consumo al namespace `development`. ResourceQuota limitará los recursos totales del namespace y LimitRange definirá valores predeterminados para contenedores que no especifiquen requests y limits.

### Tarea 4.1. Crear una ResourceQuota

- {% include step_label.html %} Crea el archivo `resource-controls.yaml`, donde almacenarás los controles de recursos del ambiente de desarrollo.

  ```bash
  touch resource-controls.yaml
  ```

- {% include step_label.html %} Abre `resource-controls.yaml` y agrega una ResourceQuota que limite Pods, Services, CPU y memoria disponibles para el namespace.

  ```yaml
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
  ```

- {% include step_label.html %} Aplica el manifiesto y revisa el consumo actual del namespace después de considerar el Deployment y Service ya existentes.

  ```bash
  kubectl apply -f resource-controls.yaml
  kubectl describe resourcequota development-quota -n development
  ```

### Tarea 4.2. Crear un LimitRange

- {% include step_label.html %} Agrega al mismo archivo el recurso siguiente para establecer requests y limits predeterminados para los contenedores creados en `development`.

  ```yaml
  ---
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
  ```

- {% include step_label.html %} Aplica nuevamente el archivo para crear el LimitRange junto con la ResourceQuota ya existente.

  ```bash
  kubectl apply -f resource-controls.yaml
  ```

- {% include step_label.html %} Ejecuta el comando siguiente para revisar los valores mínimos, máximos y predeterminados configurados para los contenedores.

  ```bash
  kubectl describe limitrange development-limits -n development
  ```

### Tarea 4.3. Validar la asignación automática de recursos

- {% include step_label.html %} Crea un Pod de prueba sin especificar `resources` para comprobar que el LimitRange inyecta automáticamente los valores definidos.

  ```bash
  kubectl run test-limitrange \
    --image=nginx:1.27-alpine \
    --restart=Never \
    -n development
  ```

- {% include step_label.html %} Consulta el Pod en YAML y revisa la sección `resources` añadida automáticamente durante su admisión.

  ```bash
  kubectl get pod test-limitrange \
    -n development \
    -o yaml
  ```

**Resultado esperado dentro de `resources`:**

```yaml
limits:
  cpu: 200m
  memory: 128Mi
requests:
  cpu: 100m
  memory: 64Mi
```

- {% include step_label.html %} Ejecuta las consultas siguientes para confirmar que ResourceQuota y LimitRange están activos en el namespace.

  ```bash
  kubectl get resourcequota -n development
  kubectl get limitrange -n development
  ```

> **NOTA:** ResourceQuota controla el consumo total del namespace, mientras LimitRange aplica reglas y valores predeterminados a objetos individuales. Son mecanismos complementarios.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🗑️ Tarea 5. Eliminar un namespace y validar la cascada

En esta tarea eliminarás `staging` y comprobarás que Kubernetes elimina automáticamente los recursos contenidos dentro del namespace sin afectar a los otros ambientes.

### Tarea 5.1. Registrar los recursos antes de eliminar

- {% include step_label.html %} Ejecuta el comando siguiente para listar todos los recursos principales de `staging` antes de eliminar el namespace.

  ```bash
  kubectl get all -n staging
  ```

- {% include step_label.html %} Comprueba que `development` y `production` continúan operativos para utilizarlos posteriormente como referencia de comparación.

  ```bash
  kubectl get deployment webapp -n development
  kubectl get deployment webapp -n production
  ```

### Tarea 5.2. Eliminar staging

- {% include step_label.html %} Ejecuta el comando siguiente para eliminar el namespace y permitir que Kubernetes procese la eliminación en cascada de los recursos namespaced contenidos.

  ```bash
  kubectl delete namespace staging
  ```

- {% include step_label.html %} Comprueba que `staging` dejó de aparecer en la lista de namespaces activos.

  ```bash
  kubectl get namespaces
  ```

- {% include step_label.html %} Intenta consultar nuevamente el Deployment que pertenecía a `staging` para confirmar que el namespace y sus recursos ya no existen.

  ```bash
  kubectl get deployment webapp -n staging
  ```

**Salida esperada:**

```text
Error from server (NotFound): namespaces "staging" not found
```

- {% include step_label.html %} Confirma que los recursos con el mismo nombre en `development` y `production` permanecen disponibles y no fueron afectados por la eliminación.

  ```bash
  kubectl get deployment webapp -n development
  kubectl get deployment webapp -n production
  ```

### Tarea 5.3. Ejecutar la verificación final

- {% include step_label.html %} Copia y ejecuta el bloque siguiente para validar automáticamente los principales resultados de la práctica.

  ```bash
  echo "=== Verificacion final de la Practica 4 ==="

  for ns in development production; do
    STATUS=$(kubectl get namespace "$ns" \
      -o jsonpath='{.status.phase}' 2>/dev/null)

    if [ "$STATUS" = "Active" ]; then
      echo "✅ Namespace $ns disponible"
    else
      echo "❌ Namespace $ns no disponible"
    fi
  done

  if kubectl get namespace staging >/dev/null 2>&1; then
    echo "❌ staging todavia existe"
  else
    echo "✅ staging fue eliminado"
  fi

  if kubectl get resourcequota development-quota \
    -n development >/dev/null 2>&1; then
    echo "✅ ResourceQuota disponible"
  else
    echo "❌ ResourceQuota no encontrada"
  fi

  if kubectl get limitrange development-limits \
    -n development >/dev/null 2>&1; then
    echo "✅ LimitRange disponible"
  else
    echo "❌ LimitRange no encontrado"
  fi

  echo ""
  echo "Deployments restantes:"
  kubectl get deployments --all-namespaces | grep webapp

  echo "=== Fin de verificacion ==="
  ```

**Salida esperada aproximada:**

```text
=== Verificacion final de la Practica 4 ===
✅ Namespace development disponible
✅ Namespace production disponible
✅ staging fue eliminado
✅ ResourceQuota disponible
✅ LimitRange disponible
...
=== Fin de verificacion ===
```

> **IMPORTANTE:** Conserva `development`, `production` y el clúster Minikube. La práctica complementaria siguiente profundizará en separación lógica por ambiente utilizando namespaces.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🛠️ Resolución de problemas

### Problema 1. Un namespace ya existe

**Síntoma:** `kubectl create namespace development` devuelve un error indicando que el recurso ya existe.

**Causa probable:** El namespace fue creado previamente durante otra ejecución del laboratorio.

**Solución:**

Comprueba primero su estado y labels antes de decidir si debes reutilizarlo.

```bash
kubectl get namespace development --show-labels
```

Si pertenece a una ejecución anterior y necesitas reiniciar completamente el ejercicio, elimina solamente ese namespace y vuelve a crearlo.

---

### Problema 2. El Deployment no crea Pods después de aplicar ResourceQuota

**Síntoma:** El Deployment existe, pero algunas réplicas no pueden crearse y los eventos muestran `exceeded quota`.

**Causa probable:** La suma de requests o limits de los Pods supera los valores máximos definidos en `development-quota`.

**Solución:**

Consulta primero el consumo actual:

```bash
kubectl describe resourcequota development-quota -n development
kubectl get pods -n development
```

Reduce réplicas o ajusta los valores de recursos del workload antes de modificar la cuota.

---

### Problema 3. El Pod de prueba no recibe resources automáticamente

**Síntoma:** Al consultar `test-limitrange`, la sección `resources` aparece vacía o no contiene los valores configurados.

**Causa probable:** El Pod fue creado antes de que existiera el LimitRange o el recurso no fue aplicado correctamente.

**Solución:**

Confirma que el LimitRange existe y recrea únicamente el Pod de prueba.

```bash
kubectl get limitrange development-limits -n development
kubectl delete pod test-limitrange -n development --ignore-not-found

kubectl run test-limitrange \
  --image=nginx:1.27-alpine \
  --restart=Never \
  -n development
```

---

### Problema 4. staging permanece en Terminating

**Síntoma:** Después de eliminar `staging`, el namespace permanece durante varios minutos en estado `Terminating`.

**Causa probable:** Kubernetes todavía está procesando recursos o finalizers existentes dentro del namespace.

**Solución:**

Consulta primero el estado del namespace y los recursos que todavía puedan existir.

```bash
kubectl get namespace staging
kubectl get all -n staging
```

En un laboratorio estándar con Minikube, espera a que Kubernetes complete la terminación antes de intentar intervenciones manuales sobre finalizers.

---

### Problema 5. kubectl consulta el namespace equivocado

**Síntoma:** Un comando sin `-n` no encuentra un recurso que sabes que existe en otro namespace.

**Causa probable:** kubectl utiliza el namespace configurado en el contexto actual o `default` cuando no existe uno explícito.

**Solución:**

Consulta el contexto y utiliza el namespace de forma explícita.

```bash
kubectl config current-context
kubectl config view --minify
kubectl get deployments -n development
kubectl get deployments -n production
```

Para evitar ambigüedad durante esta práctica, utiliza `-n <namespace>` en las operaciones sobre recursos namespaced.
