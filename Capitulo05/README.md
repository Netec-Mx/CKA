---LAB_START---
LAB_ID: 05-00-01
---MARKDOWN---
# Configuración de aplicaciones con ConfigMaps, Secrets y RBAC

## Metadatos

| Campo        | Valor                          |
|--------------|--------------------------------|
| **Duración** | 84 minutos                     |
| **Complejidad** | Alta                        |
| **Nivel Bloom** | Crear (Create)              |
| **Módulo**   | 5 — Configuración y Seguridad  |
| **Versión**  | 1.0                            |

---

## Descripción General

Este laboratorio integral cubre tres pilares fundamentales de la configuración y seguridad en Kubernetes: ConfigMaps para externalizar configuración no sensible, Secrets para gestionar datos confidenciales, y RBAC para controlar el acceso a la API del clúster. Trabajarás de forma progresiva desde la creación de recursos básicos hasta la implementación de un modelo de seguridad completo con ServiceAccounts, Roles y RoleBindings. Al finalizar, habrás construido y verificado un sistema de configuración y control de acceso que refleja las prácticas reales de entornos productivos y los patrones evaluados en el examen CKA.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Crear y consumir ConfigMaps en Pods mediante variables de entorno (`envFrom`, `env valueFrom`) y volúmenes montados (`volumeMounts`), seleccionando el método apropiado según el caso de uso
- [ ] Crear y gestionar Secrets de tipo `Opaque`, `docker-registry` y `tls`, comprendiendo la codificación base64 y sus implicaciones de seguridad al consumirlos en Pods
- [ ] Definir ServiceAccounts y configurar políticas RBAC completas (Roles, ClusterRoles, RoleBindings, ClusterRoleBindings) para controlar el acceso granular a la API de Kubernetes, verificando los permisos con `kubectl auth can-i`

---

## Prerrequisitos

### Conocimiento previo
- Haber completado los laboratorios del Módulo 4 (Namespaces)
- Comprensión sólida de Pods, Deployments y Namespaces
- Conocimiento básico de codificación base64: `echo -n 'valor' | base64`
- Familiaridad con manifiestos YAML y `kubectl apply`

### Acceso y herramientas
- Clúster Minikube operativo con `kubectl` configurado y apuntando al contexto correcto
- Terminal con acceso a `bash`, `base64`, `curl` y `openssl`
- Permisos de administrador sobre el clúster (contexto `minikube`)

---

## Entorno de Laboratorio

### Requisitos de hardware

| Recurso    | Mínimo       | Recomendado  |
|------------|--------------|--------------|
| CPU        | 4 núcleos    | 8 núcleos    |
| RAM        | 8 GB         | 16 GB        |
| Disco      | 40 GB libres | 60 GB libres |

### Software requerido

| Herramienta  | Versión mínima | Propósito                        |
|--------------|----------------|----------------------------------|
| Minikube     | 1.31.x         | Clúster local multi-nodo         |
| kubectl      | 1.28.x         | Interacción con la API           |
| Docker       | 24.x           | Driver de Minikube               |
| openssl      | 1.1.x          | Generación de certificados TLS   |
| base64       | GNU coreutils  | Codificación/decodificación      |

### Preparación del entorno

Verifica que el clúster esté operativo antes de comenzar:

```bash
# Verificar estado del clúster
minikube status

# Si el clúster no está iniciado, arrancarlo con 3 nodos
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que kubectl apunta al contexto correcto
kubectl config current-context

# Verificar que los nodos están Ready
kubectl get nodes
```

**Salida esperada de `kubectl get nodes`:**
```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

### Crear el namespace de trabajo

Todos los recursos de este laboratorio se crearán en un namespace dedicado para mantener el entorno organizado:

```bash
# Crear namespace para el laboratorio
kubectl create namespace lab05

# Establecer lab05 como namespace por defecto para esta sesión
kubectl config set-context --current --namespace=lab05

# Verificar
kubectl config view --minify | grep namespace
```

---

## Pasos del Laboratorio

---

### Parte 1: ConfigMaps (Tiempo estimado: 25 minutos)

---

#### Paso 1.1 — Crear ConfigMaps mediante métodos imperativos

**Objetivo:** Familiarizarse con los tres métodos de creación imperativa de ConfigMaps y verificar su contenido almacenado en el clúster.

**Instrucciones:**

1. Crea un ConfigMap directamente desde literales clave-valor:

```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=debug \
  --from-literal=APP_PORT=8080 \
  --from-literal=APP_ENV=development \
  --namespace=lab05
```

2. Crea un archivo de propiedades local para simular configuración de aplicación:

```bash
cat <<EOF > /tmp/app.properties
servidor.host=backend-service
servidor.timeout=30
servidor.max_conexiones=100
feature.nueva_ui=true
feature.dark_mode=false
EOF
```

3. Crea un segundo ConfigMap desde el archivo:

```bash
kubectl create configmap app-properties \
  --from-file=/tmp/app.properties \
  --namespace=lab05
```

4. Inspecciona ambos ConfigMaps:

```bash
# Listar todos los ConfigMaps en el namespace
kubectl get configmaps -n lab05

# Ver el contenido detallado del primero
kubectl describe configmap app-config -n lab05

# Ver el YAML completo del segundo
kubectl get configmap app-properties -n lab05 -o yaml
```

**Salida esperada de `kubectl get configmaps -n lab05`:**
```
NAME              DATA   AGE
app-config        3      Xs
app-properties    1      Xs
```

**Verificación:**
```bash
# Confirmar que las claves existen correctamente
kubectl get configmap app-config -n lab05 -o jsonpath='{.data.LOG_LEVEL}'
# Debe imprimir: debug

kubectl get configmap app-properties -n lab05 -o jsonpath='{.data.app\.properties}' | head -3
# Debe imprimir las primeras líneas del archivo
```

---

#### Paso 1.2 — Crear un ConfigMap declarativo con YAML

**Objetivo:** Definir un ConfigMap completo mediante manifiesto YAML que incluya tanto variables simples como un bloque de configuración multilínea.

**Instrucciones:**

1. Crea el manifiesto YAML:

```bash
cat <<'EOF' > /tmp/configmap-nginx.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: lab05
  labels:
    app: webserver
    environment: lab
data:
  # Variables de entorno simples
  WORKER_PROCESSES: "4"
  WORKER_CONNECTIONS: "1024"
  # Archivo de configuración completo de Nginx
  nginx.conf: |
    worker_processes 4;
    events {
        worker_connections 1024;
    }
    http {
        server {
            listen 80;
            server_name localhost;
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
  # Página HTML personalizada
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Lab 05 - ConfigMap Demo</title></head>
    <body>
      <h1>Configuración desde ConfigMap</h1>
      <p>Esta página fue servida con configuración externalizada.</p>
    </body>
    </html>
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f /tmp/configmap-nginx.yaml
```

3. Verifica el resultado:

```bash
kubectl get configmap nginx-config -n lab05 -o yaml
```

**Salida esperada (fragmento):**
```yaml
apiVersion: v1
data:
  WORKER_CONNECTIONS: "1024"
  WORKER_PROCESSES: "4"
  index.html: |
    <!DOCTYPE html>
    ...
  nginx.conf: |
    worker_processes 4;
    ...
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: lab05
```

**Verificación:**
```bash
# Contar las claves del ConfigMap
kubectl get configmap nginx-config -n lab05 -o jsonpath='{.data}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Claves: {list(d.keys())}')"
# Debe mostrar las 4 claves: WORKER_CONNECTIONS, WORKER_PROCESSES, index.html, nginx.conf
```

---

#### Paso 1.3 — Consumir ConfigMap como variables de entorno

**Objetivo:** Desplegar un Pod que consuma el ConfigMap `app-config` mediante `envFrom` (todas las claves) y `env.valueFrom` (clave individual), y verificar que los valores están disponibles dentro del contenedor.

**Instrucciones:**

1. Crea el manifiesto del Pod:

```bash
cat <<'EOF' > /tmp/pod-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-env
  namespace: lab05
  labels:
    app: demo-env
spec:
  containers:
    - name: app
      image: busybox:latest
      command:
        - "sh"
        - "-c"
        - |
          echo "=== Variables desde envFrom ==="
          echo "LOG_LEVEL=$LOG_LEVEL"
          echo "APP_PORT=$APP_PORT"
          echo "APP_ENV=$APP_ENV"
          echo ""
          echo "=== Variable individual ==="
          echo "NIVEL_LOG=$NIVEL_LOG"
          echo ""
          echo "=== Todas las variables de entorno ==="
          env | sort
          sleep 3600
      # Inyectar TODAS las claves del ConfigMap como variables de entorno
      envFrom:
        - configMapRef:
            name: app-config
      env:
        # Inyectar una clave específica con nombre personalizado
        - name: NIVEL_LOG
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
  restartPolicy: Never
EOF
```

2. Aplica y espera a que el Pod esté en ejecución:

```bash
kubectl apply -f /tmp/pod-env.yaml

# Esperar a que el Pod esté Running
kubectl wait --for=condition=Ready pod/app-pod-env -n lab05 --timeout=60s
```

3. Verifica los logs del Pod:

```bash
kubectl logs app-pod-env -n lab05
```

**Salida esperada:**
```
=== Variables desde envFrom ===
LOG_LEVEL=debug
APP_PORT=8080
APP_ENV=development

=== Variable individual ===
NIVEL_LOG=debug

=== Todas las variables de entorno ===
APP_ENV=development
APP_PORT=8080
LOG_LEVEL=debug
NIVEL_LOG=debug
...
```

**Verificación:**
```bash
# Ejecutar comando directo en el contenedor para verificar variables
kubectl exec app-pod-env -n lab05 -- sh -c 'echo "LOG_LEVEL=$LOG_LEVEL, APP_PORT=$APP_PORT"'
# Debe imprimir: LOG_LEVEL=debug, APP_PORT=8080
```

---

#### Paso 1.4 — Consumir ConfigMap como volumen montado

**Objetivo:** Desplegar un Pod Nginx que monte el ConfigMap `nginx-config` como volumen, haciendo que cada clave del ConfigMap se convierta en un archivo dentro del contenedor.

**Instrucciones:**

1. Crea el manifiesto del Pod:

```bash
cat <<'EOF' > /tmp/pod-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-vol
  namespace: lab05
  labels:
    app: demo-vol
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
      volumeMounts:
        # Montar nginx.conf en su ubicación estándar
        - name: nginx-conf-volume
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf        # solo montar esta clave como archivo
        # Montar index.html en el directorio web
        - name: nginx-conf-volume
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
  volumes:
    - name: nginx-conf-volume
      configMap:
        name: nginx-config           # nombre del ConfigMap a montar
  restartPolicy: Never
EOF
```

2. Aplica y espera a que el Pod esté listo:

```bash
kubectl apply -f /tmp/pod-volume.yaml
kubectl wait --for=condition=Ready pod/app-pod-vol -n lab05 --timeout=90s
```

3. Verifica que los archivos están correctamente montados dentro del contenedor:

```bash
# Listar archivos montados
kubectl exec app-pod-vol -n lab05 -- ls -la /etc/nginx/nginx.conf
kubectl exec app-pod-vol -n lab05 -- ls -la /usr/share/nginx/html/index.html

# Verificar el contenido de la configuración montada
kubectl exec app-pod-vol -n lab05 -- cat /etc/nginx/nginx.conf

# Verificar que Nginx responde correctamente
kubectl exec app-pod-vol -n lab05 -- curl -s http://localhost/health
```

**Salida esperada de `curl`:**
```
OK
```

**Verificación:**
```bash
# Confirmar que el index.html proviene del ConfigMap
kubectl exec app-pod-vol -n lab05 -- cat /usr/share/nginx/html/index.html | grep "ConfigMap"
# Debe mostrar: <h1>Configuración desde ConfigMap</h1>
```

> **Nota importante:** Al usar `subPath` en `volumeMounts`, el archivo montado **no se actualiza automáticamente** cuando el ConfigMap cambia. Para obtener actualizaciones dinámicas, monta el volumen completo en un directorio (sin `subPath`) y configura la aplicación para leer desde ese directorio.

---

### Parte 2: Secrets (Tiempo estimado: 22 minutos)

---

#### Paso 2.1 — Crear y explorar Secrets de tipo Opaque

**Objetivo:** Crear Secrets de tipo Opaque de forma imperativa y declarativa, comprender la codificación base64 y verificar que los valores están codificados (no cifrados) en el almacenamiento.

**Instrucciones:**

1. Crea un Secret de tipo Opaque de forma imperativa:

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=S3cur3P@ssw0rd! \
  --from-literal=DB_HOST=postgres-service \
  --namespace=lab05
```

2. Inspecciona el Secret y observa la codificación base64:

```bash
# Ver el Secret (los valores aparecen codificados en base64)
kubectl get secret db-credentials -n lab05 -o yaml
```

3. Decodifica manualmente los valores para verificar:

```bash
# Extraer y decodificar el valor de DB_PASSWORD
kubectl get secret db-credentials -n lab05 \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode
echo  # salto de línea

# Extraer y decodificar DB_USER
kubectl get secret db-credentials -n lab05 \
  -o jsonpath='{.data.DB_USER}' | base64 --decode
echo
```

**Salida esperada:**
```
S3cur3P@ssw0rd!
admin
```

4. Crea un Secret de forma declarativa con valores pre-codificados:

```bash
# Primero, codifica los valores en base64
echo -n 'mi-api-key-secreta-12345' | base64
# Anota el resultado, p.ej.: bWktYXBpLWtleS1zZWNyZXRhLTEyMzQ1

echo -n 'token-jwt-super-secreto' | base64
# Anota el resultado

# Crear el manifiesto con valores ya codificados
cat <<'EOF' > /tmp/secret-api.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-credentials
  namespace: lab05
  labels:
    app: backend
type: Opaque
data:
  # Los valores DEBEN estar codificados en base64
  API_KEY: bWktYXBpLWtleS1zZWNyZXRhLTEyMzQ1
  JWT_TOKEN: dG9rZW4tand0LXN1cGVyLXNlY3JldG8=
EOF

kubectl apply -f /tmp/secret-api.yaml
```

5. Verifica ambos Secrets:

```bash
kubectl get secrets -n lab05
```

**Salida esperada:**
```
NAME               TYPE     DATA   AGE
api-credentials    Opaque   2      Xs
db-credentials     Opaque   3      Xs
```

**Verificación:**
```bash
# Verificar que los valores decodificados son correctos
kubectl get secret api-credentials -n lab05 \
  -o jsonpath='{.data.API_KEY}' | base64 --decode
echo
# Debe imprimir: mi-api-key-secreta-12345
```

> **Implicación de seguridad:** Los Secrets de Kubernetes están codificados en base64, **no cifrados**. Cualquier usuario con acceso de lectura al recurso puede decodificar los valores. Para seguridad real en producción, se deben combinar con RBAC restrictivo (que implementaremos en la Parte 3), cifrado en reposo (`EncryptionConfiguration`) y herramientas como HashiCorp Vault o Sealed Secrets.

---

#### Paso 2.2 — Crear Secrets de tipo docker-registry y TLS

**Objetivo:** Crear los tipos de Secrets más comunes en entornos productivos: credenciales para registro privado de Docker y certificados TLS.

**Instrucciones:**

1. Crea un Secret de tipo `docker-registry` para un registro privado:

```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.mi-empresa.com \
  --docker-username=deploy-user \
  --docker-password=RegistryP@ss123 \
  --docker-email=devops@mi-empresa.com \
  --namespace=lab05
```

2. Inspecciona el Secret de tipo docker-registry:

```bash
kubectl get secret registry-credentials -n lab05 -o yaml
```

3. Genera un certificado TLS auto-firmado para el Secret de tipo TLS:

```bash
# Generar clave privada y certificado auto-firmado
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /tmp/tls.key \
  -out /tmp/tls.crt \
  -subj "/CN=lab05.local/O=Lab05/C=ES"

# Verificar que los archivos se crearon
ls -la /tmp/tls.key /tmp/tls.crt
```

4. Crea el Secret de tipo TLS:

```bash
kubectl create secret tls tls-certificate \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  --namespace=lab05
```

5. Verifica todos los Secrets del namespace:

```bash
kubectl get secrets -n lab05
```

**Salida esperada:**
```
NAME                    TYPE                             DATA   AGE
api-credentials         Opaque                           2      Xm
db-credentials          Opaque                           3      Xm
registry-credentials    kubernetes.io/dockerconfigjson   1      Xs
tls-certificate         kubernetes.io/tls                2      Xs
```

**Verificación:**
```bash
# Verificar el tipo del Secret TLS
kubectl get secret tls-certificate -n lab05 -o jsonpath='{.type}'
# Debe imprimir: kubernetes.io/tls

# Verificar las claves del Secret TLS
kubectl get secret tls-certificate -n lab05 -o jsonpath='{.data}' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys()))"
# Debe imprimir: ['tls.crt', 'tls.key']
```

---

#### Paso 2.3 — Consumir Secrets en un Pod

**Objetivo:** Desplegar un Pod que consuma el Secret `db-credentials` tanto como variables de entorno como mediante volumen montado, verificando que los valores se descodifican automáticamente dentro del contenedor.

**Instrucciones:**

1. Crea el manifiesto del Pod con consumo de Secrets:

```bash
cat <<'EOF' > /tmp/pod-secrets.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod-secrets
  namespace: lab05
  labels:
    app: demo-secrets
spec:
  containers:
    - name: app
      image: busybox:latest
      command:
        - "sh"
        - "-c"
        - |
          echo "=== Secrets como variables de entorno ==="
          echo "DB_USER=$DB_USER"
          echo "DB_HOST=$DB_HOST"
          # NUNCA imprimir passwords en logs reales; solo para demo
          echo "DB_PASSWORD está definida: $([ -n "$DB_PASSWORD" ] && echo 'SÍ' || echo 'NO')"
          echo ""
          echo "=== Secret API_KEY desde env individual ==="
          echo "API_KEY definida: $([ -n "$API_KEY" ] && echo 'SÍ' || echo 'NO')"
          echo ""
          echo "=== Secrets montados como archivos ==="
          ls -la /etc/secrets/
          echo "Contenido de DB_USER file:"
          cat /etc/secrets/DB_USER
          sleep 3600
      # Inyectar todas las claves de db-credentials como variables de entorno
      envFrom:
        - secretRef:
            name: db-credentials
      env:
        # Inyectar una clave específica de api-credentials
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-credentials
              key: API_KEY
      volumeMounts:
        # Montar db-credentials como archivos
        - name: db-secret-volume
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: db-secret-volume
      secret:
        secretName: db-credentials
  restartPolicy: Never
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f /tmp/pod-secrets.yaml
kubectl wait --for=condition=Ready pod/app-pod-secrets -n lab05 --timeout=60s
```

3. Verifica los logs:

```bash
kubectl logs app-pod-secrets -n lab05
```

**Salida esperada:**
```
=== Secrets como variables de entorno ===
DB_USER=admin
DB_HOST=postgres-service
DB_PASSWORD está definida: SÍ

=== Secret API_KEY desde env individual ===
API_KEY definida: SÍ

=== Secrets montados como archivos ===
total 0
lrwxrwxrwx 1 root root ... DB_HOST -> ..data/DB_HOST
lrwxrwxrwx 1 root root ... DB_PASSWORD -> ..data/DB_PASSWORD
lrwxrwxrwx 1 root root ... DB_USER -> ..data/DB_USER
Contenido de DB_USER file:
admin
```

**Verificación:**
```bash
# Verificar que el valor del archivo coincide con el original
kubectl exec app-pod-secrets -n lab05 -- cat /etc/secrets/DB_USER
# Debe imprimir: admin (ya decodificado automáticamente por Kubernetes)
```

---

### Parte 3: RBAC — Control de Acceso Basado en Roles (Tiempo estimado: 37 minutos)

---

#### Paso 3.1 — Crear una ServiceAccount dedicada

**Objetivo:** Crear una ServiceAccount para una aplicación específica, comprendiendo que cada ServiceAccount representa una identidad dentro del clúster y que los Pods deben usar identidades con el mínimo privilegio necesario.

**Instrucciones:**

1. Crea la ServiceAccount de forma imperativa:

```bash
kubectl create serviceaccount app-reader \
  --namespace=lab05
```

2. Crea una segunda ServiceAccount con manifiesto YAML (con `automountServiceAccountToken: false` por seguridad):

```bash
cat <<'EOF' > /tmp/serviceaccount-monitor.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-monitor
  namespace: lab05
  labels:
    app: monitoring
    purpose: read-only-access
automountServiceAccountToken: false
EOF

kubectl apply -f /tmp/serviceaccount-monitor.yaml
```

3. Lista las ServiceAccounts del namespace:

```bash
kubectl get serviceaccounts -n lab05
```

**Salida esperada:**
```
NAME              SECRETS   AGE
app-reader        0         Xs
cluster-monitor   0         Xs
default           0         Xm
```

**Verificación:**
```bash
# Verificar los detalles de la ServiceAccount
kubectl describe serviceaccount app-reader -n lab05
# Debe mostrar: Name: app-reader, Namespace: lab05
```

---

#### Paso 3.2 — Crear un Role con permisos específicos (namespace-scoped)

**Objetivo:** Definir un `Role` que otorgue permisos granulares sobre recursos específicos dentro del namespace `lab05`, aplicando el principio de mínimo privilegio.

**Instrucciones:**

1. Crea el manifiesto del Role:

```bash
cat <<'EOF' > /tmp/role-pod-reader.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-configmap-reader
  namespace: lab05
  labels:
    app: demo-rbac
rules:
  # Permiso para leer Pods (get, list, watch)
  - apiGroups: [""]          # "" indica el grupo core de la API
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  # Permiso para leer logs de Pods
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
  # Permiso para leer ConfigMaps (pero NO Secrets)
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
EOF

kubectl apply -f /tmp/role-pod-reader.yaml
```

2. Crea un Role adicional con permisos de escritura limitados:

```bash
cat <<'EOF' > /tmp/role-deployment-manager.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-manager
  namespace: lab05
rules:
  # Permisos completos sobre Deployments
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  # Solo lectura de ReplicaSets
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "list", "watch"]
  # Permisos sobre Services
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update"]
EOF

kubectl apply -f /tmp/role-deployment-manager.yaml
```

3. Verifica los Roles creados:

```bash
kubectl get roles -n lab05

# Ver los detalles del Role principal
kubectl describe role pod-configmap-reader -n lab05
```

**Salida esperada de `kubectl get roles`:**
```
NAME                    CREATED AT
deployment-manager      ...
pod-configmap-reader    ...
```

**Verificación:**
```bash
# Verificar las reglas del Role
kubectl get role pod-configmap-reader -n lab05 -o jsonpath='{.rules}' | \
  python3 -m json.tool
```

---

#### Paso 3.3 — Crear RoleBindings para vincular Roles a ServiceAccounts

**Objetivo:** Vincular los Roles creados a las ServiceAccounts correspondientes mediante `RoleBinding`, estableciendo qué identidad tiene qué permisos en el namespace.

**Instrucciones:**

1. Crea el RoleBinding para vincular `pod-configmap-reader` a `app-reader`:

```bash
cat <<'EOF' > /tmp/rolebinding-app-reader.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: lab05
  labels:
    app: demo-rbac
subjects:
  # La ServiceAccount que recibe los permisos
  - kind: ServiceAccount
    name: app-reader
    namespace: lab05
roleRef:
  # El Role que se vincula (inmutable una vez creado)
  kind: Role
  name: pod-configmap-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f /tmp/rolebinding-app-reader.yaml
```

2. Crea el RoleBinding para `deployment-manager` vinculado a `cluster-monitor`:

```bash
kubectl create rolebinding monitor-deployment-binding \
  --role=deployment-manager \
  --serviceaccount=lab05:cluster-monitor \
  --namespace=lab05
```

3. Lista los RoleBindings:

```bash
kubectl get rolebindings -n lab05

# Ver detalles del primer RoleBinding
kubectl describe rolebinding app-reader-binding -n lab05
```

**Salida esperada de `kubectl describe`:**
```
Name:         app-reader-binding
Namespace:    lab05
Labels:       app=demo-rbac
Role:
  Kind:  Role
  Name:  pod-configmap-reader
Subjects:
  Kind            Name        Namespace
  ----            ----        ---------
  ServiceAccount  app-reader  lab05
```

**Verificación:**
```bash
# Verificar la vinculación
kubectl get rolebinding app-reader-binding -n lab05 \
  -o jsonpath='{.subjects[0].name}'
# Debe imprimir: app-reader
```

---

#### Paso 3.4 — Verificar permisos con kubectl auth can-i

**Objetivo:** Utilizar `kubectl auth can-i` para auditar los permisos de las ServiceAccounts creadas, verificando tanto los permisos concedidos como los denegados.

**Instrucciones:**

1. Verifica los permisos de `app-reader` (debe poder leer Pods y ConfigMaps, pero NO Secrets ni crear Pods):

```bash
echo "=== Permisos de app-reader en namespace lab05 ==="

# Permisos que SÍ debe tener
kubectl auth can-i get pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: yes

kubectl auth can-i list pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: yes

kubectl auth can-i get configmaps \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: yes

echo "---"
echo "=== Permisos que NO debe tener ==="

# Permisos que NO debe tener
kubectl auth can-i create pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: no

kubectl auth can-i get secrets \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: no

kubectl auth can-i delete pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: no

kubectl auth can-i get deployments \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: no
```

2. Verifica los permisos de `cluster-monitor`:

```bash
echo "=== Permisos de cluster-monitor en namespace lab05 ==="

kubectl auth can-i get deployments \
  --as=system:serviceaccount:lab05:cluster-monitor \
  --namespace=lab05
# Esperado: yes

kubectl auth can-i create deployments \
  --as=system:serviceaccount:lab05:cluster-monitor \
  --namespace=lab05
# Esperado: yes

kubectl auth can-i delete deployments \
  --as=system:serviceaccount:lab05:cluster-monitor \
  --namespace=lab05
# Esperado: no
```

3. Usa el flag `--list` para ver todos los permisos de una ServiceAccount:

```bash
# Listar TODOS los permisos de app-reader en el namespace
kubectl auth can-i --list \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
```

**Salida esperada (fragmento):**
```
Resources                                       Non-Resource URLs   Resource Names   Verbs
configmaps                                      []                  []               [get list watch]
pods                                            []                  []               [get list watch]
pods/log                                        []                  []               [get]
...
```

**Verificación:**
```bash
# Script de auditoría rápida
for verb in get list watch create delete; do
  result=$(kubectl auth can-i $verb pods \
    --as=system:serviceaccount:lab05:app-reader \
    --namespace=lab05 2>/dev/null)
  echo "app-reader puede '$verb' pods: $result"
done
```

---

#### Paso 3.5 — Crear un ClusterRole y ClusterRoleBinding (cluster-scoped)

**Objetivo:** Demostrar la diferencia entre `Role` (limitado a un namespace) y `ClusterRole` (válido en todo el clúster), creando un ClusterRole de solo lectura para recursos de nodo.

**Instrucciones:**

1. Crea un ClusterRole para lectura de recursos de clúster:

```bash
cat <<'EOF' > /tmp/clusterrole-node-reader.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-namespace-reader
  labels:
    app: demo-rbac
    scope: cluster
rules:
  # Lectura de nodos (recurso de clúster, sin namespace)
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  # Lectura de namespaces (recurso de clúster)
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
  # Lectura de PersistentVolumes (recurso de clúster)
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch"]
EOF

kubectl apply -f /tmp/clusterrole-node-reader.yaml
```

2. Crea un ClusterRoleBinding para vincular el ClusterRole a `cluster-monitor`:

```bash
cat <<'EOF' > /tmp/clusterrolebinding-monitor.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-monitor-binding
  labels:
    app: demo-rbac
subjects:
  - kind: ServiceAccount
    name: cluster-monitor
    namespace: lab05           # ServiceAccount está en namespace lab05
roleRef:
  kind: ClusterRole
  name: node-namespace-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f /tmp/clusterrolebinding-monitor.yaml
```

3. Verifica los permisos a nivel de clúster:

```bash
echo "=== Permisos de cluster-monitor a nivel de CLÚSTER ==="

# Puede leer nodos (recurso de clúster)
kubectl auth can-i get nodes \
  --as=system:serviceaccount:lab05:cluster-monitor
# Esperado: yes

kubectl auth can-i list namespaces \
  --as=system:serviceaccount:lab05:cluster-monitor
# Esperado: yes

# NO puede leer nodos en un namespace específico (los nodos son cluster-scoped)
kubectl auth can-i delete nodes \
  --as=system:serviceaccount:lab05:cluster-monitor
# Esperado: no

echo ""
echo "=== app-reader NO tiene permisos de clúster ==="

kubectl auth can-i get nodes \
  --as=system:serviceaccount:lab05:app-reader
# Esperado: no

kubectl auth can-i list namespaces \
  --as=system:serviceaccount:lab05:app-reader
# Esperado: no
```

4. Compara los tipos de recursos RBAC:

```bash
# Ver todos los ClusterRoles del sistema (incluidos los del sistema)
kubectl get clusterroles | grep -E "^(node-namespace|system:node|cluster-admin)"

# Ver el ClusterRoleBinding creado
kubectl get clusterrolebindings cluster-monitor-binding -o yaml
```

**Verificación:**
```bash
# Demostrar diferencia: app-reader puede leer pods en lab05 pero NO en kube-system
kubectl auth can-i get pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Esperado: yes

kubectl auth can-i get pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=kube-system
# Esperado: no
# Esto demuestra que el Role es namespace-scoped
```

---

#### Paso 3.6 — Desplegar un Pod que use la ServiceAccount y verificar acceso a la API

**Objetivo:** Desplegar un Pod real que use `app-reader` como ServiceAccount y verificar que puede consultar la API de Kubernetes con los permisos configurados, pero que es rechazado al intentar operaciones no autorizadas.

**Instrucciones:**

1. Crea el Pod con la ServiceAccount asignada:

```bash
cat <<'EOF' > /tmp/pod-rbac-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rbac-demo-pod
  namespace: lab05
  labels:
    app: rbac-demo
spec:
  serviceAccountName: app-reader      # Usar la ServiceAccount creada
  automountServiceAccountToken: true  # Montar el token automáticamente
  containers:
    - name: kubectl-container
      image: bitnami/kubectl:latest
      command:
        - "sh"
        - "-c"
        - |
          echo "=== Identidad del Pod ==="
          echo "ServiceAccount token montado en: /var/run/secrets/kubernetes.io/serviceaccount/"
          ls /var/run/secrets/kubernetes.io/serviceaccount/

          echo ""
          echo "=== Operaciones PERMITIDAS ==="

          echo "Listando Pods en namespace lab05:"
          kubectl get pods -n lab05 --no-headers | wc -l
          echo "pods encontrados"

          echo "Listando ConfigMaps en namespace lab05:"
          kubectl get configmaps -n lab05 --no-headers | wc -l
          echo "configmaps encontrados"

          echo ""
          echo "=== Operaciones DENEGADAS (deben fallar) ==="

          echo "Intentando listar Secrets (debe fallar):"
          kubectl get secrets -n lab05 2>&1 || echo "ACCESO DENEGADO - correcto"

          echo "Intentando crear un Pod (debe fallar):"
          kubectl run test-pod --image=nginx -n lab05 2>&1 || echo "ACCESO DENEGADO - correcto"

          sleep 3600
      resources:
        requests:
          memory: "64Mi"
          cpu: "50m"
        limits:
          memory: "128Mi"
          cpu: "100m"
  restartPolicy: Never
EOF

kubectl apply -f /tmp/pod-rbac-demo.yaml
kubectl wait --for=condition=Ready pod/rbac-demo-pod -n lab05 --timeout=90s
```

2. Verifica los logs del Pod:

```bash
kubectl logs rbac-demo-pod -n lab05
```

**Salida esperada:**
```
=== Identidad del Pod ===
ServiceAccount token montado en: /var/run/secrets/kubernetes.io/serviceaccount/
ca.crt  namespace  token

=== Operaciones PERMITIDAS ===
Listando Pods en namespace lab05:
X
pods encontrados
Listando ConfigMaps en namespace lab05:
X
configmaps encontrados

=== Operaciones DENEGADAS (deben fallar) ===
Intentando listar Secrets (debe fallar):
Error from server (Forbidden): secrets is forbidden: User "system:serviceaccount:lab05:app-reader" cannot list resource "secrets" in API group "" in the namespace "lab05"
ACCESO DENEGADO - correcto
Intentando crear un Pod (debe fallar):
Error from server (Forbidden): pods is forbidden: ...
ACCESO DENEGADO - correcto
```

**Verificación:**
```bash
# Verificar que el Pod usa la ServiceAccount correcta
kubectl get pod rbac-demo-pod -n lab05 \
  -o jsonpath='{.spec.serviceAccountName}'
# Debe imprimir: app-reader
```

---

## Validación y Pruebas Finales

Ejecuta este bloque de validación completo para confirmar que todos los recursos están correctamente configurados:

```bash
#!/bin/bash
echo "============================================"
echo "VALIDACIÓN FINAL - Lab 05-00-01"
echo "============================================"
NAMESPACE="lab05"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  local expected="$3"
  local result=$(eval "$cmd" 2>/dev/null)
  if echo "$result" | grep -q "$expected"; then
    echo "  ✅ PASS: $desc"
    ((PASS++))
  else
    echo "  ❌ FAIL: $desc (obtenido: '$result', esperado: '$expected')"
    ((FAIL++))
  fi
}

echo ""
echo "--- Parte 1: ConfigMaps ---"
check "ConfigMap app-config existe" \
  "kubectl get configmap app-config -n $NAMESPACE -o jsonpath='{.metadata.name}'" \
  "app-config"

check "ConfigMap app-config tiene clave LOG_LEVEL=debug" \
  "kubectl get configmap app-config -n $NAMESPACE -o jsonpath='{.data.LOG_LEVEL}'" \
  "debug"

check "ConfigMap nginx-config existe con nginx.conf" \
  "kubectl get configmap nginx-config -n $NAMESPACE -o jsonpath='{.data.nginx\.conf}'" \
  "worker_processes"

check "Pod app-pod-env completó ejecución" \
  "kubectl get pod app-pod-env -n $NAMESPACE -o jsonpath='{.status.phase}'" \
  "Running"

check "Pod app-pod-vol está Running" \
  "kubectl get pod app-pod-vol -n $NAMESPACE -o jsonpath='{.status.phase}'" \
  "Running"

echo ""
echo "--- Parte 2: Secrets ---"
check "Secret db-credentials existe tipo Opaque" \
  "kubectl get secret db-credentials -n $NAMESPACE -o jsonpath='{.type}'" \
  "Opaque"

check "Secret tls-certificate es tipo kubernetes.io/tls" \
  "kubectl get secret tls-certificate -n $NAMESPACE -o jsonpath='{.type}'" \
  "kubernetes.io/tls"

check "Secret registry-credentials es tipo dockerconfigjson" \
  "kubectl get secret registry-credentials -n $NAMESPACE -o jsonpath='{.type}'" \
  "dockerconfigjson"

check "DB_USER decodifica correctamente a 'admin'" \
  "kubectl get secret db-credentials -n $NAMESPACE -o jsonpath='{.data.DB_USER}' | base64 --decode" \
  "admin"

echo ""
echo "--- Parte 3: RBAC ---"
check "ServiceAccount app-reader existe" \
  "kubectl get serviceaccount app-reader -n $NAMESPACE -o jsonpath='{.metadata.name}'" \
  "app-reader"

check "Role pod-configmap-reader existe" \
  "kubectl get role pod-configmap-reader -n $NAMESPACE -o jsonpath='{.metadata.name}'" \
  "pod-configmap-reader"

check "RoleBinding app-reader-binding existe" \
  "kubectl get rolebinding app-reader-binding -n $NAMESPACE -o jsonpath='{.metadata.name}'" \
  "app-reader-binding"

check "ClusterRole node-namespace-reader existe" \
  "kubectl get clusterrole node-namespace-reader -o jsonpath='{.metadata.name}'" \
  "node-namespace-reader"

check "app-reader PUEDE get pods en lab05" \
  "kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:app-reader --namespace=$NAMESPACE" \
  "yes"

check "app-reader NO PUEDE get secrets en lab05" \
  "kubectl auth can-i get secrets --as=system:serviceaccount:$NAMESPACE:app-reader --namespace=$NAMESPACE" \
  "no"

check "app-reader NO PUEDE get pods en kube-system" \
  "kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:app-reader --namespace=kube-system" \
  "no"

check "cluster-monitor PUEDE get nodes (cluster-scoped)" \
  "kubectl auth can-i get nodes --as=system:serviceaccount:$NAMESPACE:cluster-monitor" \
  "yes"

check "Pod rbac-demo-pod usa ServiceAccount app-reader" \
  "kubectl get pod rbac-demo-pod -n $NAMESPACE -o jsonpath='{.spec.serviceAccountName}'" \
  "app-reader"

echo ""
echo "============================================"
echo "RESULTADO: $PASS pasaron, $FAIL fallaron"
echo "============================================"
```

---

## Solución de Problemas

### Problema 1: Pod en estado `CreateContainerConfigError` al referenciar ConfigMap o Secret inexistente

**Síntomas:**
```
$ kubectl get pod app-pod-env -n lab05
NAME          READY   STATUS                       RESTARTS   AGE
app-pod-env   0/1     CreateContainerConfigError   0          30s

$ kubectl describe pod app-pod-env -n lab05
...
Warning  Failed  ...  Error: configmap "app-config" not found
```

**Causa:** El Pod referencia un ConfigMap o Secret que no existe en el mismo namespace, o hay una discrepancia en el nombre (typo) o en el namespace.

**Solución:**
```bash
# 1. Verificar que el ConfigMap existe en el namespace correcto
kubectl get configmap app-config -n lab05
# Si no existe, crearlo:
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=debug \
  --from-literal=APP_PORT=8080 \
  --from-literal=APP_ENV=development \
  --namespace=lab05

# 2. Verificar el namespace del Pod vs el namespace del ConfigMap
kubectl get pod app-pod-env -n lab05 -o jsonpath='{.metadata.namespace}'
kubectl get configmap app-config -n lab05 -o jsonpath='{.metadata.namespace}'
# Ambos deben ser: lab05

# 3. Forzar recreación del Pod después de crear el recurso faltante
kubectl delete pod app-pod-env -n lab05
kubectl apply -f /tmp/pod-env.yaml

# 4. Verificar el estado
kubectl get pod app-pod-env -n lab05
```

---

### Problema 2: `kubectl auth can-i` devuelve `no` para permisos que deberían estar concedidos

**Síntomas:**
```
$ kubectl auth can-i get pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
no
```
Cuando se esperaba `yes` porque el Role y RoleBinding fueron creados.

**Causa:** El RoleBinding no vincula correctamente la ServiceAccount al Role. Las causas más comunes son: (a) el nombre de la ServiceAccount en el `subject` del RoleBinding no coincide exactamente con el nombre real, (b) el namespace del subject es incorrecto, o (c) el `roleRef` apunta a un Role que no existe o tiene un nombre diferente.

**Solución:**
```bash
# 1. Verificar que el RoleBinding existe y tiene el subject correcto
kubectl get rolebinding app-reader-binding -n lab05 -o yaml

# Buscar en la sección subjects:
# subjects:
# - kind: ServiceAccount
#   name: app-reader          <-- debe coincidir exactamente
#   namespace: lab05          <-- debe ser el namespace correcto

# 2. Verificar que la ServiceAccount existe con ese nombre exacto
kubectl get serviceaccount -n lab05 | grep app-reader

# 3. Verificar que el Role referenciado existe
kubectl get role pod-configmap-reader -n lab05

# 4. Si hay discrepancia, eliminar y recrear el RoleBinding
kubectl delete rolebinding app-reader-binding -n lab05
kubectl apply -f /tmp/rolebinding-app-reader.yaml

# 5. Volver a verificar
kubectl auth can-i get pods \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05
# Ahora debe devolver: yes

# 6. Herramienta de diagnóstico adicional: listar todos los permisos
kubectl auth can-i --list \
  --as=system:serviceaccount:lab05:app-reader \
  --namespace=lab05 | head -20
```

---

## Limpieza del Entorno

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio. **Omite este paso si planeas usar estos recursos en laboratorios posteriores.**

```bash
# Eliminar Pods
kubectl delete pod app-pod-env app-pod-vol app-pod-secrets rbac-demo-pod \
  -n lab05 --ignore-not-found=true

# Eliminar ConfigMaps
kubectl delete configmap app-config app-properties nginx-config \
  -n lab05 --ignore-not-found=true

# Eliminar Secrets
kubectl delete secret db-credentials api-credentials \
  registry-credentials tls-certificate \
  -n lab05 --ignore-not-found=true

# Eliminar recursos RBAC con scope de namespace
kubectl delete rolebinding app-reader-binding monitor-deployment-binding \
  -n lab05 --ignore-not-found=true

kubectl delete role pod-configmap-reader deployment-manager \
  -n lab05 --ignore-not-found=true

kubectl delete serviceaccount app-reader cluster-monitor \
  -n lab05 --ignore-not-found=true

# Eliminar recursos RBAC con scope de clúster
kubectl delete clusterrolebinding cluster-monitor-binding \
  --ignore-not-found=true

kubectl delete clusterrole node-namespace-reader \
  --ignore-not-found=true

# Eliminar archivos temporales
rm -f /tmp/app.properties /tmp/configmap-nginx.yaml \
      /tmp/pod-env.yaml /tmp/pod-volume.yaml \
      /tmp/secret-api.yaml /tmp/pod-secrets.yaml \
      /tmp/serviceaccount-monitor.yaml \
      /tmp/role-pod-reader.yaml /tmp/role-deployment-manager.yaml \
      /tmp/rolebinding-app-reader.yaml \
      /tmp/clusterrole-node-reader.yaml \
      /tmp/clusterrolebinding-monitor.yaml \
      /tmp/pod-rbac-demo.yaml \
      /tmp/tls.key /tmp/tls.crt

# Restaurar el namespace por defecto
kubectl config set-context --current --namespace=default

# Opcional: eliminar el namespace completo (elimina TODOS los recursos dentro)
# kubectl delete namespace lab05
```

Verifica que la limpieza fue exitosa:
```bash
kubectl get all -n lab05
# Debe mostrar: No resources found in lab05 namespace.
```

---

## Resumen

En este laboratorio has construido un sistema completo de configuración y control de acceso en Kubernetes, cubriendo los tres pilares fundamentales:

### Lo que aprendiste

| Área | Conceptos aplicados |
|------|---------------------|
| **ConfigMaps** | Creación imperativa (`--from-literal`, `--from-file`) y declarativa (YAML); consumo como `envFrom`, `env.valueFrom` y `volumeMounts` con `subPath`; diferencia en actualización dinámica entre volúmenes y variables de entorno |
| **Secrets** | Tipos `Opaque`, `docker-registry` y `tls`; codificación base64 (no es cifrado); consumo con `secretRef` y `secretKeyRef`; implicaciones de seguridad y necesidad de RBAC complementario |
| **RBAC** | ServiceAccounts como identidades de aplicación; `Role` vs `ClusterRole` (namespace-scoped vs cluster-scoped); `RoleBinding` y `ClusterRoleBinding`; verificación con `kubectl auth can-i --list`; principio de mínimo privilegio |

### Patrones clave para el examen CKA

- Un `Role` solo otorga permisos dentro de su propio namespace; para permisos en múltiples namespaces o recursos de clúster, usa `ClusterRole` + `ClusterRoleBinding`
- El formato del `--as` flag para ServiceAccounts es siempre `system:serviceaccount:<namespace>:<name>`
- Los Secrets montados como volúmenes se decodifican automáticamente; las variables de entorno también
- `kubectl auth can-i --list` es tu herramienta de auditoría de permisos más rápida en el examen

### Recursos adicionales

- [Documentación oficial: ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Documentación oficial: Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Documentación oficial: RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Referencia de API: ServiceAccount](https://kubernetes.io/docs/reference/kubernetes-api/authentication-resources/service-account-v1/)
- [Twelve-Factor App — Factor III: Config](https://12factor.net/config)

---
LAB_END---

---

# Práctica complementaria 5.1: Validación de permisos con ServiceAccount

## 1. Metadatos

| Campo | Detalle |
|---|---|
| **Duración estimada** | 22 minutos |
| **Complejidad** | Media |
| **Nivel Bloom** | Aplicar (Apply) |
| **Módulo** | 5 — Configuración y Seguridad en Kubernetes |
| **Laboratorio previo requerido** | 05-00-01 |

---

## 2. Descripción General

En este laboratorio aplicarás técnicas de auditoría y corrección de configuraciones RBAC utilizando `kubectl auth can-i` con suplantación de identidad (`--as`) y verificación real desde dentro de un Pod. Recibirás un entorno pre-configurado con tres ServiceAccounts que presentan distintos problemas: permisos correctos, permisos insuficientes y permisos excesivos con comodines (`*`). Tu misión es identificar cada problema, demostrarlo con evidencia técnica y aplicar las correcciones necesarias siguiendo el principio de mínimo privilegio.

Este laboratorio refuerza la comprensión de cómo el token del ServiceAccount montado en `/var/run/secrets/kubernetes.io/serviceaccount/` permite a los Pods interactuar con la API de Kubernetes, y cómo RBAC controla ese acceso de forma granular.

---

## 3. Objetivos de Aprendizaje

- [ ] Usar `kubectl auth can-i --as=system:serviceaccount:<namespace>:<name>` para auditar permisos de ServiceAccounts sin ejecutar como ellos directamente.
- [ ] Ejecutar un Pod con un ServiceAccount específico y demostrar acceso real a la API de Kubernetes usando el token montado automáticamente.
- [ ] Identificar y corregir un ServiceAccount con permisos insuficientes que impide el funcionamiento de una aplicación.
- [ ] Identificar y corregir un ServiceAccount con permisos de comodín (`*`) que viola el principio de mínimo privilegio.
- [ ] Verificar que las correcciones RBAC producen el comportamiento esperado mediante pruebas antes y después del cambio.

---

## 4. Prerrequisitos

### Conocimiento previo

- Comprensión de ServiceAccounts, Roles y RoleBindings (Lab 05-00-01 completado).
- Familiaridad con `kubectl exec` para ejecutar comandos dentro de Pods.
- Conocimiento básico de la API REST de Kubernetes y tokens Bearer.
- Haber revisado el contenido de la Lección 5.1 sobre ConfigMaps (contexto del módulo).

### Acceso requerido

- Clúster Minikube operativo con mínimo 1 nodo (los recursos del Lab 05-00-01 deben estar disponibles).
- Terminal con `kubectl` configurado y apuntando al clúster Minikube.
- Permisos de administrador del clúster (`cluster-admin`) para crear y modificar recursos RBAC.

---

## 5. Entorno del Laboratorio

### Hardware mínimo recomendado

| Recurso | Mínimo | Recomendado |
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
| `curl` | 7.x | `curl --version` |

### Verificación del entorno antes de comenzar

Ejecuta los siguientes comandos para confirmar que el entorno está listo:

```bash
# 1. Verificar que el clúster está activo
kubectl cluster-info

# 2. Verificar que el namespace del lab anterior existe
kubectl get namespace rbac-lab 2>/dev/null || echo "AVISO: namespace rbac-lab no encontrado"

# 3. Verificar nodos disponibles
kubectl get nodes

# 4. Confirmar acceso de administrador
kubectl auth can-i '*' '*' --all-namespaces
```

**Salida esperada del paso 4:**
```
yes
```

> **Nota:** Si el namespace `rbac-lab` no existe desde el Lab 05-00-01, el Paso 1 de este laboratorio lo recreará con todos los recursos necesarios.

---

## 6. Instrucciones Paso a Paso

---

### Paso 1: Despliegue del Entorno de Práctica

**Objetivo:** Crear el namespace de trabajo y los tres ServiceAccounts con sus RoleBindings pre-configurados — uno correcto, uno con permisos insuficientes y uno con permisos excesivos — que serán objeto de auditoría.

#### Instrucciones

**1.1** Crea el namespace de trabajo para este laboratorio:

```bash
kubectl create namespace rbac-audit 2>/dev/null || echo "Namespace rbac-audit ya existe"
```

**1.2** Crea el archivo de manifiesto completo con todos los recursos del entorno de práctica. Este manifiesto configura intencionalmente escenarios problemáticos:

```bash
cat << 'EOF' > rbac-audit-setup.yaml
# ─────────────────────────────────────────────────────────────────────────────
# ServiceAccount 1: "reader-sa" — Permisos CORRECTOS (solo lectura de pods)
# ─────────────────────────────────────────────────────────────────────────────
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reader-sa
  namespace: rbac-audit
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader-role
  namespace: rbac-audit
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reader-sa-binding
  namespace: rbac-audit
subjects:
  - kind: ServiceAccount
    name: reader-sa
    namespace: rbac-audit
roleRef:
  kind: Role
  name: pod-reader-role
  apiGroup: rbac.authorization.k8s.io
---
# ─────────────────────────────────────────────────────────────────────────────
# ServiceAccount 2: "app-deployer-sa" — Permisos INSUFICIENTES
# La aplicación necesita listar y obtener ConfigMaps, pero el Role solo
# permite listar Pods. Esto simulará una aplicación que falla al arrancar.
# ─────────────────────────────────────────────────────────────────────────────
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-deployer-sa
  namespace: rbac-audit
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer-role-broken
  namespace: rbac-audit
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list"]
  # PROBLEMA: Falta permiso para leer ConfigMaps que la app necesita
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer-binding
  namespace: rbac-audit
subjects:
  - kind: ServiceAccount
    name: app-deployer-sa
    namespace: rbac-audit
roleRef:
  kind: Role
  name: app-deployer-role-broken
  apiGroup: rbac.authorization.k8s.io
---
# ─────────────────────────────────────────────────────────────────────────────
# ServiceAccount 3: "wildcard-sa" — Permisos EXCESIVOS (viola mínimo privilegio)
# Tiene acceso wildcard (*) a todos los recursos y verbos.
# ─────────────────────────────────────────────────────────────────────────────
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wildcard-sa
  namespace: rbac-audit
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: wildcard-role-excessive
  namespace: rbac-audit
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: wildcard-sa-binding
  namespace: rbac-audit
subjects:
  - kind: ServiceAccount
    name: wildcard-sa
    namespace: rbac-audit
roleRef:
  kind: Role
  name: wildcard-role-excessive
  apiGroup: rbac.authorization.k8s.io
---
# ─────────────────────────────────────────────────────────────────────────────
# ConfigMap de ejemplo que la app-deployer-sa debería poder leer
# ─────────────────────────────────────────────────────────────────────────────
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
  namespace: rbac-audit
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
EOF
```

**1.3** Aplica el manifiesto al clúster:

```bash
kubectl apply -f rbac-audit-setup.yaml
```

**Salida esperada:**
```
serviceaccount/reader-sa created
role.rbac.authorization.k8s.io/pod-reader-role created
rolebinding.rbac.authorization.k8s.io/reader-sa-binding created
serviceaccount/app-deployer-sa created
role.rbac.authorization.k8s.io/app-deployer-role-broken created
rolebinding.rbac.authorization.k8s.io/app-deployer-binding created
serviceaccount/wildcard-sa created
role.rbac.authorization.k8s.io/wildcard-role-excessive created
rolebinding.rbac.authorization.k8s.io/wildcard-sa-binding created
configmap/app-settings created
```

#### Verificación

```bash
# Confirmar que los tres ServiceAccounts existen
kubectl get serviceaccounts -n rbac-audit

# Confirmar que los Roles y RoleBindings están creados
kubectl get roles,rolebindings -n rbac-audit

# Confirmar que el ConfigMap existe
kubectl get configmap app-settings -n rbac-audit
```

**Salida esperada de `kubectl get serviceaccounts`:**
```
NAME              SECRETS   AGE
app-deployer-sa   0         Xs
default           0         Xs
reader-sa         0         Xs
wildcard-sa       0         Xs
```

---

### Paso 2: Auditoría con `kubectl auth can-i --as`

**Objetivo:** Usar el flag `--as` de `kubectl auth can-i` para verificar los permisos de cada ServiceAccount sin necesidad de ejecutar Pods, y documentar el estado actual antes de realizar correcciones.

#### Instrucciones

**2.1** Audita el ServiceAccount `reader-sa` (configuración correcta — referencia):

```bash
echo "=== AUDITORÍA: reader-sa ==="

# ¿Puede listar pods? (debería ser YES)
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit

# ¿Puede obtener un pod específico? (debería ser YES)
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit

# ¿Puede crear pods? (debería ser NO — mínimo privilegio)
kubectl auth can-i create pods \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit

# ¿Puede leer ConfigMaps? (debería ser NO)
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit

# ¿Puede eliminar pods? (debería ser NO)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit
```

**Salida esperada:**
```
yes
yes
no
no
no
```

**2.2** Audita el ServiceAccount `app-deployer-sa` (permisos insuficientes):

```bash
echo "=== AUDITORÍA: app-deployer-sa ==="

# ¿Puede listar pods? (debería ser YES — lo único que tiene)
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

# ¿Puede leer ConfigMaps? (debería ser NO — aquí está el problema)
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

# ¿Puede listar ConfigMaps? (debería ser NO)
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit
```

**Salida esperada:**
```
yes
no
no
```

> **Análisis:** `app-deployer-sa` no puede acceder a ConfigMaps. Si esta SA fuera usada por una aplicación que necesita leer su configuración desde un ConfigMap (como vimos en la Lección 5.1), la aplicación fallaría con un error 403 Forbidden al intentar consultar la API.

**2.3** Audita el ServiceAccount `wildcard-sa` (permisos excesivos):

```bash
echo "=== AUDITORÍA: wildcard-sa ==="

# ¿Puede hacer TODO? (debería ser YES — esto es el problema)
kubectl auth can-i '*' '*' \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

# ¿Puede eliminar pods? (debería ser NO en un SA bien configurado)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

# ¿Puede crear roles? (debería ser NO en un SA de aplicación)
kubectl auth can-i create roles \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

# ¿Puede crear secrets? (debería ser NO para una app normal)
kubectl auth can-i create secrets \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit
```

**Salida esperada:**
```
yes
yes
yes
yes
```

> **Análisis:** `wildcard-sa` tiene permisos para todo dentro del namespace. Esto viola gravemente el principio de mínimo privilegio — si este SA fuera comprometido, un atacante tendría control total del namespace.

**2.4** Usa el flag `--list` para obtener un inventario completo de permisos:

```bash
# Listar TODOS los permisos de reader-sa (referencia correcta)
echo "=== PERMISOS COMPLETOS: reader-sa ==="
kubectl auth can-i --list \
  --as=system:serviceaccount:rbac-audit:reader-sa \
  -n rbac-audit

# Listar TODOS los permisos de wildcard-sa (excesivos)
echo ""
echo "=== PERMISOS COMPLETOS: wildcard-sa ==="
kubectl auth can-i --list \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit
```

**Salida esperada para `reader-sa` (extracto):**
```
Resources                                       Non-Resource URLs   Resource Names   Verbs
pods                                            []                  []               [get list watch]
...
```

**Salida esperada para `wildcard-sa` (extracto):**
```
Resources                                       Non-Resource URLs   Resource Names   Verbs
*.*                                             []                  []               [*]
...
```

#### Verificación

```bash
# Resumen rápido de los tres escenarios
echo "--- RESUMEN DE AUDITORÍA ---"
echo "reader-sa puede listar pods:"
kubectl auth can-i list pods --as=system:serviceaccount:rbac-audit:reader-sa -n rbac-audit
echo "app-deployer-sa puede leer configmaps:"
kubectl auth can-i get configmaps --as=system:serviceaccount:rbac-audit:app-deployer-sa -n rbac-audit
echo "wildcard-sa puede hacer todo:"
kubectl auth can-i '*' '*' --as=system:serviceaccount:rbac-audit:wildcard-sa -n rbac-audit
```

**Salida esperada:**
```
--- RESUMEN DE AUDITORÍA ---
reader-sa puede listar pods:
yes
app-deployer-sa puede leer configmaps:
no
wildcard-sa puede hacer todo:
yes
```

---

### Paso 3: Demostración de Acceso Real desde dentro de un Pod

**Objetivo:** Demostrar que las restricciones RBAC se aplican también cuando un Pod usa su token de ServiceAccount para llamar directamente a la API de Kubernetes, no solo desde `kubectl` externo.

#### Instrucciones

**3.1** Crea un Pod que use `reader-sa` y ejecuta `kubectl` desde dentro usando el token montado:

```bash
cat << 'EOF' > pod-reader-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-test-pod
  namespace: rbac-audit
spec:
  serviceAccountName: reader-sa
  containers:
    - name: kubectl-container
      image: bitnami/kubectl:latest
      command: ["sleep", "3600"]
      # El token se monta automáticamente en:
      # /var/run/secrets/kubernetes.io/serviceaccount/token
  restartPolicy: Never
EOF

kubectl apply -f pod-reader-test.yaml
```

**3.2** Espera a que el Pod esté en estado `Running`:

```bash
kubectl wait --for=condition=Ready pod/reader-test-pod \
  -n rbac-audit \
  --timeout=60s
```

**Salida esperada:**
```
pod/reader-test-pod condition met
```

**3.3** Verifica desde dentro del Pod que el token existe y examina su estructura:

```bash
# Listar los archivos del ServiceAccount token montado
kubectl exec -n rbac-audit reader-test-pod -- \
  ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

**Salida esperada:**
```
total 4
drwxrwxrwt    3 root     root           140 <date> .
drwxr-xr-x    3 root     root            28 <date> ..
lrwxrwxrwx    1 root     root            13 <date> ca.crt -> ..data/ca.crt
lrwxrwxrwx    1 root     root            16 <date> namespace -> ..data/namespace
lrwxrwxrwx    1 root     root            12 <date> token -> ..data/token
```

> **Explicación:** Los tres archivos son clave para autenticarse con la API:
> - `token`: Token JWT Bearer del ServiceAccount
> - `ca.crt`: Certificado CA del clúster para validar TLS
> - `namespace`: El namespace donde corre el Pod

**3.4** Usa `kubectl` dentro del Pod para listar Pods (operación permitida para `reader-sa`):

```bash
kubectl exec -n rbac-audit reader-test-pod -- \
  kubectl get pods -n rbac-audit
```

**Salida esperada:**
```
NAME               READY   STATUS    RESTARTS   AGE
reader-test-pod    1/1     Running   0          Xm
```

**3.5** Intenta una operación NO permitida (crear pods) desde dentro del Pod:

```bash
kubectl exec -n rbac-audit reader-test-pod -- \
  kubectl run test-pod --image=nginx -n rbac-audit
```

**Salida esperada (error esperado):**
```
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:rbac-audit:reader-sa" cannot create resource "pods" in API group "" in the namespace "rbac-audit"
```

> **Punto clave:** El mensaje de error muestra exactamente la identidad que Kubernetes evaluó: `system:serviceaccount:rbac-audit:reader-sa`. Esto confirma que RBAC está funcionando correctamente.

**3.6** Demuestra el acceso denegado usando `curl` directamente contra la API (método alternativo sin `kubectl`):

```bash
kubectl exec -n rbac-audit reader-test-pod -- sh -c '
  # Variables del token y CA
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
  APISERVER=https://kubernetes.default.svc

  echo "=== Intentando listar ConfigMaps (NO permitido para reader-sa) ==="
  curl -s --cacert $CA \
    -H "Authorization: Bearer $TOKEN" \
    $APISERVER/api/v1/namespaces/$NS/configmaps | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get(\"message\", d.get(\"kind\", \"OK\")))" 2>/dev/null || \
    curl -s --cacert $CA \
    -H "Authorization: Bearer $TOKEN" \
    $APISERVER/api/v1/namespaces/$NS/configmaps
'
```

**Salida esperada:**
```
=== Intentando listar ConfigMaps (NO permitido para reader-sa) ===
configmaps is forbidden: User "system:serviceaccount:rbac-audit:reader-sa" cannot list resource "configmaps" in API group "" in the namespace "rbac-audit"
```

#### Verificación

```bash
# Confirmar que el Pod usa el ServiceAccount correcto
kubectl get pod reader-test-pod -n rbac-audit \
  -o jsonpath='{.spec.serviceAccountName}'
echo ""
```

**Salida esperada:**
```
reader-sa
```

---

### Paso 4: Corrección del Escenario 1 — Permisos Insuficientes

**Objetivo:** Corregir el Role de `app-deployer-sa` para que pueda leer ConfigMaps (necesario para que la aplicación funcione), manteniendo el principio de mínimo privilegio al no otorgar permisos innecesarios.

#### Instrucciones

**4.1** Documenta el estado actual del Role roto:

```bash
kubectl describe role app-deployer-role-broken -n rbac-audit
```

**Salida esperada:**
```
Name:         app-deployer-role-broken
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [list]
```

**4.2** Confirma el problema antes de corregirlo:

```bash
echo "ANTES de la corrección:"
echo "¿Puede app-deployer-sa leer ConfigMaps?"
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit
```

**Salida esperada:**
```
ANTES de la corrección:
¿Puede app-deployer-sa leer ConfigMaps?
no
```

**4.3** Aplica la corrección creando un Role con los permisos correctos y actualizando el RoleBinding:

```bash
cat << 'EOF' > fix-app-deployer-role.yaml
# Role corregido: agrega permisos para ConfigMaps (solo get y list, no create/delete)
# Esto permite que la app lea su configuración sin permisos excesivos
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer-role-broken  # Mismo nombre para hacer patch/update
  namespace: rbac-audit
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list", "get"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
    # Solo lectura de ConfigMaps — no puede crear, actualizar ni eliminar
EOF

kubectl apply -f fix-app-deployer-role.yaml
```

**Salida esperada:**
```
role.rbac.authorization.k8s.io/app-deployer-role-broken configured
```

**4.4** Verifica la corrección:

```bash
echo "DESPUÉS de la corrección:"

echo "¿Puede app-deployer-sa leer ConfigMaps? (debe ser YES)"
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

echo "¿Puede app-deployer-sa listar ConfigMaps? (debe ser YES)"
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

echo "¿Puede app-deployer-sa CREAR ConfigMaps? (debe ser NO — mínimo privilegio)"
kubectl auth can-i create configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

echo "¿Puede app-deployer-sa ELIMINAR ConfigMaps? (debe ser NO)"
kubectl auth can-i delete configmaps \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit

echo "¿Puede app-deployer-sa crear Pods? (debe ser NO)"
kubectl auth can-i create pods \
  --as=system:serviceaccount:rbac-audit:app-deployer-sa \
  -n rbac-audit
```

**Salida esperada:**
```
DESPUÉS de la corrección:
¿Puede app-deployer-sa leer ConfigMaps? (debe ser YES)
yes
¿Puede app-deployer-sa listar ConfigMaps? (debe ser YES)
yes
¿Puede app-deployer-sa CREAR ConfigMaps? (debe ser NO — mínimo privilegio)
no
¿Puede app-deployer-sa ELIMINAR ConfigMaps? (debe ser NO)
no
¿Puede app-deployer-sa crear Pods? (debe ser NO)
no
```

**4.5** Prueba funcional: crea un Pod con `app-deployer-sa` y verifica que puede leer el ConfigMap `app-settings`:

```bash
cat << 'EOF' > pod-deployer-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: deployer-test-pod
  namespace: rbac-audit
spec:
  serviceAccountName: app-deployer-sa
  containers:
    - name: kubectl-container
      image: bitnami/kubectl:latest
      command: ["sleep", "3600"]
  restartPolicy: Never
EOF

kubectl apply -f pod-deployer-test.yaml
kubectl wait --for=condition=Ready pod/deployer-test-pod \
  -n rbac-audit --timeout=60s

# Probar acceso al ConfigMap desde dentro del Pod
kubectl exec -n rbac-audit deployer-test-pod -- \
  kubectl get configmap app-settings -n rbac-audit -o yaml
```

**Salida esperada (extracto):**
```yaml
apiVersion: v1
data:
  APP_ENV: production
  LOG_LEVEL: info
  MAX_CONNECTIONS: "100"
kind: ConfigMap
metadata:
  name: app-settings
  namespace: rbac-audit
...
```

#### Verificación

```bash
kubectl describe role app-deployer-role-broken -n rbac-audit
```

**Salida esperada:**
```
PolicyRule:
  Resources   Non-Resource URLs  Resource Names  Verbs
  ---------   -----------------  --------------  -----
  configmaps  []                 []              [get list]
  pods        []                 []              [list get]
```

---

### Paso 5: Corrección del Escenario 2 — Permisos Excesivos con Comodín

**Objetivo:** Reemplazar el Role con comodines (`*`) de `wildcard-sa` por uno que otorgue únicamente los permisos que una aplicación típica de monitoreo de pods necesitaría, demostrando la aplicación del principio de mínimo privilegio.

#### Instrucciones

**5.1** Documenta el estado actual del Role excesivo:

```bash
kubectl describe role wildcard-role-excessive -n rbac-audit
```

**Salida esperada:**
```
Name:         wildcard-role-excessive
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  *.*        []                 []              [*]
```

**5.2** Demuestra la magnitud del problema listando qué puede hacer `wildcard-sa`:

```bash
echo "=== RIESGO: wildcard-sa puede hacer TODO esto ==="

# Operaciones destructivas que NO debería poder hacer
for verb_resource in "delete:pods" "create:secrets" "delete:configmaps" "create:roles" "delete:rolebindings"; do
  verb=$(echo $verb_resource | cut -d: -f1)
  resource=$(echo $verb_resource | cut -d: -f2)
  result=$(kubectl auth can-i $verb $resource \
    --as=system:serviceaccount:rbac-audit:wildcard-sa \
    -n rbac-audit)
  echo "  kubectl $verb $resource: $result"
done
```

**Salida esperada:**
```
=== RIESGO: wildcard-sa puede hacer TODO esto ===
  kubectl delete pods: yes
  kubectl create secrets: yes
  kubectl delete configmaps: yes
  kubectl create roles: yes
  kubectl delete rolebindings: yes
```

> **Análisis de riesgo:** Un SA comprometido con estos permisos podría destruir todos los pods del namespace, leer todos los secrets, escalar privilegios creando nuevos roles, etc.

**5.3** Aplica la corrección. Asumamos que `wildcard-sa` es usado por una aplicación de monitoreo que solo necesita observar pods y leer sus logs:

```bash
cat << 'EOF' > fix-wildcard-role.yaml
# Role corregido: permisos específicos para una app de monitoreo
# Principio de mínimo privilegio: solo lo estrictamente necesario
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: wildcard-role-excessive  # Mismo nombre — sobrescribe el existente
  namespace: rbac-audit
rules:
  # Permiso 1: Solo observar pods (leer estado, no modificar)
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  # Permiso 2: Leer logs de pods (necesario para monitoreo)
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
  # Permiso 3: Leer eventos del namespace (para alertas)
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
  # ELIMINADO: Todo lo demás — sin crear, eliminar, modificar nada
EOF

kubectl apply -f fix-wildcard-role.yaml
```

**Salida esperada:**
```
role.rbac.authorization.k8s.io/wildcard-role-excessive configured
```

**5.4** Verifica que los permisos excesivos han sido eliminados:

```bash
echo "=== VERIFICACIÓN POST-CORRECCIÓN: wildcard-sa ==="

echo "¿Puede listar pods? (debe ser YES — necesario para monitoreo)"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

echo "¿Puede leer logs? (debe ser YES)"
kubectl auth can-i get pods/log \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

echo "¿Puede ELIMINAR pods? (debe ser NO)"
kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

echo "¿Puede crear Secrets? (debe ser NO)"
kubectl auth can-i create secrets \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

echo "¿Puede crear Roles? (debe ser NO)"
kubectl auth can-i create roles \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit

echo "¿Puede hacer TODO (*)? (debe ser NO)"
kubectl auth can-i '*' '*' \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit
```

**Salida esperada:**
```
=== VERIFICACIÓN POST-CORRECCIÓN: wildcard-sa ===
¿Puede listar pods? (debe ser YES — necesario para monitoreo)
yes
¿Puede leer logs? (debe ser YES)
yes
¿Puede ELIMINAR pods? (debe ser NO)
no
¿Puede crear Secrets? (debe ser NO)
no
¿Puede crear Roles? (debe ser NO)
no
¿Puede hacer TODO (*)? (debe ser NO)
no
```

**5.5** Verifica el Role resultante:

```bash
kubectl describe role wildcard-role-excessive -n rbac-audit
```

**Salida esperada:**
```
Name:         wildcard-role-excessive
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  events     []                 []              [get list watch]
  pods/log   []                 []              [get]
  pods       []                 []              [get list watch]
```

#### Verificación

```bash
# Inventario final de permisos del wildcard-sa corregido
kubectl auth can-i --list \
  --as=system:serviceaccount:rbac-audit:wildcard-sa \
  -n rbac-audit
```

La salida debe mostrar únicamente los tres recursos configurados (`pods`, `pods/log`, `events`) con verbos limitados — no debe aparecer ninguna línea con `[*]`.

---

## 7. Validación y Pruebas Finales

Ejecuta esta batería de verificación completa para confirmar que todos los escenarios han sido resueltos correctamente:

```bash
#!/bin/bash
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       VALIDACIÓN FINAL — Lab 05-00-02                   ║"
echo "╚══════════════════════════════════════════════════════════╝"

PASS=0
FAIL=0
NS="rbac-audit"

check() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $desc (esperado: $expected, obtenido: $actual)"
    FAIL=$((FAIL+1))
  fi
}

echo ""
echo "── reader-sa (configuración correcta) ──"
check "reader-sa puede listar pods" "yes" \
  "$(kubectl auth can-i list pods --as=system:serviceaccount:$NS:reader-sa -n $NS)"
check "reader-sa NO puede crear pods" "no" \
  "$(kubectl auth can-i create pods --as=system:serviceaccount:$NS:reader-sa -n $NS)"
check "reader-sa NO puede leer configmaps" "no" \
  "$(kubectl auth can-i get configmaps --as=system:serviceaccount:$NS:reader-sa -n $NS)"

echo ""
echo "── app-deployer-sa (permisos insuficientes — CORREGIDO) ──"
check "app-deployer-sa AHORA puede leer configmaps" "yes" \
  "$(kubectl auth can-i get configmaps --as=system:serviceaccount:$NS:app-deployer-sa -n $NS)"
check "app-deployer-sa AHORA puede listar configmaps" "yes" \
  "$(kubectl auth can-i list configmaps --as=system:serviceaccount:$NS:app-deployer-sa -n $NS)"
check "app-deployer-sa NO puede crear configmaps" "no" \
  "$(kubectl auth can-i create configmaps --as=system:serviceaccount:$NS:app-deployer-sa -n $NS)"
check "app-deployer-sa NO puede eliminar configmaps" "no" \
  "$(kubectl auth can-i delete configmaps --as=system:serviceaccount:$NS:app-deployer-sa -n $NS)"

echo ""
echo "── wildcard-sa (permisos excesivos — CORREGIDO) ──"
check "wildcard-sa puede listar pods" "yes" \
  "$(kubectl auth can-i list pods --as=system:serviceaccount:$NS:wildcard-sa -n $NS)"
check "wildcard-sa NO puede eliminar pods" "no" \
  "$(kubectl auth can-i delete pods --as=system:serviceaccount:$NS:wildcard-sa -n $NS)"
check "wildcard-sa NO puede crear secrets" "no" \
  "$(kubectl auth can-i create secrets --as=system:serviceaccount:$NS:wildcard-sa -n $NS)"
check "wildcard-sa NO tiene permisos wildcard" "no" \
  "$(kubectl auth can-i '*' '*' --as=system:serviceaccount:$NS:wildcard-sa -n $NS)"

echo ""
echo "── Prueba funcional desde Pod ──"
POD_SA=$(kubectl get pod reader-test-pod -n $NS \
  -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
check "reader-test-pod usa reader-sa" "reader-sa" "$POD_SA"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  RESULTADO: $PASS pruebas pasadas, $FAIL pruebas fallidas"
echo "══════════════════════════════════════════════════════════"
```

**Salida esperada al completar el laboratorio correctamente:**
```
══════════════════════════════════════════════════════════
  RESULTADO: 11 pruebas pasadas, 0 pruebas fallidas
══════════════════════════════════════════════════════════
```

---

## 8. Resolución de Problemas

### Problema 1: `kubectl auth can-i --as` devuelve error de autorización

**Síntomas:**
```
Error from server (Forbidden): selfsubjectaccessreviews.authorization.k8s.io is forbidden:
User "..." cannot create resource "selfsubjectaccessreviews" in API group
"authorization.k8s.io" at the cluster scope
```
O bien:
```
error: user "system:serviceaccount:rbac-audit:reader-sa" cannot impersonate
resource "serviceaccounts" in API group "" at the cluster scope
```

**Causa:** El usuario que ejecuta `kubectl auth can-i --as` no tiene permisos de **impersonación** en el clúster. En un clúster Minikube con el contexto `minikube`, esto normalmente no ocurre porque el usuario por defecto es `cluster-admin`. Si aparece este error, el contexto activo no tiene permisos suficientes.

**Solución:**

```bash
# 1. Verificar el contexto actual
kubectl config current-context

# 2. Asegurarse de estar usando el contexto de minikube (admin)
kubectl config use-context minikube

# 3. Verificar que tienes permisos de impersonación
kubectl auth can-i impersonate serviceaccounts --all-namespaces

# 4. Si el problema persiste, verificar que el usuario actual es cluster-admin
kubectl get clusterrolebinding cluster-admin -o yaml | grep -A5 subjects
```

---

### Problema 2: El Pod con ServiceAccount no puede ejecutar `kubectl` — imagen no disponible o error `exec`

**Síntomas:**
```
Error from server: error dialing backend: dial tcp: lookup <node-ip>: no such host
```
O bien:
```
error: unable to upgrade connection: container not found ("kubectl-container")
```
O bien, el Pod queda en estado `ErrImagePull` o `ImagePullBackOff`.

**Causa:** Hay dos causas posibles:
1. La imagen `bitnami/kubectl:latest` no se pudo descargar (conectividad limitada o el registro está lento).
2. El Pod no llegó al estado `Running` antes de intentar el `kubectl exec`, por lo que el contenedor no existe aún.

**Solución:**

```bash
# Opción A: Si el Pod está en ImagePullBackOff, pre-descarga la imagen en Minikube
minikube ssh -- docker pull bitnami/kubectl:latest

# Opción B: Usa una imagen alternativa que incluya curl y sh (siempre disponible)
# Modifica el manifiesto del pod para usar busybox y acceder a la API con curl:
cat << 'EOF' > pod-reader-test-alt.yaml
apiVersion: v1
kind: Pod
metadata:
  name: reader-test-pod-alt
  namespace: rbac-audit
spec:
  serviceAccountName: reader-sa
  containers:
    - name: curl-container
      image: curlimages/curl:latest
      command: ["sleep", "3600"]
  restartPolicy: Never
EOF
kubectl apply -f pod-reader-test-alt.yaml

# Opción C: Verificar el estado del Pod antes de hacer exec
kubectl get pod reader-test-pod -n rbac-audit -w
# Esperar hasta que el STATUS sea "Running" antes de continuar

# Opción D: Si el Pod ya terminó (Completed/Error), verificar logs
kubectl logs reader-test-pod -n rbac-audit
kubectl describe pod reader-test-pod -n rbac-audit | grep -A10 Events
```

---

## 9. Limpieza del Entorno

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
echo "=== Iniciando limpieza del Lab 05-00-02 ==="

# 1. Eliminar los Pods de prueba
kubectl delete pod reader-test-pod deployer-test-pod \
  -n rbac-audit \
  --ignore-not-found=true

# 2. Eliminar los manifiestos locales
rm -f rbac-audit-setup.yaml \
      pod-reader-test.yaml \
      pod-deployer-test.yaml \
      fix-app-deployer-role.yaml \
      fix-wildcard-role.yaml \
      pod-reader-test-alt.yaml

# 3. Eliminar el namespace completo (esto elimina TODOS los recursos dentro)
kubectl delete namespace rbac-audit

echo "=== Limpieza completada ==="
```

**Salida esperada:**
```
pod "reader-test-pod" deleted
pod "deployer-test-pod" deleted
namespace "rbac-audit" deleted
=== Limpieza completada ===
```

> **Nota:** Si los recursos del Lab 05-00-01 están en un namespace diferente (p. ej. `rbac-lab`), no se verán afectados por esta limpieza.

---

## 10. Resumen

### Conceptos Aplicados

En este laboratorio aplicaste un flujo completo de **auditoría y corrección de RBAC** en Kubernetes:

| Técnica | Comando/Recurso | Propósito |
|---|---|---|
| Auditoría sin ejecución | `kubectl auth can-i --as` | Verificar permisos sin crear Pods |
| Inventario de permisos | `kubectl auth can-i --list --as` | Listar todos los permisos de un SA |
| Token montado | `/var/run/secrets/kubernetes.io/serviceaccount/` | Autenticación real desde Pod |
| Acceso API desde Pod | `kubectl exec` + `kubectl` interno | Demostrar acceso real a la API |
| Corrección de Role | `kubectl apply` con YAML actualizado | Parchar permisos insuficientes |
| Mínimo privilegio | Verbos explícitos en lugar de `*` | Reducir superficie de ataque |

### Principios Clave Demostrados

1. **`kubectl auth can-i --as`** es la herramienta de auditoría más eficiente para RBAC: permite verificar permisos sin crear ni ejecutar Pods, y debe ser el primer paso en cualquier investigación de acceso.

2. **El token de ServiceAccount** montado automáticamente en `/var/run/secrets/kubernetes.io/serviceaccount/token` es el mecanismo real de autenticación que usan las aplicaciones dentro de los Pods para comunicarse con la API de Kubernetes.

3. **Los permisos insuficientes** causan errores 403 Forbidden en tiempo de ejecución, que pueden manifestarse como fallos de aplicación difíciles de diagnosticar si no se conoce RBAC. La corrección es agregar solo los verbos y recursos estrictamente necesarios.

4. **Los comodines (`*`)** en Roles son una señal de alerta de seguridad. Siempre deben reemplazarse con permisos explícitos y granulares, siguiendo el principio de mínimo privilegio.

5. **La conexión con ConfigMaps** (tema de la Lección 5.1) es directa: si una aplicación necesita leer ConfigMaps mediante la API de Kubernetes (en lugar de montarlos como volumen), su ServiceAccount debe tener explícitamente `get` y `list` sobre `configmaps` en el Role correspondiente.

### Recursos Adicionales

- [Documentación oficial: Autorización RBAC en Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [kubectl auth can-i — Referencia de comandos](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#auth)
- [ServiceAccount tokens — Proyección y montaje automático](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Principio de mínimo privilegio en Kubernetes](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [Kubernetes API accedida desde un Pod](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/)

---
