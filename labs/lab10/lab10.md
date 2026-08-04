---
layout: lab
title: "Práctica 6: Exposición de aplicaciones con Services e Ingress"
permalink: /lab10/lab10/
images_base: /labs/lab10/img
duration: "70 minutos"
objective:
  - Desplegar dos aplicaciones que representen los componentes frontend y backend de una solución.
  - Crear Services ClusterIP para proporcionar acceso interno estable hacia Pods administrados por Deployments.
  - Exponer el frontend mediante un Service NodePort y comprobar el acceso desde el equipo host.
  - Habilitar el Ingress Controller de Minikube y crear reglas de enrutamiento por path hacia múltiples Services.
  - Validar el flujo completo Pod → Service → Ingress y reconocer los puntos principales de verificación.
prerequisites:
  - Haber completado la Práctica 5 y la Práctica complementaria 5.1.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Conservar el clúster Minikube de tres nodos utilizado en prácticas anteriores.
  - Comprender Pods, Deployments, labels, selectors y puertos TCP.
introduction:
  - En esta práctica construirás el flujo de exposición de una aplicación Kubernetes utilizando Services e Ingress. Desplegarás un frontend y un backend, crearás Services ClusterIP para comunicación interna, expondrás el frontend mediante NodePort y habilitarás el NGINX Ingress Controller de Minikube para enrutar las rutas / y /api hacia Services diferentes. Las prácticas complementarias posteriores profundizarán en diagnóstico de Services, endpoints y DNS interno.
slug: lab10
lab_number: 10
final_result: >
  Al finalizar la práctica habrás desplegado una arquitectura frontend/backend y comprobado tres niveles de exposición: acceso interno mediante ClusterIP, acceso externo mediante NodePort y enrutamiento HTTP centralizado mediante Ingress.
notes:
  - Esta práctica utiliza un namespace dedicado llamado lab10.
  - En Windows y macOS con el driver Docker, utiliza minikube service --url para probar NodePort de forma confiable.
  - Para validar Ingress desde el host se utilizará un port-forward temporal hacia el Ingress Controller, evitando depender de rutas especiales del host hacia la red interna de Minikube.
  - La resolución DNS detallada y el diagnóstico profundo de endpoints se trabajarán en prácticas complementarias.
references:
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: Ingress
    url: https://kubernetes.io/docs/concepts/services-networking/ingress/
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
  - text: Minikube Addons
    url: https://minikube.sigs.k8s.io/docs/commands/addons/
prev: /lab9/lab9/
next: /lab11/lab11/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio y namespace

En esta práctica crearás un namespace independiente y los manifiestos necesarios para construir la arquitectura de red.

### 🗂️ Preparar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que el motor está activo antes de utilizar Minikube y desplegar los recursos.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio del laboratorio.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab10
  cd /c/LABS/kubernetes/lab10
  ```

- {% include step_label.html %} Confirma que Minikube continúa activo y que los tres nodos están disponibles antes de crear los workloads.

  ```bash
  minikube status
  kubectl get nodes
  ```

- {% include step_label.html %} Crea el namespace `lab10` y configúralo temporalmente como namespace predeterminado del contexto.

  ```bash
  kubectl create namespace lab10
  kubectl config set-context --current --namespace=lab10
  ```

- {% include step_label.html %} Verifica que el contexto activo utiliza el namespace correcto para evitar crear recursos accidentalmente en `default`.

  ```bash
  kubectl config view --minify | grep namespace
  ```

**Salida esperada:**

```text
namespace: lab10
```

---

## 🚀 Tarea 1. Desplegar frontend y backend

En esta tarea crearás dos Deployments con respuestas HTML diferentes para poder identificar visualmente qué componente procesa cada petición.

### Tarea 1.1. Crear el backend

- {% include step_label.html %} Crea el archivo `backend.yaml` para definir dos réplicas de NGINX que representarán una API interna.

  ```bash
  touch backend.yaml
  ```

- {% include step_label.html %} Abre el archivo en VS Code y agrega el Deployment siguiente.

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: backend
    namespace: lab10
    labels:
      app: backend
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
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
            command:
              - /bin/sh
              - -c
            args:
              - |
                echo "<html><body><h1>BACKEND API</h1><p>Pod: $(hostname)</p></body></html>" > /usr/share/nginx/html/index.html
                nginx -g 'daemon off;'
  ```

### Tarea 1.2. Crear el frontend

- {% include step_label.html %} Crea el archivo `frontend.yaml` y define dos réplicas para representar la capa web de la aplicación.

  ```bash
  touch frontend.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: frontend
    namespace: lab10
    labels:
      app: frontend
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: frontend
    template:
      metadata:
        labels:
          app: frontend
      spec:
        containers:
          - name: frontend
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
            command:
              - /bin/sh
              - -c
            args:
              - |
                echo "<html><body><h1>FRONTEND WEB</h1><p>Pod: $(hostname)</p></body></html>" > /usr/share/nginx/html/index.html
                nginx -g 'daemon off;'
  ```

### Tarea 1.3. Aplicar y validar

- {% include step_label.html %} Valida ambos manifiestos antes de crearlos para detectar problemas de sintaxis o estructura.

  ```bash
  kubectl apply --dry-run=client -f backend.yaml
  kubectl apply --dry-run=client -f frontend.yaml
  ```

- {% include step_label.html %} Aplica los Deployments y espera hasta que sus réplicas se encuentren disponibles.

  ```bash
  kubectl apply -f backend.yaml
  kubectl apply -f frontend.yaml

  kubectl rollout status deployment/backend
  kubectl rollout status deployment/frontend
  ```

- {% include step_label.html %} Consulta los Pods con información extendida y observa sus IPs y nodos de ejecución.

  ```bash
  kubectl get pods -o wide
  ```

**Resultado esperado:**

Deben existir cuatro Pods en estado `Running`: dos pertenecientes a `backend` y dos pertenecientes a `frontend`.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🔗 Tarea 2. Crear Services ClusterIP

En esta tarea proporcionarás identidades de red estables para frontend y backend. Los Pods pueden cambiar de IP, mientras un Service conserva una dirección virtual y selecciona los Pods mediante labels.

### Tarea 2.1. Crear los Services

- {% include step_label.html %} Crea el archivo `services-clusterip.yaml` para definir un Service interno para cada componente.

  ```bash
  touch services-clusterip.yaml
  ```

- {% include step_label.html %} Agrega los dos Services siguientes, ambos de tipo `ClusterIP`.

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: backend-svc
    namespace: lab10
  spec:
    type: ClusterIP
    selector:
      app: backend
    ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: frontend-svc
    namespace: lab10
  spec:
    type: ClusterIP
    selector:
      app: frontend
    ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 80
  ```

- {% include step_label.html %} Aplica el archivo y revisa las direcciones ClusterIP asignadas por Kubernetes.

  ```bash
  kubectl apply -f services-clusterip.yaml
  kubectl get services -o wide
  ```

**Salida esperada aproximada:**

```text
NAME           TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)
backend-svc    ClusterIP   10.96.x.x     <none>        80/TCP
frontend-svc   ClusterIP   10.96.y.y     <none>        80/TCP
```

### Tarea 2.2. Validar conectividad interna básica

- {% include step_label.html %} Obtén el nombre de uno de los Pods frontend para utilizarlo como origen de una prueba interna.

  ```bash
  FRONTEND_POD=$(kubectl get pod \
    -l app=frontend \
    -o jsonpath='{.items[0].metadata.name}')

  echo "$FRONTEND_POD"
  ```

- {% include step_label.html %} Desde el Pod frontend, realiza una petición HTTP hacia `backend-svc` utilizando el nombre estable del Service.

  ```bash
  kubectl exec "$FRONTEND_POD" -- \
    wget -qO- http://backend-svc
  ```

**Salida esperada aproximada:**

```html
<html><body><h1>BACKEND API</h1><p>Pod: backend-...</p></body></html>
```

- {% include step_label.html %} Ejecuta varias solicitudes para comprobar que el Service puede dirigir tráfico hacia las réplicas disponibles del backend.

  ```bash
  for i in 1 2 3 4; do
    kubectl exec "$FRONTEND_POD" -- \
      wget -qO- http://backend-svc | grep -o 'Pod: [^<]*'
  done
  ```

> **NOTA:** No es obligatorio observar una alternancia exacta entre Pods en cuatro solicitudes. Kubernetes distribuye conexiones entre endpoints disponibles, pero una secuencia corta no garantiza reparto perfectamente uniforme.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🌍 Tarea 3. Exponer el frontend mediante NodePort

En esta tarea crearás un segundo Service para frontend que pueda ser alcanzado desde fuera del clúster mediante un puerto asignado en los nodos.

### Tarea 3.1. Crear el NodePort

- {% include step_label.html %} Crea el archivo `frontend-nodeport.yaml` y define un Service que exponga el frontend mediante el puerto `30080`.

  ```bash
  touch frontend-nodeport.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: frontend-nodeport
    namespace: lab10
  spec:
    type: NodePort
    selector:
      app: frontend
    ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 80
        nodePort: 30080
  ```

- {% include step_label.html %} Aplica el manifiesto y comprueba la relación entre el puerto interno del Service y el NodePort externo.

  ```bash
  kubectl apply -f frontend-nodeport.yaml
  kubectl get service frontend-nodeport
  ```

**Salida esperada aproximada:**

```text
NAME                TYPE       CLUSTER-IP   EXTERNAL-IP   PORT(S)
frontend-nodeport   NodePort   10.96.x.x    <none>        80:30080/TCP
```

### Tarea 3.2. Obtener una URL accesible desde el host

- {% include step_label.html %} Ejecuta el comando siguiente para obtener la URL adecuada según el sistema operativo y el driver utilizado por Minikube.

  ```bash
  minikube service frontend-nodeport \
    --namespace=lab10 \
    --url
  ```

> **IMPORTANTE:** En Windows o macOS con el driver Docker, utiliza la URL devuelta por `minikube service --url`. No asumas que `minikube ip:30080` será accesible directamente desde el host.
{: .lab-note .important .compact}

- {% include step_label.html %} Copia la URL mostrada, abre otra terminal Git Bash y valida la respuesta mediante `curl`.

  ```bash
  curl -s URL_DEVUELTA_POR_MINIKUBE
  ```

**Resultado esperado:**

La respuesta debe contener:

```text
FRONTEND WEB
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🚦 Tarea 4. Habilitar Ingress y configurar enrutamiento por path

En esta tarea utilizarás Ingress para consolidar la exposición HTTP de frontend y backend bajo un único punto de entrada.

### Tarea 4.1. Habilitar el Ingress Controller

- {% include step_label.html %} Habilita el addon `ingress` de Minikube para instalar el NGINX Ingress Controller utilizado por las reglas HTTP.

  ```bash
  minikube addons enable ingress
  ```

- {% include step_label.html %} Espera hasta que el Deployment del controlador indique que está disponible antes de aplicar reglas de Ingress.

  ```bash
  kubectl rollout status \
    deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=180s
  ```

- {% include step_label.html %} Comprueba que el controlador y la clase `nginx` existen en el clúster.

  ```bash
  kubectl get pods -n ingress-nginx
  kubectl get ingressclass
  ```

### Tarea 4.2. Crear reglas para frontend y backend

- {% include step_label.html %} Crea el archivo `ingress.yaml`, que enviará `/` hacia frontend y `/api` hacia backend.

  ```bash
  touch ingress.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente utilizando `ingressClassName: nginx`.

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: app-ingress
    namespace: lab10
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/rewrite-target: /
  spec:
    ingressClassName: nginx
    rules:
      - http:
          paths:
            - path: /api
              pathType: Prefix
              backend:
                service:
                  name: backend-svc
                  port:
                    number: 80
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: frontend-svc
                  port:
                    number: 80
  ```

- {% include step_label.html %} Valida y aplica el recurso Ingress para registrar las reglas de enrutamiento en el controlador NGINX.

  ```bash
  kubectl apply --dry-run=client -f ingress.yaml
  kubectl apply -f ingress.yaml
  ```

- {% include step_label.html %} Revisa el recurso y confirma que cada path apunta al Service esperado.

  ```bash
  kubectl get ingress app-ingress
  kubectl describe ingress app-ingress
  ```

### Tarea 4.3. Probar Ingress desde el host

- {% include step_label.html %} Abre una segunda terminal Git Bash y crea un port-forward temporal hacia el Service del Ingress Controller.

  ```bash
  kubectl port-forward \
    -n ingress-nginx \
    service/ingress-nginx-controller \
    8080:80
  ```

**Salida esperada:**

```text
Forwarding from 127.0.0.1:8080 -> 80
```

> **IMPORTANTE:** Mantén esta segunda terminal abierta mientras realizas las pruebas siguientes. `port-forward` solo se utiliza como puente local hacia el controlador; las decisiones `/` y `/api` siguen siendo realizadas por Ingress.
{: .lab-note .important .compact}

- {% include step_label.html %} Desde la terminal principal, realiza una petición a `/` para comprobar que Ingress dirige la solicitud hacia `frontend-svc`.

  ```bash
  curl -s http://127.0.0.1:8080/
  ```

**Resultado esperado:**

La respuesta debe contener:

```text
FRONTEND WEB
```

- {% include step_label.html %} Realiza una segunda petición a `/api` para comprobar que la regla correspondiente dirige el tráfico hacia `backend-svc`.

  ```bash
  curl -s http://127.0.0.1:8080/api
  ```

**Resultado esperado:**

La respuesta debe contener:

```text
BACKEND API
```

- {% include step_label.html %} Regresa a la segunda terminal y presiona `Ctrl+C` para cerrar el port-forward después de completar las pruebas.

> **Concepto clave:** Ingress no reemplaza los Services. El controlador recibe la petición HTTP, evalúa las reglas y reenvía el tráfico al Service configurado como backend.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Validar la arquitectura completa

En esta tarea comprobarás que los componentes creados durante la práctica permanecen disponibles y correctamente relacionados.

### Tarea 5.1. Revisar recursos

- {% include step_label.html %} Ejecuta la consulta siguiente para obtener una vista consolidada de Deployments, Pods y Services del namespace.

  ```bash
  kubectl get all -n lab10
  ```

- {% include step_label.html %} Comprueba que el Ingress existe y utiliza la clase `nginx`.

  ```bash
  kubectl get ingress app-ingress \
    -n lab10 \
    -o wide
  ```

### Tarea 5.2. Ejecutar la validación automática

- {% include step_label.html %} Copia y ejecuta el bloque siguiente para confirmar los elementos esenciales de la arquitectura.

  ```bash
  echo "=== Verificacion final de la Practica 6 ==="

  BACKEND_READY=$(kubectl get deployment backend \
    -n lab10 \
    -o jsonpath='{.status.readyReplicas}')

  FRONTEND_READY=$(kubectl get deployment frontend \
    -n lab10 \
    -o jsonpath='{.status.readyReplicas}')

  [ "$BACKEND_READY" = "2" ] \
    && echo "✅ backend disponible: 2/2" \
    || echo "❌ backend incompleto: $BACKEND_READY/2"

  [ "$FRONTEND_READY" = "2" ] \
    && echo "✅ frontend disponible: 2/2" \
    || echo "❌ frontend incompleto: $FRONTEND_READY/2"

  BACKEND_TYPE=$(kubectl get service backend-svc \
    -n lab10 \
    -o jsonpath='{.spec.type}')

  NODEPORT_TYPE=$(kubectl get service frontend-nodeport \
    -n lab10 \
    -o jsonpath='{.spec.type}')

  [ "$BACKEND_TYPE" = "ClusterIP" ] \
    && echo "✅ backend-svc es ClusterIP" \
    || echo "❌ Tipo inesperado: $BACKEND_TYPE"

  [ "$NODEPORT_TYPE" = "NodePort" ] \
    && echo "✅ frontend-nodeport es NodePort" \
    || echo "❌ Tipo inesperado: $NODEPORT_TYPE"

  NODEPORT=$(kubectl get service frontend-nodeport \
    -n lab10 \
    -o jsonpath='{.spec.ports[0].nodePort}')

  [ "$NODEPORT" = "30080" ] \
    && echo "✅ NodePort configurado en 30080" \
    || echo "❌ NodePort inesperado: $NODEPORT"

  INGRESS_CLASS=$(kubectl get ingress app-ingress \
    -n lab10 \
    -o jsonpath='{.spec.ingressClassName}')

  [ "$INGRESS_CLASS" = "nginx" ] \
    && echo "✅ Ingress utiliza la clase nginx" \
    || echo "❌ IngressClass inesperada: $INGRESS_CLASS"

  echo ""
  echo "Services:"
  kubectl get services -n lab10

  echo ""
  echo "Ingress:"
  kubectl get ingress -n lab10

  echo "=== Fin de verificacion ==="
  ```

**Salida esperada aproximada:**

```text
=== Verificacion final de la Practica 6 ===
✅ backend disponible: 2/2
✅ frontend disponible: 2/2
✅ backend-svc es ClusterIP
✅ frontend-nodeport es NodePort
✅ NodePort configurado en 30080
✅ Ingress utiliza la clase nginx
...
=== Fin de verificacion ===
```

> **IMPORTANTE:** Conserva el namespace `lab10`, los Deployments, Services y el addon de Ingress. Las prácticas complementarias 6.1 y 6.2 reutilizarán estos recursos para diagnóstico de Services, endpoints y DNS.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🛠️ Resolución de problemas

### Problema 1. backend-svc no responde desde frontend

**Síntoma:** La petición `wget http://backend-svc` falla o queda esperando.

**Causa probable:** El Service no existe, los Pods backend no están disponibles o existe una inconsistencia entre selector y labels.

**Solución:**

```bash
kubectl get service backend-svc -n lab10
kubectl get pods -n lab10 -l app=backend --show-labels
kubectl describe service backend-svc -n lab10
```

La práctica complementaria 6.1 profundizará en el diagnóstico sistemático de endpoints.

---

### Problema 2. minikube service --url no permite acceder al NodePort

**Síntoma:** La URL no se genera, el comando permanece activo o `curl` no obtiene respuesta.

**Causa probable:** El Service no está disponible, Minikube no está activo o el túnel local del driver Docker no pudo establecerse.

**Solución:**

```bash
minikube status
kubectl get service frontend-nodeport -n lab10
kubectl get pods -n lab10 -l app=frontend
```

Vuelve a ejecutar `minikube service frontend-nodeport --namespace=lab10 --url` y utiliza exactamente la URL generada.

---

### Problema 3. El Ingress Controller no alcanza Running

**Síntoma:** El rollout del controlador termina por timeout o los Pods permanecen en `ContainerCreating` o `ImagePullBackOff`.

**Causa probable:** Las imágenes del addon todavía se están descargando, existe un problema de conectividad o Docker Desktop no dispone de recursos suficientes.

**Solución:**

```bash
kubectl get pods -n ingress-nginx
kubectl get events -n ingress-nginx \
  --sort-by='.lastTimestamp'
```

Corrige el problema indicado por los eventos y repite el rollout antes de probar el Ingress.

---

### Problema 4. Ingress devuelve 404

**Síntoma:** `curl http://127.0.0.1:8080/` o `/api` devuelve una respuesta 404 del controlador.

**Causa probable:** El recurso Ingress no fue aplicado, la clase no coincide con el controlador o el path solicitado no corresponde con las reglas definidas.

**Solución:**

```bash
kubectl get ingress app-ingress -n lab10
kubectl describe ingress app-ingress -n lab10
kubectl get ingressclass
```

Confirma que `ingressClassName` sea `nginx` y que existan las rutas `/` y `/api`.

---

### Problema 5. Ingress devuelve 503 Service Unavailable

**Síntoma:** El controlador responde, pero una ruta devuelve `503 Service Unavailable`.

**Causa probable:** El Service utilizado como backend no dispone de Pods disponibles o no tiene destinos asociados.

**Solución:**

```bash
kubectl get services -n lab10
kubectl get pods -n lab10 --show-labels
kubectl describe service backend-svc -n lab10
kubectl describe service frontend-svc -n lab10
```

No cambies los selectors hasta identificar qué relación entre Service y Pods está fallando.
