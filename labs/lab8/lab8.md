---
course_id: kubeadmin
lab_id: l008
tracking: true
position: 8
layout: lab
title: "Práctica 5: Configuración de aplicaciones con ConfigMaps, Secrets y RBAC"
permalink: /lab8/lab8/
images_base: /labs/lab8/img
duration: "75 minutos"
objective:
  - Crear ConfigMaps mediante métodos imperativos y declarativos para externalizar configuración no sensible.
  - Consumir ConfigMaps como variables de entorno y archivos montados dentro de Pods.
  - Crear y consumir Secrets de tipo Opaque y TLS comprendiendo su codificación y uso seguro.
  - Crear ServiceAccounts, Roles y RoleBindings aplicando el principio de mínimo privilegio.
  - Validar permisos de identidades Kubernetes mediante kubectl auth can-i y comprobar accesos permitidos y denegados.
prerequisites:
  - Haber completado la Práctica 4 y la Práctica complementaria 4.1.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Comprender Pods, Deployments, Services y namespaces.
  - Tener conocimientos básicos de manifiestos YAML y codificación base64.
  - Disponer de openssl y base64 desde Git Bash.
introduction:
  - En esta práctica trabajarás con tres mecanismos fundamentales para configurar y proteger aplicaciones Kubernetes. Utilizarás ConfigMaps para separar configuración no sensible del contenedor, Secrets para almacenar datos confidenciales y RBAC para controlar qué acciones puede realizar una identidad sobre la API. Crearás recursos, los consumirás desde Pods y verificarás los permisos concedidos y denegados mediante kubectl.
slug: lab8
lab_number: 8
final_result: >
  Al finalizar la práctica habrás configurado aplicaciones mediante ConfigMaps y Secrets, consumido sus valores desde Pods y construido un modelo RBAC basado en ServiceAccounts, Roles y RoleBindings, validando de forma explícita los permisos permitidos y denegados.
notes:
  - Esta práctica utiliza un namespace dedicado llamado lab5 para mantener aislados los recursos de configuración y seguridad.
  - Los valores almacenados en Secrets mediante data están codificados en base64; la codificación no equivale a cifrado.
  - Los ejemplos de credenciales utilizados son exclusivamente datos de laboratorio y no deben reutilizarse en sistemas reales.
  - La administración de ServiceAccounts se profundizará en la práctica complementaria 5.1.
  - En Git Bash, las rutas Linux usadas dentro de contenedores se ejecutan mediante `sh -c` para evitar conversión automática de rutas por MSYS2.
  - La variable APP_PORT=8080 del ConfigMap es un dato de configuración demostrativo; no cambia automáticamente el puerto 80 utilizado por NGINX.
references:
  - text: ConfigMaps
    url: https://kubernetes.io/docs/concepts/configuration/configmap/
  - text: Secrets
    url: https://kubernetes.io/docs/concepts/configuration/secret/
  - text: RBAC Authorization
    url: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
  - text: Service Accounts
    url: https://kubernetes.io/docs/concepts/security/service-accounts/
prev: /lab7/lab7/
next: /lab9/lab9/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio y namespace

En esta práctica crearás un namespace dedicado llamado `lab5` y un directorio local donde conservarás los manifiestos relacionados con ConfigMaps, Secrets y RBAC.

### 🗂️ Preparar el entorno de trabajo


{% assign tracking_task_id = "t001" %}

- {% include step_label.html id="s001" %} Abre **Docker Desktop** y confirma que el motor continúa activo antes de utilizar Minikube.

- {% include step_label.html id="s002" %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio correspondiente a este laboratorio.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab5
  cd /c/LABS/kubernetes/lab5
  ```

- {% include step_label.html id="s003" %} Verifica que Minikube se encuentra disponible y que los nodos continúan en estado `Ready`.

  ```bash
  minikube status
  kubectl get nodes
  ```

- {% include step_label.html id="s004" %} Crea el namespace `lab5` para mantener aislados todos los recursos utilizados durante esta práctica.

  ```bash
  kubectl create namespace lab5
  ```

  **Salida esperada:**

  ```text
  namespace/lab5 created
  ```

- {% include step_label.html id="s005" %} Establece temporalmente `lab5` como namespace predeterminado del contexto activo para reducir errores durante los comandos posteriores.

  ```bash
  kubectl config set-context --current --namespace=lab5
  ```

  **Salida esperada aproximada:**

  ```text
  Context "<nombre-del-contexto>" modified.
  ```

- {% include step_label.html id="s006" %} Confirma que el contexto actual utiliza `lab5` antes de comenzar con los recursos de configuración.

  ```bash
  kubectl config view --minify | grep namespace
  ```

  **Salida esperada:**

  ```text
  namespace: lab5
  ```

---

## 🧩 Tarea 1. Crear y consumir ConfigMaps

En esta tarea externalizarás configuración no sensible utilizando ConfigMaps. Crearás valores mediante comandos y YAML, y después comprobarás dos formas de consumo desde Pods.

### Tarea 1.1. Crear un ConfigMap desde literales


{% assign tracking_task_id = "t002" %}

- {% include step_label.html id="s007" %} Ejecuta el comando siguiente para crear `app-config` con tres parámetros básicos que simulan la configuración de una aplicación.

  ```bash
  kubectl create configmap app-config \
    --from-literal=LOG_LEVEL=debug \
    --from-literal=APP_PORT=8080 \
    --from-literal=APP_ENV=development
  ```

  **Salida esperada:**

  ```text
  configmap/app-config created
  ```

- {% include step_label.html id="s008" %} Comprueba las claves almacenadas y revisa sus valores para confirmar que Kubernetes registró correctamente el ConfigMap.

  ```bash
  kubectl describe configmap app-config
  ```

  **Salida esperada aproximada:**

  ```text
  Name:         app-config
  Namespace:    lab5

  Data
  ====
  APP_ENV:
  ----
  development
  APP_PORT:
  ----
  8080
  LOG_LEVEL:
  ----
  debug
  ```

### Tarea 1.2. Crear un ConfigMap declarativo

- {% include step_label.html id="s009" %} Crea el archivo `configmap-nginx.yaml` para almacenar una página HTML y una configuración mínima de NGINX.

  ```bash
  touch configmap-nginx.yaml
  ```

- {% include step_label.html id="s010" %} Abre el archivo en VS Code y agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: nginx-config
    namespace: lab5
  data:
    nginx.conf: |
      events {}
      http {
          server {
              listen 80;
              location / {
                  root /usr/share/nginx/html;
                  index index.html;
              }
              location /health {
                  return 200 'OK';
                  add_header Content-Type text/plain;
              }
          }
      }
    index.html: |
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <title>Kubernetes ConfigMap</title>
      </head>
      <body>
        <h1>Configuración desde ConfigMap</h1>
        <p>Contenido externalizado correctamente.</p>
      </body>
      </html>
  ```

- {% include step_label.html id="s011" %} Valida y aplica el manifiesto para crear el segundo ConfigMap.

  ```bash
  kubectl apply --dry-run=client -f configmap-nginx.yaml
  ```

  **Salida esperada:**

  ```text
  configmap/nginx-config created (dry run)
  ```

- {% include step_label.html id="s012" %} Aplica el manifiesto validado para crear `nginx-config` dentro del namespace `lab5`.

  ```bash
  kubectl apply -f configmap-nginx.yaml
  ```

  **Salida esperada:**

  ```text
  configmap/nginx-config created
  ```

### Tarea 1.3. Consumir variables y archivos

- {% include step_label.html id="s013" %} Crea el archivo `pods-configmap.yaml`, donde definirás dos Pods que consumirán ConfigMaps mediante mecanismos diferentes.

  ```bash
  touch pods-configmap.yaml
  ```

- {% include step_label.html id="s014" %} Agrega el contenido siguiente para inyectar `app-config` como variables de entorno y montar `nginx-config` como archivos.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: config-env-pod
    namespace: lab5
  spec:
    containers:
      - name: app
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            echo "LOG_LEVEL=$LOG_LEVEL"
            echo "APP_PORT=$APP_PORT"
            echo "APP_ENV=$APP_ENV"
            sleep 3600
        envFrom:
          - configMapRef:
              name: app-config
    restartPolicy: Never
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: config-volume-pod
    namespace: lab5
  spec:
    containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
          - containerPort: 80
        volumeMounts:
          - name: nginx-config-volume
            mountPath: /etc/nginx/nginx.conf
            subPath: nginx.conf
          - name: nginx-config-volume
            mountPath: /usr/share/nginx/html/index.html
            subPath: index.html
    volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
  ```

- {% include step_label.html id="s015" %} Aplica los Pods y espera hasta que ambos recursos estén listos antes de revisar la configuración inyectada.

  ```bash
  kubectl apply -f pods-configmap.yaml
  ```

  **Salida esperada:**

  ```text
  pod/config-env-pod created
  pod/config-volume-pod created
  ```

- {% include step_label.html id="s016" %} Espera hasta que ambos Pods estén `Ready` para evitar validar configuración mientras los contenedores todavía están iniciando.

  ```bash
  kubectl wait --for=condition=Ready pod/config-env-pod --timeout=60s
  kubectl wait --for=condition=Ready pod/config-volume-pod --timeout=90s
  ```

  **Salida esperada:**

  ```text
  pod/config-env-pod condition met
  pod/config-volume-pod condition met
  ```

- {% include step_label.html id="s017" %} Comprueba las variables de entorno cargadas en el primer Pod.

  ```bash
  kubectl exec config-env-pod -- \
    sh -c 'echo "LOG_LEVEL=$LOG_LEVEL APP_PORT=$APP_PORT APP_ENV=$APP_ENV"'
  ```

  **Salida esperada:**

  ```text
  LOG_LEVEL=debug APP_PORT=8080 APP_ENV=development
  ```

- {% include step_label.html id="s018" %} Comprueba que el segundo Pod utiliza el contenido montado desde `nginx-config`.

  ```bash
  kubectl exec config-volume-pod -- \
    sh -c 'cat /usr/share/nginx/html/index.html'
  ```

  **Salida esperada aproximada:**

  ```html
  <!DOCTYPE html>
  <html lang="es">
  ...
  <h1>Configuración desde ConfigMap</h1>
  <p>Contenido externalizado correctamente.</p>
  ...
  </html>
  ```

  > **IMPORTANTE:** En Git Bash se utiliza `sh -c` para que `/usr/share/nginx/html/index.html` sea interpretado dentro del contenedor y no sea convertido a una ruta de Windows.
  {: .lab-note .important .compact}

- {% include step_label.html id="s019" %} Verifica el endpoint `/health` directamente desde el contenedor NGINX.

  ```bash
  kubectl exec config-volume-pod -- \
    sh -c 'wget -qO- http://127.0.0.1/health'
  ```

  **Salida esperada:**

  ```text
  OK
  ```

  > **NOTA:** Los valores consumidos como variables de entorno se establecen al iniciar el contenedor. Los volúmenes de ConfigMap tienen un comportamiento diferente, aunque el uso de `subPath` evita actualizaciones automáticas del archivo montado.
  {: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🔐 Tarea 2. Crear y consumir Secrets

En esta tarea almacenarás información sensible en Secrets y comprobarás cómo Kubernetes entrega automáticamente sus valores decodificados a los contenedores.

### Tarea 2.1. Crear un Secret Opaque


{% assign tracking_task_id = "t003" %}

- {% include step_label.html id="s020" %} Ejecuta el comando siguiente para crear credenciales ficticias de base de datos en un Secret de tipo `Opaque`.

  ```bash
  kubectl create secret generic db-credentials \
    --from-literal=DB_USER=labadmin \
    --from-literal=DB_PASSWORD='Lab-S3cret-2026' \
    --from-literal=DB_HOST=postgres-service
  ```

  **Salida esperada:**

  ```text
  secret/db-credentials created
  ```

- {% include step_label.html id="s021" %} Consulta el Secret en YAML para observar que los valores del campo `data` están representados mediante base64.

  ```bash
  kubectl get secret db-credentials -o yaml
  ```

  **Salida esperada aproximada:**

  ```yaml
  apiVersion: v1
  data:
    DB_HOST: cG9zdGdyZXMtc2VydmljZQ==
    DB_PASSWORD: TGFiLVMzY3JldC0yMDI2
    DB_USER: bGFiYWRtaW4=
  kind: Secret
  type: Opaque
  ```

- {% include step_label.html id="s022" %} Extrae y decodifica únicamente `DB_USER` para comprobar la relación entre el valor original y la representación almacenada.

  ```bash
  kubectl get secret db-credentials \
    -o jsonpath='{.data.DB_USER}' \
    | base64 --decode
  echo
  ```

  **Salida esperada:**

  ```text
  labadmin
  ```

  > **IMPORTANTE:** Base64 es una codificación reversible y no proporciona cifrado. Un usuario autorizado para leer Secrets puede recuperar fácilmente sus valores originales.
  {: .lab-note .important .compact}

### Tarea 2.2. Crear un Secret TLS

- {% include step_label.html id="s023" %} Genera una clave privada y un certificado autofirmado de 30 días para demostrar la estructura requerida por un Secret `kubernetes.io/tls`.

  ```bash
  MSYS_NO_PATHCONV=1 openssl req -x509 -nodes -days 30 \
    -newkey rsa:2048 \
    -keyout tls.key \
    -out tls.crt \
    -subj "/CN=lab5.local/O=KubernetesLab"
  ```

  > **IMPORTANTE:** `MSYS_NO_PATHCONV=1` evita que Git Bash transforme `/CN=...` en una ruta de Windows como `C:/Program Files/Git/...`.
  {: .lab-note .important .compact}

- {% include step_label.html id="s024" %} Comprueba que OpenSSL generó los dos archivos antes de intentar crear el Secret TLS, evitando continuar con archivos inexistentes.

  ```bash
  ls -lh tls.crt tls.key
  ```

  **Salida esperada aproximada:**

  ```text
  -rw-r--r-- ... tls.crt
  -rw-r--r-- ... tls.key
  ```

- {% include step_label.html id="s025" %} Inspecciona el sujeto y la vigencia del certificado para confirmar que el Common Name corresponde con `lab5.local`.

  ```bash
  openssl x509 \
    -in tls.crt \
    -noout \
    -subject \
    -dates
  ```

  **Salida esperada aproximada:**

  ```text
  subject=CN=lab5.local, O=KubernetesLab
  notBefore=...
  notAfter=...
  ```

- {% include step_label.html id="s026" %} Crea `tls-certificate` utilizando el certificado y la clave privada que acabas de validar.

  ```bash
  kubectl create secret tls tls-certificate \
    --cert=tls.crt \
    --key=tls.key
  ```

  **Salida esperada:**

  ```text
  secret/tls-certificate created
  ```

- {% include step_label.html id="s027" %} Consulta únicamente el tipo del Secret para confirmar que Kubernetes lo registró como un recurso TLS y no como un Secret Opaque genérico.

  ```bash
  kubectl get secret tls-certificate \
    -o jsonpath='{.type}{"\n"}'
  ```

  **Salida esperada:**

  ```text
  kubernetes.io/tls
  ```

### Tarea 2.3. Consumir el Secret desde un Pod

- {% include step_label.html id="s028" %} Crea `pod-secret.yaml` para consumir el mismo Secret como variables de entorno y como archivo proyectado de solo lectura.

  ```bash
  touch pod-secret.yaml
  ```

- {% include step_label.html id="s029" %} Agrega el manifiesto siguiente; la proyección `items` crea explícitamente el archivo `db-user`, evitando depender del nombre automático de la clave.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: secret-demo-pod
    namespace: lab5
  spec:
    containers:
      - name: app
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            echo "DB_USER=$DB_USER"
            echo "DB_HOST=$DB_HOST"

            if [ -n "$DB_PASSWORD" ]; then
              echo "DB_PASSWORD definida correctamente"
            else
              echo "ERROR: DB_PASSWORD no fue inyectada"
            fi

            FILE_DB_USER="$(cat /etc/db-secret/db-user)"
            printf 'Archivo DB_USER=%s\n' "$FILE_DB_USER"

            sleep 3600
        envFrom:
          - secretRef:
              name: db-credentials
        volumeMounts:
          - name: db-secret-volume
            mountPath: /etc/db-secret
            readOnly: true
    volumes:
      - name: db-secret-volume
        secret:
          secretName: db-credentials
          items:
            - key: DB_USER
              path: db-user
    restartPolicy: Never
  ```

- {% include step_label.html id="s030" %} Valida el manifiesto localmente antes de crear el Pod, comprobando sintaxis y estructura sin modificar todavía el clúster.

  ```bash
  kubectl apply --dry-run=client -f pod-secret.yaml
  ```

  **Salida esperada:**

  ```text
  pod/secret-demo-pod created (dry run)
  ```

- {% include step_label.html id="s031" %} Aplica el manifiesto y espera a que el contenedor quede `Ready` antes de consultar las variables y el archivo proyectado.

  ```bash
  kubectl apply -f pod-secret.yaml
  kubectl wait \
    --for=condition=Ready \
    pod/secret-demo-pod \
    --timeout=60s
  ```

  **Salida esperada:**

  ```text
  pod/secret-demo-pod created
  pod/secret-demo-pod condition met
  ```

- {% include step_label.html id="s032" %} Revisa los logs para confirmar que las variables se inyectaron y que el archivo proyectado contiene exactamente el mismo usuario.

  ```bash
  kubectl logs secret-demo-pod
  ```

  **Salida esperada:**

  ```text
  DB_USER=labadmin
  DB_HOST=postgres-service
  DB_PASSWORD definida correctamente
  Archivo DB_USER=labadmin
  ```

- {% include step_label.html id="s033" %} Valida directamente el archivo montado para demostrar que su contenido proviene del Secret y no únicamente de la variable `DB_USER`.

  ```bash
  kubectl exec secret-demo-pod -- \
    sh -c 'printf "Contenido del archivo: "; cat /etc/db-secret/db-user; echo'
  ```

  **Salida esperada:**

  ```text
  Contenido del archivo: labadmin
  ```

  > **IMPORTANTE:** El valor correcto es `labadmin`, porque ese fue el dato creado en `DB_USER`. La práctica no utiliza `labuser`.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 👤 Tarea 3. Crear una ServiceAccount y un Role de mínimo privilegio

En esta tarea crearás una identidad de aplicación y definirás exactamente qué recursos puede consultar dentro del namespace `lab5`.

### Tarea 3.1. Crear la ServiceAccount


{% assign tracking_task_id = "t004" %}

- {% include step_label.html id="s034" %} Ejecuta el comando siguiente para crear una ServiceAccount denominada `app-reader`, que representará una identidad independiente del usuario administrador.

  ```bash
  kubectl create serviceaccount app-reader
  ```

  **Salida esperada:**

  ```text
  serviceaccount/app-reader created
  ```

- {% include step_label.html id="s035" %} Comprueba que la nueva identidad aparece junto con la ServiceAccount `default` del namespace.

  ```bash
  kubectl get serviceaccounts
  ```

  **Salida esperada aproximada:**

  ```text
  NAME         SECRETS   AGE
  app-reader   0         ...
  default      0         ...
  ```

  > **NOTA:** En versiones actuales de Kubernetes es normal que la columna `SECRETS` muestre `0`; los tokens de ServiceAccount se obtienen mediante TokenRequest y se proyectan en los Pods.
  {: .lab-note .info .compact}

### Tarea 3.2. Crear el Role

- {% include step_label.html id="s036" %} Crea el archivo `role-reader.yaml` para definir permisos de solo lectura sobre Pods, logs y ConfigMaps.

  ```bash
  touch role-reader.yaml
  ```

- {% include step_label.html id="s037" %} Agrega las reglas siguientes, excluyendo deliberadamente cualquier permiso sobre Secrets.

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: pod-configmap-reader
    namespace: lab5
  rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get"]
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch"]
  ```

- {% include step_label.html id="s038" %} Valida y aplica el Role antes de vincularlo con la ServiceAccount.

  ```bash
  kubectl apply --dry-run=client -f role-reader.yaml
  ```

  **Salida esperada:**

  ```text
  role.rbac.authorization.k8s.io/pod-configmap-reader created (dry run)
  ```

- {% include step_label.html id="s039" %} Aplica el Role después de validar su sintaxis.

  ```bash
  kubectl apply -f role-reader.yaml
  ```

  **Salida esperada:**

  ```text
  role.rbac.authorization.k8s.io/pod-configmap-reader created
  ```

### Tarea 3.3. Crear el RoleBinding

- {% include step_label.html id="s040" %} Crea `rolebinding-reader.yaml` para asignar las reglas del Role `pod-configmap-reader` a la ServiceAccount `app-reader`.

  ```bash
  touch rolebinding-reader.yaml
  ```

- {% include step_label.html id="s041" %} Agrega la relación siguiente entre la identidad y el Role.

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: app-reader-binding
    namespace: lab5
  subjects:
    - kind: ServiceAccount
      name: app-reader
      namespace: lab5
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: pod-configmap-reader
  ```

- {% include step_label.html id="s042" %} Aplica el RoleBinding y revisa su descripción para comprobar que subject y roleRef apuntan a los recursos correctos.

  ```bash
  kubectl apply -f rolebinding-reader.yaml
  ```

  **Salida esperada:**

  ```text
  rolebinding.rbac.authorization.k8s.io/app-reader-binding created
  ```

- {% include step_label.html id="s043" %} Describe el RoleBinding para verificar que `app-reader` es el subject y que `pod-configmap-reader` es el Role asignado.

  ```bash
  kubectl describe rolebinding app-reader-binding
  ```

  **Salida esperada aproximada:**

  ```text
  Name:         app-reader-binding
  Namespace:    lab5
  Role:
    Kind:  Role
    Name:  pod-configmap-reader
  Subjects:
    Kind            Name        Namespace
    ----            ----        ---------
    ServiceAccount  app-reader  lab5
  ```

  > **Concepto clave:** Un Role define permisos; un RoleBinding asigna esos permisos a una identidad. Crear únicamente el Role no concede acceso a ningún usuario o ServiceAccount.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧪 Tarea 4. Validar permisos con kubectl auth can-i

En esta tarea comprobarás explícitamente qué operaciones puede realizar `app-reader` y verificarás que los accesos no definidos permanecen denegados.

### Tarea 4.1. Validar operaciones permitidas


{% assign tracking_task_id = "t005" %}

- {% include step_label.html id="s044" %} Ejecuta las consultas siguientes impersonando la ServiceAccount para comprobar que puede leer Pods y ConfigMaps dentro de `lab5`.

  ```bash
  kubectl auth can-i get pods \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```
  ```bash
  kubectl auth can-i list pods \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```
  ```bash
  kubectl auth can-i get configmaps \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```

  **Salida esperada, en el mismo orden de ejecución:**

  ```text
  yes
  yes
  yes
  ```

### Tarea 4.2. Validar operaciones denegadas

- {% include step_label.html id="s045" %} Comprueba que la misma identidad no puede crear Pods, eliminar Pods ni consultar Secrets porque esos permisos nunca fueron incluidos en el Role.

  ```bash
  kubectl auth can-i create pods \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```
  ```bash
  kubectl auth can-i delete pods \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```
  ```bash
  kubectl auth can-i get secrets \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```

  **Salida esperada, en el mismo orden de ejecución:**

  ```text
  no
  no
  no
  ```

### Tarea 4.3. Comprobar el alcance del namespace

- {% include step_label.html id="s046" %} Ejecuta la consulta siguiente para demostrar que el Role creado en `lab5` no otorga automáticamente permisos sobre Pods de `kube-system`.

  ```bash
  kubectl auth can-i get pods \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=kube-system
  ```

  **Salida esperada:**

  ```text
  no
  ```

- {% include step_label.html id="s047" %} Utiliza `--list` para obtener una vista consolidada de las acciones que Kubernetes autoriza a la identidad dentro del namespace.

  ```bash
  kubectl auth can-i --list \
    --as=system:serviceaccount:lab5:app-reader \
    --namespace=lab5
  ```

  **Salida esperada aproximada:**

  ```text
  Resources      Non-Resource URLs   Resource Names   Verbs
  pods           []                  []               [get list watch]
  pods/log       []                  []               [get]
  configmaps     []                  []               [get list watch]
  ```

  La tabla puede incluir permisos básicos adicionales de descubrimiento de API, pero no debe conceder lectura de `secrets` ni creación o eliminación de Pods.

  > **NOTA:** El formato completo de identidad de una ServiceAccount es `system:serviceaccount:<namespace>:<nombre>`. Este formato es especialmente útil durante auditorías y ejercicios CKA.
  {: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## 🛡️ Tarea 5. Validar RBAC desde un Pod real

En esta tarea asignarás la ServiceAccount al Pod y utilizarás su identidad real para consultar la API del clúster, comprobando tanto operaciones permitidas como denegadas.

### Tarea 5.1. Crear el Pod con la ServiceAccount


{% assign tracking_task_id = "t006" %}

- {% include step_label.html id="s048" %} Crea el archivo `pod-rbac.yaml`, que utilizará una imagen con kubectl y ejecutará consultas contra la API con la identidad `app-reader`.

  ```bash
  touch pod-rbac.yaml
  ```

- {% include step_label.html id="s049" %} Agrega el manifiesto siguiente para montar automáticamente las credenciales de la ServiceAccount dentro del Pod.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: rbac-demo-pod
    namespace: lab5
  spec:
    serviceAccountName: app-reader
    containers:
      - name: kubectl
        image: bitnami/kubectl:latest
        command:
          - sh
          - -c
          - |
            echo "=== ServiceAccount ==="
            ls /var/run/secrets/kubernetes.io/serviceaccount/

            echo ""
            echo "=== Pods permitidos ==="
            kubectl get pods -n lab5

            echo ""
            echo "=== ConfigMaps permitidos ==="
            kubectl get configmaps -n lab5

            echo ""
            echo "=== Secrets denegados ==="
            kubectl get secrets -n lab5 || true

            sleep 3600
  ```

- {% include step_label.html id="s050" %} Aplica el Pod y espera hasta que esté disponible antes de consultar sus logs.

  ```bash
  kubectl apply -f pod-rbac.yaml
  ```

  **Salida esperada:**

  ```text
  pod/rbac-demo-pod created
  ```

- {% include step_label.html id="s051" %} Espera hasta que el Pod esté `Ready` antes de leer los resultados generados por kubectl dentro del contenedor.

  ```bash
  kubectl wait --for=condition=Ready pod/rbac-demo-pod --timeout=90s
  ```

  **Salida esperada:**

  ```text
  pod/rbac-demo-pod condition met
  ```

- {% include step_label.html id="s052" %} Revisa los logs y confirma que la ServiceAccount puede listar Pods y ConfigMaps, pero recibe `Forbidden` al intentar consultar Secrets.

  ```bash
  kubectl logs rbac-demo-pod
  ```

  **Salida esperada aproximada:**

  ```text
  === ServiceAccount ===
  ca.crt
  namespace
  token

  === Pods permitidos ===
  NAME                READY   STATUS    ...
  ...

  === ConfigMaps permitidos ===
  NAME               DATA   AGE
  app-config         3      ...
  nginx-config       2      ...

  === Secrets denegados ===
  Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:lab5:app-reader" cannot list resource "secrets" ...
  ```

  La línea `Forbidden` es esperada y demuestra que el Role aplica mínimo privilegio; el `|| true` evita que el contenedor termine por esa comprobación negativa.

### Tarea 5.2. Verificar la identidad asignada

- {% include step_label.html id="s053" %} Ejecuta la consulta siguiente para comprobar que el Pod utiliza realmente `app-reader` y no la ServiceAccount predeterminada.

  ```bash
  kubectl get pod rbac-demo-pod \
    -o jsonpath='{.spec.serviceAccountName}{"\n"}'
  ```

  **Salida esperada:**

  ```text
  app-reader
  ```

### Tarea 5.3. Ejecutar la validación final

- {% include step_label.html id="s054" %} Ejecuta el siguiente script para validar la configuracion.

  ```bash
  curl -sSL https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab8/scripts/validacion.sh -o validacion.sh
  chmod +x validacion.sh
  ./validacion.sh
  ```

  **Salida esperada aproximada:**

  ```text
  === Verificacion final de la Practica 5 ===
  ✅ ConfigMap app-config disponible
  ✅ Secret db-credentials disponible
  ✅ ServiceAccount app-reader disponible
  ✅ Role disponible
  ✅ RoleBinding disponible
  ✅ app-reader puede leer Pods
  ✅ app-reader no puede leer Secrets
  ✅ rbac-demo-pod usa app-reader
  === Fin de verificacion ===
  ```

  > **IMPORTANTE:** Conserva los recursos RBAC y el namespace `lab5`. La práctica complementaria siguiente reutilizará la ServiceAccount para profundizar en validación de permisos.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}