---
course_id: kubeadmin
lab_id: l001
tracking: true
position: 1
layout: lab
title: "Práctica 1: Despliegue de una aplicación Node.js en Kubernetes"
permalink: /lab1/lab1/
images_base: /labs/lab1/img
duration: "60 minutos"
objective:
  - Preparar una aplicación web Node.js sencilla y comprobar su funcionamiento local antes de contenerizarla.
  - Construir una imagen Docker de la aplicación y cargarla en el clúster local de Minikube.
  - Crear un Deployment mediante un manifiesto YAML para ejecutar la aplicación como un Pod administrado por Kubernetes.
  - Crear un Service de tipo NodePort para exponer la aplicación y acceder a ella desde el navegador.
  - Validar los recursos desplegados mediante kubectl y relacionar Pod, Deployment y Service dentro del flujo básico de Kubernetes.
prerequisites:
  - Tener Docker Desktop instalado y en ejecución.
  - Tener Minikube instalado y disponible desde la terminal.
  - Tener kubectl instalado y configurado.
  - Tener Visual Studio Code instalado.
  - Tener Git Bash instalado en Windows y configurado como terminal integrada de Visual Studio Code.
  - Tener un navegador web moderno como Chrome, Edge o Firefox.
  - Conocer los fundamentos básicos de Docker, contenedores y archivos YAML.
introduction:
  - En esta práctica desplegarás una aplicación web Node.js en un clúster local de Kubernetes con Minikube. Primero crearás y validarás una página sencilla, después construirás su imagen Docker y la cargarás en Minikube. Finalmente definirás un Deployment y un Service NodePort mediante manifiestos YAML, comprobarás el estado de los recursos con kubectl y accederás a la aplicación desde el navegador. El objetivo es recorrer de principio a fin el flujo básico código → imagen → Deployment → Pod → Service → aplicación.
slug: lab1
lab_number: 1
final_result: >
  Al finalizar la práctica tendrás una aplicación web Node.js empaquetada como imagen Docker y desplegada en Kubernetes mediante un Deployment. La aplicación estará expuesta mediante un Service NodePort, será accesible desde el navegador y podrás identificar con kubectl la relación entre Deployment, ReplicaSet, Pod y Service.
notes:
  - En Windows, ejecuta todos los comandos desde la terminal integrada de Visual Studio Code seleccionando el perfil Git Bash.
  - Esta práctica utiliza un clúster Minikube de un nodo para concentrarse en el flujo fundamental de despliegue. Los escenarios multinodo se trabajarán posteriormente.
  - No elimines el clúster ni los recursos al finalizar. La práctica complementaria 1.1 reutilizará este entorno para validar kubectl y los manifiestos YAML.
  - La imagen se construirá con Docker Desktop y se cargará explícitamente en Minikube mediante minikube image load para evitar depender de un registro externo.
references:
  - text: Deployments
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: kubectl
    url: https://kubernetes.io/docs/reference/kubectl/
  - text: Minikube
    url: https://minikube.sigs.k8s.io/docs/
prev: /
next: /lab2/lab2/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio de trabajo

En esta preparación crearás el directorio raíz del curso y el subdirectorio de la práctica 1. Esta estructura se conservará durante las prácticas siguientes para mantener separados el código, las imágenes y los manifiestos de cada laboratorio.

### 🗂️ Crear el directorio raíz y el subdirectorio de la práctica


{% assign tracking_task_id = "t001" %}

- {% include step_label.html id="s001" %} Abre **Docker Desktop** y espera a que el motor indique que está activo, porque Minikube utilizará Docker para ejecutar el nodo local del clúster.

- {% include step_label.html id="s002" %} Abre **Visual Studio Code** y espera a que cargue completamente, ya que desde su terminal integrada crearás los archivos y administrarás Kubernetes.

- {% include step_label.html id="s003" %} En VS Code, selecciona **Terminal → New Terminal** para abrir una consola integrada desde la cual ejecutarás todos los comandos requeridos.

- {% include step_label.html id="s004" %} En la flecha desplegable situada junto al botón **+** del panel Terminal, selecciona **Git Bash** para trabajar con la sintaxis Bash utilizada en esta práctica.

- {% include step_label.html id="s005" %} Ejecuta el comando siguiente para crear el directorio raíz del curso y el subdirectorio `lab1`, manteniendo los laboratorios organizados en una sola ubicación.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab1
  ```

- {% include step_label.html id="s006" %} Ejecuta el comando siguiente para abrir `C:\LABS\kubernetes` como carpeta de trabajo en VS Code y visualizar desde el Explorador los archivos del curso.

  ```bash
  code /c/LABS/kubernetes
  ```

- {% include step_label.html id="s007" %} Si VS Code solicita confirmar la confianza de la carpeta, acepta la acción para habilitar la terminal integrada, el Explorador y la edición de archivos.

- {% include step_label.html id="s008" %} En el Explorador de VS Code, confirma que aparezcan el directorio raíz `kubernetes` y el subdirectorio `lab1`, donde trabajarás durante esta práctica.

  ```text
  C:\LABS\kubernetes
  └── lab1
  ```

- {% include step_label.html id="s009" %} Ejecuta el siguiente comando para cambiar la ubicación activa de Git Bash al directorio `lab1` y evitar crear archivos en una ruta incorrecta.

  ```bash
  cd /c/LABS/kubernetes/lab1
  ```

- {% include step_label.html id="s010" %} Ejecuta `pwd` para comprobar la ruta actual y confirma que la terminal se encuentre exactamente en `/c/LABS/kubernetes/lab1` antes de continuar.

  ```bash
  pwd
  ```

  **Salida esperada:**

  Comprueba la salida obtenida y confirma que Git Bash se encuentra en el directorio destinado a la primera práctica.

  ```text
  /c/LABS/kubernetes/lab1
  ```

  > **IMPORTANTE:** En las prácticas siguientes conservarás `C:\LABS\kubernetes` y crearás únicamente el subdirectorio correspondiente a cada nuevo laboratorio.
  {: .lab-note .important .compact}

---

## 🌐 Tarea 1. Crear y validar la aplicación Node.js

En esta tarea crearás una aplicación web sencilla con Node.js. La página mostrará información básica de la instancia que responde, permitiendo comprobar después que la aplicación realmente se está ejecutando dentro de un Pod de Kubernetes.

### Tarea 1.1. Crear la estructura del proyecto


{% assign tracking_task_id = "t002" %}

- {% include step_label.html id="s011" %} Ejecuta el bloque siguiente para crear las carpetas `app` y `k8s`; la primera contendrá la aplicación y la segunda almacenará los manifiestos de Kubernetes.

  ```bash
  mkdir -p app k8s
  touch app/package.json app/server.js app/index.html
  touch Dockerfile .dockerignore
  touch k8s/deployment.yaml k8s/service.yaml
  ```

- {% include step_label.html id="s012" %} Ejecuta el comando siguiente para comprobar que los archivos fueron creados en las rutas esperadas antes de agregar código o configuración.

  ```bash
  find . -maxdepth 2 -type f | sort
  ```

  **Salida esperada:**

  Comprueba que la estructura general corresponda con la referencia siguiente antes de continuar con la implementación.

  ```text
  ./.dockerignore
  ./Dockerfile
  ./app/index.html
  ./app/package.json
  ./app/server.js
  ./k8s/deployment.yaml
  ./k8s/service.yaml
  ```

### Tarea 1.2. Crear la aplicación web

- {% include step_label.html id="s013" %} Abre `app/package.json` desde el Explorador de VS Code y agrega la definición mínima del proyecto para iniciar el servidor mediante `npm start`.

  ```json
  {
    "name": "k8s-node-web",
    "version": "1.0.0",
    "description": "Aplicación Node.js para laboratorio de Kubernetes",
    "main": "server.js",
    "scripts": {
      "start": "node server.js"
    },
    "engines": {
      "node": ">=24"
    }
  }
  ```

- {% include step_label.html id="s014" %} Abre `app/server.js` y agrega el servidor HTTP que entregará la página principal y un endpoint `/health` utilizado para validar el estado de la aplicación.

  ```javascript
  const http = require('http');
  const fs = require('fs');
  const path = require('path');
  const os = require('os');

  const PORT = process.env.PORT || 3000;
  const htmlPath = path.join(__dirname, 'index.html');

  const server = http.createServer((req, res) => {
    if (req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({
        status: 'ok',
        pod: os.hostname()
      }));
    }

    if (req.url === '/') {
      const html = fs.readFileSync(htmlPath, 'utf8')
        .replace('{{POD_NAME}}', os.hostname());

      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(html);
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Recurso no encontrado');
  });

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Aplicación disponible en el puerto ${PORT}`);
    console.log(`Hostname: ${os.hostname()}`);
  });
  ```

- {% include step_label.html id="s015" %} Abre `app/index.html` y agrega la interfaz visual que permitirá reconocer la aplicación desplegada y observar el hostname de la instancia que responde.

  ```html
  <!DOCTYPE html>
  <html lang="es">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Node.js Lab</title>
    <style>
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: Arial, Helvetica, sans-serif;
        background: #f4f7fb;
        color: #172033;
      }
      .card {
        width: min(680px, 90%);
        padding: 36px;
        background: white;
        border: 1px solid #dfe6ef;
        border-radius: 16px;
        box-shadow: 0 12px 30px rgba(23, 32, 51, .08);
      }
      .badge {
        display: inline-block;
        padding: 6px 10px;
        border-radius: 999px;
        background: #eef3ff;
        font-size: 14px;
        font-weight: 700;
      }
      h1 { margin-bottom: 10px; }
      p { line-height: 1.6; }
      code {
        display: inline-block;
        padding: 4px 7px;
        background: #f2f4f7;
        border-radius: 6px;
      }
      .status {
        margin-top: 24px;
        padding: 16px;
        border-left: 4px solid #326ce5;
        background: #f7f9fc;
      }
    </style>
  </head>
  <body>
    <main class="card">
      <span class="badge">Kubernetes Lab 1</span>
      <h1>Aplicación Node.js desplegada correctamente</h1>
      <p>
        Esta página se entrega desde una aplicación Node.js empaquetada
        como contenedor y administrada por Kubernetes.
      </p>

      <div class="status">
        <strong>Instancia que respondió:</strong><br>
        <code>{{POD_NAME}}</code>
      </div>
    </main>
  </body>
  </html> 
  ```

### Tarea 1.3. Probar la aplicación localmente

- {% include step_label.html id="s016" %} Ejecuta el servidor directamente con Node.js para comprobar primero que el código funciona correctamente antes de introducir Docker y Kubernetes en el flujo.

  ```bash
  cd app
  npm start
  ```

  **Salida esperada:**

  Comprueba que Node.js confirme el puerto utilizado y que el proceso permanezca activo esperando solicitudes HTTP.

  ```text
  Aplicación disponible en el puerto 3000
  Hostname: <nombre_del_equipo>
  ```

- {% include step_label.html id="s017" %} Abre un navegador y visita `http://localhost:3000` para confirmar que la página se renderiza correctamente antes de empaquetar la aplicación.

  ```text
  http://localhost:3000
  ```

- {% include step_label.html id="s018" %} Abre otra pestaña con `http://localhost:3000/health` para validar que el endpoint de comprobación devuelve un documento JSON con estado `ok`.

  ```text
  http://localhost:3000/health
  ```

  **Salida esperada aproximada:**

  ```json
  {
    "status": "ok",
    "pod": "<nombre_del_equipo>"
  }
  ```

- {% include step_label.html id="s019" %} Regresa a la terminal, presiona `Ctrl+C` para detener Node.js y vuelve al directorio raíz `lab1` antes de comenzar la construcción de la imagen.

  ```bash
  cd ..
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🐳 Tarea 2. Construir la imagen Docker y preparar Minikube

En esta tarea empaquetarás la aplicación como una imagen Docker y la cargarás explícitamente en Minikube. De esta forma Kubernetes podrá utilizar una imagen local sin depender de Docker Hub ni de otro registro externo.

### Tarea 2.1. Crear los archivos de construcción


{% assign tracking_task_id = "t003" %}

- {% include step_label.html id="s020" %} Abre `.dockerignore` y agrega las exclusiones siguientes para impedir que archivos innecesarios del host formen parte del contexto utilizado por Docker.

  ```gitignore
  .git
  .gitignore
  k8s
  node_modules
  npm-debug.log
  *.md
  ```

- {% include step_label.html id="s021" %} Abre `Dockerfile` y agrega la configuración siguiente para construir una imagen ligera basada en Node.js 24 LTS y ejecutar el proceso como usuario no root.

  ```dockerfile
  FROM node:24-alpine

  WORKDIR /app

  COPY app/package.json ./
  COPY app/server.js ./
  COPY app/index.html ./

  ENV PORT=3000

  EXPOSE 3000

  USER node

  CMD ["node", "server.js"]
  ```

### Tarea 2.2. Construir y probar la imagen

- {% include step_label.html id="s022" %} Ejecuta `docker build` desde la raíz de `lab1` para crear la imagen `k8s-node-web:1.0`, utilizando los archivos preparados en la tarea anterior.

  ```bash
  docker build -t k8s-node-web:1.0 .
  ```

- {% include step_label.html id="s023" %} Ejecuta el comando siguiente para comprobar que Docker registró la imagen con el repositorio y la etiqueta esperados antes de cargarla en Minikube.

  ```bash
  docker images k8s-node-web:1.0
  ```

- {% include step_label.html id="s024" %} Ejecuta temporalmente el contenedor en el puerto 3000 para validar que la imagen funciona de manera independiente antes de desplegarla en Kubernetes.

  ```bash
  docker run --rm -d \
    --name k8s-node-web-test \
    -p 3000:3000 \
    k8s-node-web:1.0
  ```

- {% include step_label.html id="s025" %} Ejecuta `curl` contra el endpoint `/health` para confirmar que el contenedor responde con HTTP 200 y que Node.js inició correctamente dentro de la imagen.

  ```bash
  curl http://localhost:3000/health
  ```

  **Salida esperada aproximada:**

  ```json
  {"status":"ok","pod":"<id_del_contenedor>"}
  ```

- {% include step_label.html id="s026" %} Detén el contenedor temporal para liberar el puerto 3000 y conservar únicamente la imagen que será utilizada posteriormente por Kubernetes.

  ```bash
  docker stop k8s-node-web-test
  ```

### Tarea 2.3. Iniciar Minikube y cargar la imagen

- {% include step_label.html id="s027" %} Ejecuta el comando siguiente para iniciar un clúster Minikube local con driver Docker y un nodo, suficiente para trabajar el flujo fundamental de esta práctica.

  ```bash
  minikube start --driver=docker
  ```

- {% include step_label.html id="s028" %} Ejecuta `kubectl get nodes` para confirmar que el nodo de Minikube alcanzó el estado `Ready` antes de intentar crear cualquier workload de la aplicación.

  ```bash
  kubectl get nodes
  ```

  **Salida esperada aproximada:**

  ```text
  NAME       STATUS   ROLES           AGE   VERSION
  minikube   Ready    control-plane   ...   ...
  ```

- {% include step_label.html id="s029" %} Ejecuta `minikube image load` para copiar la imagen construida con Docker Desktop al almacenamiento de imágenes disponible para el nodo local de Minikube.

  ```bash
  minikube image load k8s-node-web:1.0
  ```

- {% include step_label.html id="s030" %} Ejecuta el comando siguiente para confirmar desde Minikube que la imagen local se encuentra disponible antes de crear el Deployment.

  ```bash
  minikube image ls | grep k8s-node-web
  ```

  **Salida esperada aproximada:**

  ```text
  docker.io/library/k8s-node-web:1.0
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## ☸️ Tarea 3. Crear y desplegar la aplicación con un Deployment

En esta tarea definirás el estado deseado de la aplicación mediante un manifiesto YAML. Kubernetes utilizará el Deployment para crear y mantener el Pod necesario sin administrar directamente el contenedor.

### Tarea 3.1. Crear el manifiesto deployment.yaml


{% assign tracking_task_id = "t004" %}

- {% include step_label.html id="s031" %} Abre `k8s/deployment.yaml` y agrega el manifiesto siguiente para declarar un Deployment con una réplica de la aplicación Node.js preparada previamente.

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: node-web-deployment
    labels:
      app: node-web
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: node-web
    template:
      metadata:
        labels:
          app: node-web
      spec:
        containers:
          - name: node-web
            image: k8s-node-web:1.0
            imagePullPolicy: Never
            ports:
              - containerPort: 3000
                protocol: TCP
  ```

  > **NOTA:** Se utiliza `imagePullPolicy: Never` porque la imagen fue cargada manualmente en Minikube. En un entorno productivo normalmente se utilizaría una imagen almacenada en un registry accesible para los nodos.
  {: .lab-note .info .compact}

### Tarea 3.2. Validar el manifiesto antes de aplicarlo

- {% include step_label.html id="s032" %} Ejecuta una validación local con `--dry-run=client` para comprobar la estructura del manifiesto sin crear todavía ningún recurso dentro del clúster.

  ```bash
  kubectl apply \
    --dry-run=client \
    -f k8s/deployment.yaml
  ```

  **Salida esperada:**

  ```text
  deployment.apps/node-web-deployment created (dry run)
  ```

- {% include step_label.html id="s033" %} Ejecuta el comando siguiente para mostrar el manifiesto interpretado por kubectl y detectar errores básicos de indentación, nombres o estructura antes del despliegue.

  ```bash
  kubectl apply \
    --dry-run=client \
    -f k8s/deployment.yaml \
    -o yaml
  ```

### Tarea 3.3. Aplicar el Deployment y observar los recursos

- {% include step_label.html id="s034" %} Ejecuta `kubectl apply` para enviar la declaración al API Server y permitir que Kubernetes cree los recursos requeridos para alcanzar el estado deseado.

  ```bash
  kubectl apply -f k8s/deployment.yaml
  ```

- {% include step_label.html id="s035" %} Ejecuta `kubectl rollout status` para esperar hasta que el Deployment confirme que la réplica solicitada se encuentra creada y disponible correctamente.

  ```bash
  kubectl rollout status deployment/node-web-deployment
  ```

  **Salida esperada:**

  ```text
  deployment "node-web-deployment" successfully rolled out
  ```

- {% include step_label.html id="s036" %} Ejecuta los comandos siguientes para observar el Deployment, el ReplicaSet creado automáticamente y el Pod que ejecuta la aplicación dentro del clúster.

  ```bash
  kubectl get deployments
  kubectl get replicasets
  kubectl get pods -l app=node-web -o wide
  ```

  **Resultado esperado:**

  El Deployment debe mostrar `1/1` disponible y el Pod asociado debe encontrarse en estado `Running` con `READY 1/1`.

- {% include step_label.html id="s037" %} Ejecuta `kubectl describe` sobre el Deployment para revisar selector, estrategia, plantilla del Pod y eventos registrados durante la creación del workload.

  ```bash
  kubectl describe deployment node-web-deployment
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🔗 Tarea 4. Exponer la aplicación mediante un Service NodePort

En esta tarea crearás un Service que proporcione un punto estable de acceso hacia el Pod. La relación se realizará mediante la etiqueta `app: node-web`, introduciendo el funcionamiento básico de selectors sin profundizar todavía en su administración.

### Tarea 4.1. Crear el manifiesto service.yaml


{% assign tracking_task_id = "t005" %}

- {% include step_label.html id="s038" %} Abre `k8s/service.yaml` y agrega el manifiesto siguiente para crear un Service NodePort que dirija las solicitudes recibidas hacia el puerto 3000 del Pod.

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: node-web-service
    labels:
      app: node-web
  spec:
    type: NodePort
    selector:
      app: node-web
    ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 3000
  ```

  > **NOTA:** Kubernetes asignará automáticamente el `nodePort`. No se fija manualmente para evitar conflictos con puertos utilizados por otros laboratorios.
  {: .lab-note .info .compact}

### Tarea 4.2. Validar y aplicar el Service

- {% include step_label.html id="s039" %} Ejecuta la validación local del archivo `service.yaml` para comprobar que kubectl reconoce correctamente la definición antes de enviarla al API Server.

  ```bash
  kubectl apply \
    --dry-run=client \
    -f k8s/service.yaml
  ```

  **Salida esperada:**

  ```text
  service/node-web-service created (dry run)
  ```

- {% include step_label.html id="s040" %} Ejecuta `kubectl apply` para crear el Service y establecer un punto de acceso estable hacia los Pods identificados mediante la etiqueta `app=node-web`.

  ```bash
  kubectl apply -f k8s/service.yaml
  ```

- {% include step_label.html id="s041" %} Ejecuta el comando siguiente para comprobar el tipo del Service, su ClusterIP y el puerto NodePort asignado automáticamente por Kubernetes.

  ```bash
  kubectl get service node-web-service
  ```

  **Salida esperada aproximada:**

  ```text
  NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
  node-web-service   NodePort   10.96.xxx.xxx   <none>        80:3xxxx/TCP   ...
  ```

### Tarea 4.3. Acceder a la aplicación desde el navegador

- {% include step_label.html id="s042" %} Ejecuta `minikube service` con la opción `--url` para obtener una dirección accesible desde el host sin depender de la topología interna utilizada por Minikube.

  ```bash
  minikube service node-web-service --url
  ```

  **Salida esperada aproximada:**

  ```text
  http://127.0.0.1:<puerto_asignado>
  ```

- {% include step_label.html id="s043" %} Mantén activa la terminal si Minikube crea un túnel temporal y copia exactamente la URL mostrada para utilizarla durante las pruebas de navegador.

  > **NOTA:** Con el driver Docker en Windows, el proceso puede permanecer activo mientras mantiene el túnel. Utiliza otra terminal de VS Code para continuar con las validaciones.
  {: .lab-note .info .compact}

- {% include step_label.html id="s044" %} Abre la URL obtenida en Chrome, Edge o Firefox y confirma que aparezca la página **Aplicación Node.js desplegada correctamente**.

- {% include step_label.html id="s045" %} Observa el valor mostrado en **Instancia que respondió** y comprueba que ahora corresponde al nombre del Pod, no al nombre del equipo Windows.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Validar el flujo completo del despliegue

En esta tarea reunirás las comprobaciones esenciales del laboratorio para relacionar los recursos creados y verificar que Deployment, Pod y Service se encuentran operativos antes de continuar con la práctica complementaria.

### Tarea 5.1. Revisar todos los recursos de la aplicación


{% assign tracking_task_id = "t006" %}

- {% include step_label.html id="s046" %} Ejecuta el comando siguiente para listar en una sola vista los recursos asociados con `app=node-web` y comprobar que Kubernetes mantiene el estado esperado.

  ```bash
  kubectl get all -l app=node-web
  ```

  **Salida esperada aproximada:**

  ```text
  NAME                                      READY   STATUS    RESTARTS   AGE
  pod/node-web-deployment-xxxxxxxxxx-xxxxx  1/1     Running   0          ...

  NAME                       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
  service/node-web-service   NodePort   10.96.xxx.xxx   <none>        80:3xxxx/TCP   ...

  NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
  deployment.apps/node-web-deployment   1/1     1            1           ...

  NAME                                             DESIRED   CURRENT   READY   AGE
  replicaset.apps/node-web-deployment-xxxxxxxxxx   1         1         1       ...
  ```

### Tarea 5.2. Validar la relación entre Service y Pod

- {% include step_label.html id="s047" %} Ejecuta el comando siguiente para comprobar los endpoints asociados con el Service y verificar que existe una dirección interna apuntando al puerto 3000 del Pod.

  ```bash
  kubectl get endpoints node-web-service
  ```

  **Salida esperada aproximada:**

  ```text
  NAME               ENDPOINTS           AGE
  node-web-service   10.244.x.x:3000     ...
  ```

  > **NOTA:** En versiones recientes de Kubernetes puedes observar una advertencia indicando que el recurso `Endpoints` está deprecado. Para esta primera práctica se usa solo como comprobación sencilla; más adelante se trabajará con los recursos actuales de descubrimiento de endpoints.
  {: .lab-note .info .compact}

### Tarea 5.3. Consultar los logs de la aplicación

- {% include step_label.html id="s048" %} Ejecuta el comando siguiente para recuperar los logs del contenedor administrado por el Deployment y confirmar que Node.js inició correctamente dentro del Pod.

  ```bash
  kubectl logs deployment/node-web-deployment
  ```

  **Salida esperada aproximada:**

  ```text
  Aplicación disponible en el puerto 3000
  Hostname: node-web-deployment-xxxxxxxxxx-xxxxx
  ```

### Tarea 5.4. Ejecutar la verificación final

- {% include step_label.html id="s049" %} Ejecuta el siguiente script para validar la configuracion.

  ```bash
  curl -sSL https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab1/scripts/validacion.sh -o validacion.sh
  chmod +x validacion.sh
  ./validacion.sh
  ```


  **Salida esperada:**

  ```text
  === Verificación final de la Práctica 1 ===
  ✅ Nodo Minikube en estado Ready
  ✅ Deployment disponible con 1 réplica
  ✅ Pod en estado Running
  ✅ Service NodePort creado
  ✅ Service asociado con al menos un endpoint
  === Fin de verificación ===
  ```

  > **IMPORTANTE:** No elimines el Deployment, el Service, la imagen ni el clúster Minikube. La **Práctica complementaria 1.1** utilizará estos recursos para trabajar validaciones con `kubectl` y manifiestos YAML.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}