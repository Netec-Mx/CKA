---
layout: lab
title: "Práctica 9: Simulación integral tipo CKA"
permalink: /lab15/lab15/
images_base: /labs/lab15/img
duration: "120 minutos"
objective:
  - Resolver escenarios administrativos de Kubernetes bajo una restricción estricta de tiempo.
  - Integrar mantenimiento de nodos, RBAC, scheduling, networking, almacenamiento y troubleshooting.
  - Aplicar una estrategia de examen basada en lectura, priorización, ejecución y verificación.
  - Trabajar con recursos existentes y defectuosos sin depender de instrucciones paso a paso.
  - Validar cada solución mediante criterios técnicos objetivos antes de darla por terminada.
prerequisites:
  - Haber completado las prácticas 1 a 8 y sus prácticas complementarias.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Conservar un clúster Minikube de tres nodos.
  - Tener dominio operativo de kubectl, YAML, Services, RBAC, almacenamiento y troubleshooting.
introduction:
  - Esta práctica es una simulación de examen inspirada en el formato práctico del Certified Kubernetes Administrator. Dispondrás de 120 minutos para resolver diez escenarios independientes con un valor total de 100 puntos. Los enunciados especifican el estado final requerido, pero no proporcionan la solución. Deberás decidir qué comandos, manifiestos y técnicas utilizar, validar cada tarea y administrar tu tiempo como si estuvieras en una evaluación práctica.
slug: lab15
lab_number: 15
final_result: >
  Al finalizar la simulación habrás resuelto diez escenarios integrales de administración de Kubernetes bajo presión de tiempo, aplicando técnicas de mantenimiento, configuración, networking, almacenamiento, scheduling, RBAC y troubleshooting.
notes:
  - Esta simulación utiliza Minikube y no reproduce la plataforma oficial de entrega del examen CKA.
  - La preparación del entorno se realiza antes de iniciar el cronómetro.
  - Durante el modo examen no se incluyen prompts de apoyo con IA ni soluciones paso a paso.
  - Cada tarea es independiente; si una tarea consume demasiado tiempo, continúa con la siguiente y regresa al final.
  - La puntuación de esta práctica es pedagógica y no representa el sistema oficial de calificación del CKA.
references:
  - text: Certified Kubernetes Administrator (CKA)
    url: https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/
  - text: kubectl Cheat Sheet
    url: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
  - text: Debug Running Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
  - text: Debug Services
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
prev: /lab14/lab14/
next: /
---

---
<!-- Aquí comienzan las instrucciones de la simulación -->

# 🏁 Simulación tipo CKA

## Información de la evaluación

| Elemento | Valor |
|---|---:|
| Tiempo total | **120 minutos** |
| Tareas | **10** |
| Puntuación máxima | **100 puntos** |
| Modalidad | Práctica / terminal |
| Clúster | Minikube de 3 nodos |
| Herramienta principal | `kubectl` |
| Soluciones durante el examen | **No disponibles** |

> **IMPORTANTE:** El examen CKA oficial es actualmente una evaluación práctica de dos horas. Esta simulación reproduce el enfoque de resolución por terminal y la presión de tiempo, pero utiliza Minikube y recursos preparados específicamente para este curso.
{: .lab-note .important .compact}

---

# 📋 Reglas del modo examen

Durante los 120 minutos:

1. Lee completamente el enunciado antes de modificar recursos.
2. Verifica siempre el namespace indicado.
3. Conserva exactamente los nombres solicitados.
4. No elimines recursos que el enunciado no autorice eliminar.
5. Puedes utilizar comandos imperativos, YAML o una combinación de ambos.
6. Puedes utilizar `--dry-run=client -o yaml` para generar manifiestos.
7. Verifica cada tarea antes de avanzar.
8. Si una tarea te bloquea durante varios minutos, márcala y continúa.
9. No ejecutes el script de evaluación final hasta terminar o decidir cerrar el examen.
10. No utilices los laboratorios anteriores como soluciones literales; interpreta el escenario.

---

# 🧠 Estrategia recomendada

Una estrategia eficiente para esta simulación es:

```text
0–5 min     Leer las diez tareas y marcar dificultad.
5–95 min    Resolver tareas priorizando puntos rápidos.
95–110 min  Regresar a tareas pendientes.
110–120 min Ejecutar verificaciones y corregir detalles.
```

Utiliza una hoja simple:

```text
T1  [ ] 15 pts
T2  [ ] 10 pts
T3  [ ]  8 pts
T4  [ ]  7 pts
T5  [ ] 10 pts
T6  [ ] 10 pts
T7  [ ] 10 pts
T8  [ ] 10 pts
T9  [ ] 10 pts
T10 [ ] 10 pts
```

---

# 🛠️ Preparación del entorno — NO inicia el cronómetro

## Preparación 1. Verificar el clúster

- {% include step_label.html %} Confirma que Minikube tiene tres nodos disponibles.

  ```bash
  minikube status
  kubectl get nodes -o wide
  ```

El resultado debe incluir:

```text
minikube
minikube-m02
minikube-m03
```

## Preparación 2. Verificar Ingress y almacenamiento

- {% include step_label.html %} Asegura que el Ingress Controller y el provisioner de almacenamiento estén disponibles antes de iniciar.

  ```bash
  minikube addons enable ingress
  minikube addons enable storage-provisioner
  minikube addons enable default-storageclass
  ```

- {% include step_label.html %} Espera a que el controlador Ingress quede disponible.

  ```bash
  kubectl rollout status \
    deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=180s
  ```

## Preparación 3. Crear directorio

- {% include step_label.html %} Crea el directorio de trabajo.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab15
  cd /c/LABS/kubernetes/lab15
  ```

## Preparación 4. Crear alias de sesión

- {% include step_label.html %} Define un alias temporal para reducir escritura durante el examen.

  ```bash
  alias k=kubectl
  ```

> **NOTA:** El alias se mantiene únicamente en la terminal actual. Si abres otra terminal, deberás volver a ejecutarlo.
{: .lab-note .info .compact}

## Preparación 5. Crear escenarios iniciales

- {% include step_label.html %} Crea el archivo `exam-setup.yaml`.

  ```bash
  touch exam-setup.yaml
  ```

- {% include step_label.html %} Agrega el contenido siguiente sin modificar los errores intencionales.

  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-admin
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-security
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-workloads
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-network
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-storage
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: cka-troubleshoot
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: maintenance-app
    namespace: cka-admin
  spec:
    replicas: 6
    selector:
      matchLabels:
        app: maintenance-app
    template:
      metadata:
        labels:
          app: maintenance-app
      spec:
        containers:
          - name: nginx
            image: nginx:1.27-alpine
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: broken-backend
    namespace: cka-network
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
          - name: nginx
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: broken-backend-svc
    namespace: cka-network
  spec:
    type: ClusterIP
    selector:
      app: backend-error
    ports:
      - port: 80
        targetPort: 8080
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: image-failure
    namespace: cka-troubleshoot
  spec:
    containers:
      - name: app
        image: nginx:tag-does-not-exist-cka
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: crash-failure
    namespace: cka-troubleshoot
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c", "exit 17"]
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: dns-backend
    namespace: cka-troubleshoot
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: dns-backend
    template:
      metadata:
        labels:
          app: dns-backend
      spec:
        containers:
          - name: nginx
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: dns-backend-svc
    namespace: cka-troubleshoot
  spec:
    selector:
      app: dns-wrong
    ports:
      - port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: dns-client
    namespace: cka-troubleshoot
  spec:
    dnsPolicy: None
    dnsConfig:
      nameservers:
        - 1.2.3.4
    containers:
      - name: tools
        image: busybox:1.36
        command: ["sh", "-c", "sleep 7200"]
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: production-api
    namespace: cka-troubleshoot
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: production-api
    template:
      metadata:
        labels:
          app: production-api
      spec:
        containers:
          - name: nginx
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
            readinessProbe:
              httpGet:
                path: /ready-does-not-exist
                port: 80
              initialDelaySeconds: 3
              periodSeconds: 3
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: production-api-svc
    namespace: cka-troubleshoot
  spec:
    selector:
      app: production-api
    ports:
      - port: 80
        targetPort: 80
  ```

- {% include step_label.html %} Aplica la configuración inicial.

  ```bash
  kubectl apply -f exam-setup.yaml
  ```

- {% include step_label.html %} Espera 20 segundos y observa únicamente el estado general, sin resolver todavía los fallos.

  ```bash
  sleep 20

  kubectl get pods -A | grep -E 'cka-|NAMESPACE'
  ```

---

# ⏱️ INICIA EL CRONÓMETRO — 120 MINUTOS

---

# Tarea 1 — Mantenimiento de nodo

**Dominio:** Cluster Architecture, Installation & Configuration  
**Valor:** **15 puntos**  
**Tiempo objetivo:** 15 minutos

## Escenario

El nodo `minikube-m02` debe entrar en mantenimiento sin dejar nuevos workloads programados sobre él.

El Deployment `maintenance-app`, ubicado en `cka-admin`, debe permanecer disponible durante la operación.

## Estado final requerido

Realiza las acciones necesarias para que:

- `minikube-m02` quede marcado temporalmente como no programable.
- los workloads administrados que puedan desalojarse sean retirados del nodo;
- los DaemonSets no bloqueen la operación;
- los Pods desalojados sean reprogramados en nodos disponibles;
- al finalizar, `minikube-m02` vuelva a aceptar scheduling;
- `maintenance-app` termine con **6/6 réplicas disponibles**.

## Restricciones

- No elimines el nodo.
- No elimines el Deployment.
- No reduzcas permanentemente el número de réplicas.
- No reinicies Minikube.

## Criterios de aceptación

```text
[ ] minikube-m02 termina en estado Ready,SchedulingEnabled.
[ ] maintenance-app termina con 6 réplicas disponibles.
[ ] Ningún Pod de maintenance-app queda Pending.
```

## Verificación permitida

```bash
kubectl get nodes
kubectl get pods -n cka-admin -o wide
kubectl get deployment maintenance-app -n cka-admin
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

---

# Tarea 2 — RBAC con mínimo privilegio

**Dominio:** Cluster Architecture, Installation & Configuration  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 10 minutos

## Escenario

Una aplicación necesita consultar información operativa en el namespace `cka-security`.

Crea los recursos necesarios para proporcionar acceso de solo lectura.

## Estado final requerido

En `cka-security` deben existir:

- ServiceAccount: `auditor`
- Role: `workload-reader`
- RoleBinding: `auditor-reader`

La identidad `auditor` debe poder:

```text
get, list, watch Pods
get, list ConfigMaps
```

No debe poder:

```text
create Pods
delete Pods
get Secrets
```

## Restricciones

- No utilices `ClusterRole`.
- No utilices wildcards `*`.
- No concedas acceso a Secrets.
- El permiso debe quedar limitado a `cka-security`.

## Criterios de aceptación

```text
[ ] ServiceAccount auditor existe.
[ ] Role workload-reader contiene solo los permisos requeridos.
[ ] RoleBinding auditor-reader vincula auditor con workload-reader.
[ ] kubectl auth can-i get pods devuelve yes.
[ ] kubectl auth can-i get secrets devuelve no.
```

## Comando de identidad para tus pruebas

```text
system:serviceaccount:cka-security:auditor
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

---

# Tarea 3 — Rolling update y rollback

**Dominio:** Workloads & Scheduling  
**Valor:** **8 puntos**  
**Tiempo objetivo:** 9 minutos

## Escenario

Debes crear una aplicación web administrada mediante Deployment.

## Estado final requerido

En `cka-workloads` crea:

```text
Deployment: exam-web
Réplicas: 4
Imagen inicial: nginx:1.27-alpine
```

Después:

1. actualiza la imagen a `nginx:1.28-alpine`;
2. verifica el rollout;
3. revierte a la revisión anterior.

El estado final debe ser:

```text
4/4 réplicas Ready
imagen nginx:1.27-alpine
historial con al menos dos revisiones
```

## Restricciones

- Debes utilizar el mecanismo de rollout del Deployment.
- No resuelvas el rollback eliminando y recreando el Deployment.

## Criterios de aceptación

```text
[ ] exam-web existe con 4 réplicas.
[ ] El historial contiene más de una revisión.
[ ] La imagen final es nginx:1.27-alpine.
[ ] El Deployment finaliza 4/4 Ready.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

---

# Tarea 4 — Scheduling con label, taint y toleration

**Dominio:** Workloads & Scheduling  
**Valor:** **7 puntos**  
**Tiempo objetivo:** 9 minutos

## Escenario

El nodo `minikube-m03` será reservado para una carga analítica.

## Estado final requerido

Configura el nodo con:

```text
label:
workload=analytics

taint:
dedicated=analytics:NoSchedule
```

Después crea en `cka-workloads`:

```text
Deployment: analytics-app
Réplicas: 2
Imagen: nginx:1.27-alpine
```

Los Pods de `analytics-app` deben:

- ejecutarse exclusivamente en `minikube-m03`;
- tolerar el taint configurado;
- terminar `Running` y `Ready`.

## Restricciones

- No elimines el taint para hacer funcionar la aplicación.
- No utilices `nodeName`.
- Debes utilizar scheduling declarativo.

## Criterios de aceptación

```text
[ ] minikube-m03 tiene el label workload=analytics.
[ ] minikube-m03 tiene el taint dedicated=analytics:NoSchedule.
[ ] analytics-app tiene 2/2 réplicas Ready.
[ ] Ambos Pods ejecutan en minikube-m03.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

---

# Tarea 5 — Reparar Service y exponer mediante NodePort

**Dominio:** Services & Networking  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 11 minutos

## Escenario

El Deployment `broken-backend` está operativo, pero el Service `broken-backend-svc` no permite acceder a sus Pods.

## Estado final requerido

Diagnostica y corrige el Service existente.

Después conviértelo o configúralo para cumplir:

```text
Nombre: broken-backend-svc
Namespace: cka-network
Tipo: NodePort
Service port: 80
Target port: 80
NodePort: 30081
```

## Restricciones

- No modifiques los labels del Deployment.
- No elimines `broken-backend`.
- Conserva el nombre del Service.

## Criterios de aceptación

```text
[ ] El selector del Service coincide con los Pods.
[ ] El targetPort es 80.
[ ] El tipo del Service es NodePort.
[ ] nodePort es exactamente 30081.
[ ] El Service tiene 2 endpoints disponibles.
```

## Validación funcional

En Windows/macOS con driver Docker puedes utilizar:

```bash
minikube service broken-backend-svc \
  -n cka-network \
  --url
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

---

# Tarea 6 — Ingress con enrutamiento por path

**Dominio:** Services & Networking  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 12 minutos

## Escenario

Debes publicar dos aplicaciones detrás de un único Ingress.

## Estado final requerido

En `cka-network` crea:

### Aplicación frontend

```text
Deployment: portal
Réplicas: 2
Imagen: nginx:1.27-alpine
Service: portal-svc
Service port: 80
```

### Aplicación API

```text
Deployment: api
Réplicas: 2
Imagen: nginx:1.27-alpine
Service: api-svc
Service port: 80
```

### Ingress

```text
Nombre: exam-ingress
IngressClass: nginx

/       → portal-svc:80
/api    → api-svc:80
```

La ruta `/api` debe llegar correctamente al backend aunque NGINX solo disponga de `/` como contenido inicial.

## Restricciones

- No expongas los Deployments mediante NodePort.
- Utiliza Services ClusterIP.
- Conserva exactamente los nombres solicitados.

## Criterios de aceptación

```text
[ ] portal tiene 2/2 réplicas Ready.
[ ] api tiene 2/2 réplicas Ready.
[ ] portal-svc y api-svc tienen endpoints.
[ ] exam-ingress utiliza la clase nginx.
[ ] / apunta a portal-svc.
[ ] /api apunta a api-svc.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r6 %}{{ results[5] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r6 %}

---

# Tarea 7 — PersistentVolume y PersistentVolumeClaim

**Dominio:** Storage  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 12 minutos

## Escenario

Una aplicación necesita almacenamiento persistente estático.

## Estado final requerido

Crea:

### PersistentVolume

```text
Nombre: exam-pv
Capacidad: 1Gi
AccessMode: ReadWriteOnce
ReclaimPolicy: Retain
StorageClassName: ""
Backend: hostPath
Ruta: /mnt/data/cka-exam
Nodo permitido: minikube
```

### PersistentVolumeClaim

En `cka-storage`:

```text
Nombre: exam-pvc
Solicitud: 500Mi
AccessMode: ReadWriteOnce
StorageClassName: ""
Debe enlazarse con exam-pv
```

### Pod consumidor

```text
Nombre: storage-check
Namespace: cka-storage
Imagen: busybox:1.36
MountPath: /data
```

El Pod debe permanecer en ejecución y debe existir:

```text
/data/exam.txt
```

con el contenido exacto:

```text
CKA-STORAGE-OK
```

## Criterios de aceptación

```text
[ ] exam-pv está Bound.
[ ] exam-pvc está Bound con exam-pv.
[ ] storage-check está Running.
[ ] storage-check ejecuta en minikube.
[ ] /data/exam.txt contiene CKA-STORAGE-OK.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r7 %}{{ results[6] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r7 %}

---

# Tarea 8 — Troubleshooting de Pods

**Dominio:** Troubleshooting  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 10 minutos

## Escenario

En `cka-troubleshoot` existen dos Pods defectuosos:

```text
image-failure
crash-failure
```

## Estado final requerido

Diagnostica ambos recursos y corrige la causa raíz.

Al finalizar:

```text
image-failure → Running / Ready
crash-failure → Running / Ready
```

Ambos deben utilizar:

```text
nginx:1.27-alpine
```

## Restricciones

- Antes de corregir cada Pod debes revisar la evidencia disponible mediante `describe`, `logs` o Events.
- Conserva los nombres originales.
- No reemplaces los Pods por Deployments.

## Criterios de aceptación

```text
[ ] image-failure utiliza nginx:1.27-alpine.
[ ] image-failure está Running.
[ ] crash-failure utiliza nginx:1.27-alpine.
[ ] crash-failure permanece Running sin reinicios continuos.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r8 %}{{ results[7] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r8 %}

---

# Tarea 9 — Service y DNS

**Dominio:** Troubleshooting  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 10 minutos

## Escenario

En `cka-troubleshoot`:

- `dns-backend` tiene dos Pods saludables;
- `dns-backend-svc` no encuentra correctamente sus backends;
- `dns-client` no utiliza la política DNS normal del clúster.

## Estado final requerido

Corrige ambos problemas.

Desde `dns-client` deben funcionar:

```text
nslookup dns-backend-svc

nslookup dns-backend-svc.cka-troubleshoot.svc.cluster.local
```

y la petición:

```text
http://dns-backend-svc
```

debe devolver contenido NGINX.

## Restricciones

- No modifiques CoreDNS.
- No reinicies el clúster.
- No cambies los labels del Deployment `dns-backend`.
- Conserva los nombres de los recursos.

## Criterios de aceptación

```text
[ ] dns-backend-svc tiene 2 endpoints.
[ ] dns-client utiliza la política DNS normal del clúster.
[ ] El nombre corto resuelve.
[ ] El FQDN resuelve.
[ ] La petición HTTP al Service funciona.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r9 %}{{ results[8] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r9 %}

---

# Tarea 10 — Incidente integral de disponibilidad

**Dominio:** Troubleshooting  
**Valor:** **10 puntos**  
**Tiempo objetivo:** 12 minutos

## Escenario

El Service `production-api-svc` existe y el Deployment `production-api` mantiene tres Pods en ejecución, pero la aplicación no está disponible a través del Service.

Tu responsabilidad es encontrar la causa raíz y restaurar el servicio.

## Estado final requerido

Al finalizar:

```text
Deployment production-api:
3/3 réplicas Ready

Service production-api-svc:
3 endpoints disponibles
```

Desde un Pod temporal dentro de `cka-troubleshoot`:

```text
wget http://production-api-svc
```

debe devolver la página de NGINX.

## Restricciones

- No elimines el Deployment.
- No elimines el Service.
- No reduzcas las réplicas.
- No cambies la imagen.
- Corrige únicamente la configuración responsable del incidente.

## Criterios de aceptación

```text
[ ] production-api tiene 3/3 réplicas Ready.
[ ] Los Pods no presentan reinicios continuos.
[ ] production-api-svc tiene 3 endpoints.
[ ] La prueba HTTP devuelve contenido correctamente.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r10 %}{{ results[9] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r10 %}

---

# ⏹️ FIN DEL EXAMEN

Cuando el cronómetro llegue a cero:

1. Detén cualquier modificación.
2. No borres recursos fallidos.
3. Ejecuta únicamente las verificaciones siguientes.
4. Registra tu puntuación.

---

# 🧾 Evaluación automática

## Crear el evaluador

- {% include step_label.html %} Crea `validate-exam.sh` con el contenido siguiente.

  ```bash
  cat > validate-exam.sh <<'EOF'
  #!/usr/bin/env bash

  PASS=0
  TOTAL=100

  pass() {
    echo "✅ $1 (+$2)"
    PASS=$((PASS + $2))
  }

  fail() {
    echo "❌ $1 (+0/$2)"
  }

  echo "================================================"
  echo "        EVALUACION SIMULACION TIPO CKA"
  echo "================================================"

  echo ""
  echo "--- T1 Mantenimiento de nodo: 15 puntos ---"

  UNSCHED=$(kubectl get node minikube-m02 \
    -o jsonpath='{.spec.unschedulable}' 2>/dev/null)

  READY=$(kubectl get deployment maintenance-app \
    -n cka-admin \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  if [ "$UNSCHED" != "true" ] && [ "$READY" = "6" ]; then
    pass "T1 mantenimiento completado" 15
  else
    fail "T1 mantenimiento incompleto" 15
  fi

  echo ""
  echo "--- T2 RBAC: 10 puntos ---"

  CAN_GET=$(kubectl auth can-i get pods \
    --as=system:serviceaccount:cka-security:auditor \
    -n cka-security 2>/dev/null)

  CAN_SECRET=$(kubectl auth can-i get secrets \
    --as=system:serviceaccount:cka-security:auditor \
    -n cka-security 2>/dev/null)

  if [ "$CAN_GET" = "yes" ] && [ "$CAN_SECRET" = "no" ]; then
    pass "T2 RBAC correcto" 10
  else
    fail "T2 RBAC incorrecto" 10
  fi

  echo ""
  echo "--- T3 Rollout: 8 puntos ---"

  T3_READY=$(kubectl get deployment exam-web \
    -n cka-workloads \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  T3_IMAGE=$(kubectl get deployment exam-web \
    -n cka-workloads \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  if [ "$T3_READY" = "4" ] && [ "$T3_IMAGE" = "nginx:1.27-alpine" ]; then
    pass "T3 rollout y rollback correctos" 8
  else
    fail "T3 rollout incompleto" 8
  fi

  echo ""
  echo "--- T4 Scheduling: 7 puntos ---"

  T4_READY=$(kubectl get deployment analytics-app \
    -n cka-workloads \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  T4_NODES=$(kubectl get pod \
    -n cka-workloads \
    -l app=analytics-app \
    -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)

  if [ "$T4_READY" = "2" ] && \
     echo "$T4_NODES" | grep -q "minikube-m03" && \
     ! echo "$T4_NODES" | grep -q "minikube-m02"; then
    pass "T4 scheduling correcto" 7
  else
    fail "T4 scheduling incorrecto" 7
  fi

  echo ""
  echo "--- T5 Service NodePort: 10 puntos ---"

  T5_TYPE=$(kubectl get service broken-backend-svc \
    -n cka-network \
    -o jsonpath='{.spec.type}' 2>/dev/null)

  T5_NODEPORT=$(kubectl get service broken-backend-svc \
    -n cka-network \
    -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

  T5_EP=$(kubectl get endpoints broken-backend-svc \
    -n cka-network \
    -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

  if [ "$T5_TYPE" = "NodePort" ] && \
     [ "$T5_NODEPORT" = "30081" ] && \
     [ "$T5_EP" -eq 2 ]; then
    pass "T5 Service reparado" 10
  else
    fail "T5 Service incorrecto" 10
  fi

  echo ""
  echo "--- T6 Ingress: 10 puntos ---"

  PORTAL_READY=$(kubectl get deployment portal \
    -n cka-network \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  API_READY=$(kubectl get deployment api \
    -n cka-network \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  INGRESS_CLASS=$(kubectl get ingress exam-ingress \
    -n cka-network \
    -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)

  if [ "$PORTAL_READY" = "2" ] && \
     [ "$API_READY" = "2" ] && \
     [ "$INGRESS_CLASS" = "nginx" ]; then
    pass "T6 Ingress creado" 10
  else
    fail "T6 Ingress incompleto" 10
  fi

  echo ""
  echo "--- T7 Storage: 10 puntos ---"

  PVC_PHASE=$(kubectl get pvc exam-pvc \
    -n cka-storage \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  STORAGE_DATA=$(kubectl exec storage-check \
    -n cka-storage -- \
    cat /data/exam.txt 2>/dev/null)

  if [ "$PVC_PHASE" = "Bound" ] && \
     [ "$STORAGE_DATA" = "CKA-STORAGE-OK" ]; then
    pass "T7 almacenamiento correcto" 10
  else
    fail "T7 almacenamiento incorrecto" 10
  fi

  echo ""
  echo "--- T8 Troubleshooting Pods: 10 puntos ---"

  P1=$(kubectl get pod image-failure \
    -n cka-troubleshoot \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  P2=$(kubectl get pod crash-failure \
    -n cka-troubleshoot \
    -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ "$P1" = "Running" ] && [ "$P2" = "Running" ]; then
    pass "T8 Pods reparados" 10
  else
    fail "T8 Pods continúan fallando" 10
  fi

  echo ""
  echo "--- T9 DNS y Service: 10 puntos ---"

  DNS_EP=$(kubectl get endpoints dns-backend-svc \
    -n cka-troubleshoot \
    -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

  kubectl exec dns-client \
    -n cka-troubleshoot -- \
    nslookup dns-backend-svc >/dev/null 2>&1
  DNS_OK=$?

  if [ "$DNS_EP" -eq 2 ] && [ "$DNS_OK" -eq 0 ]; then
    pass "T9 DNS y Service correctos" 10
  else
    fail "T9 DNS o Service incorrectos" 10
  fi

  echo ""
  echo "--- T10 Incidente integral: 10 puntos ---"

  PROD_READY=$(kubectl get deployment production-api \
    -n cka-troubleshoot \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  PROD_EP=$(kubectl get endpoints production-api-svc \
    -n cka-troubleshoot \
    -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)

  if [ "$PROD_READY" = "3" ] && [ "$PROD_EP" -eq 3 ]; then
    pass "T10 disponibilidad restaurada" 10
  else
    fail "T10 incidente no resuelto" 10
  fi

  echo ""
  echo "================================================"
  echo "PUNTUACION FINAL: $PASS / $TOTAL"
  echo "================================================"

  if [ "$PASS" -ge 75 ]; then
    echo "🎓 RESULTADO PEDAGOGICO: APROBADO"
  else
    echo "📚 RESULTADO PEDAGOGICO: REQUIERE REPASO"
  fi
  EOF
  ```

- {% include step_label.html %} Ejecuta el evaluador.

  ```bash
  chmod +x validate-exam.sh
  ./validate-exam.sh
  ```

> **IMPORTANTE:** El umbral de 75 puntos utilizado aquí es una regla pedagógica de esta práctica. No debe interpretarse como el puntaje oficial vigente del examen CKA.
{: .lab-note .important .compact}

---

# 📊 Interpretación pedagógica del resultado

| Puntuación | Interpretación |
|---:|---|
| 90–100 | Excelente dominio operativo y buena administración del tiempo |
| 80–89 | Preparación sólida; revisar errores puntuales |
| 75–79 | Aprobación pedagógica mínima; todavía existen áreas de riesgo |
| 60–74 | Conocimiento funcional, pero insuficiente bajo presión de tiempo |
| <60 | Requiere repasar fundamentos antes de realizar otra simulación |

---

# 🧾 Hoja de revisión posterior

Después de finalizar el cronómetro y registrar la puntuación, documenta:

```text
Tareas completadas sin ayuda:
Tareas completadas después de regresar:
Tareas no completadas:
Tarea que consumió más tiempo:
Comandos que necesitaste consultar:
Errores por namespace:
Errores de sintaxis YAML:
Errores de interpretación:
Puntuación final:
Tiempo utilizado:
```

La finalidad de esta hoja es detectar si el problema fue de conocimiento, sintaxis, diagnóstico o administración del tiempo.

---

# 🛠️ Troubleshooting de la simulación

## Problema 1. El entorno inicial no coincide con los escenarios

Si un recurso de preparación fue modificado accidentalmente antes de iniciar, restablece únicamente el escenario correspondiente desde `exam-setup.yaml`.

```bash
kubectl apply -f exam-setup.yaml
```

No ejecutes esta acción durante la evaluación si ya comenzaste a resolver tareas, porque podría sobrescribir cambios válidos.

---

## Problema 2. El Ingress Controller no está disponible

Comprueba su estado:

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass
```

La preparación del entorno debe completarse antes de iniciar el cronómetro.

---

## Problema 3. Un NodePort no es accesible directamente desde Windows o macOS

Esto no implica necesariamente un error del Service con el driver Docker.

Utiliza:

```bash
minikube service NOMBRE \
  -n NAMESPACE \
  --url
```

y conserva abierta la terminal si Minikube necesita mantener un túnel local.

---

## Problema 4. T4 deja cargas ajenas sin programar

El taint `dedicated=analytics:NoSchedule` afecta a nuevos Pods que no lo toleren.

Esto forma parte del escenario. No elimines el taint durante el examen porque es un criterio explícito de aceptación.

---

## Problema 5. El PV de T7 queda Available y el PVC Pending

Revisa compatibilidad entre:

```text
storageClassName
accessModes
capacity
volumeName
nodeAffinity
```

No cambies aleatoriamente varios parámetros al mismo tiempo; identifica primero cuál impide el binding.

---

# 🧹 Limpieza posterior

Ejecuta la limpieza solo después de registrar el resultado.

```bash
kubectl delete namespace \
  cka-admin \
  cka-security \
  cka-workloads \
  cka-network \
  cka-storage \
  cka-troubleshoot \
  --ignore-not-found=true

kubectl delete pv exam-pv \
  --ignore-not-found=true

kubectl uncordon minikube-m02 \
  2>/dev/null || true

kubectl taint node minikube-m03 \
  dedicated=analytics:NoSchedule- \
  2>/dev/null || true

kubectl label node minikube-m03 \
  workload- \
  2>/dev/null || true

kubectl config set-context \
  --current \
  --namespace=default
```

No elimines el clúster Minikube si deseas repetir la simulación.

---

# 🎓 Qué evalúa esta simulación

La distribución se diseñó para aproximarse a los dominios actuales del CKA dentro de lo que puede reproducirse razonablemente en un clúster Minikube local:

| Dominio | Tareas | Puntos |
|---|---|---:|
| Cluster Architecture, Installation & Configuration | T1, T2 | 25 |
| Workloads & Scheduling | T3, T4 | 15 |
| Services & Networking | T5, T6 | 20 |
| Storage | T7 | 10 |
| Troubleshooting | T8, T9, T10 | 30 |
| **Total** | **10 tareas** | **100** |

La simulación prioriza trabajo real en terminal, validación de estado y diagnóstico bajo presión de tiempo. No intenta copiar preguntas del examen oficial ni sustituye el simulador oficial.
