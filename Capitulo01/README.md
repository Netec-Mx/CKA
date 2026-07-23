# Despliegue de una aplicación Node.js en Kubernetes

## Metadatos

| Campo         | Detalle                          |
|---------------|----------------------------------|
| **Duración**  | 67 minutos                       |
| **Complejidad** | Media                          |
| **Nivel Bloom** | Crear (Create)                 |
| **Módulo**    | 1 — Fundamentos de Kubernetes    |
| **Lab ID**    | 01-00-01                         |

---

## Descripción General

En este laboratorio pondrás en práctica los conceptos introducidos en la Lección 1.1 sobre orquestación de contenedores con Kubernetes. Partirás de una aplicación Node.js simple, construirás su imagen Docker, la cargarás en el entorno de Minikube y crearás los manifiestos YAML necesarios para desplegarla como un `Deployment` con 2 réplicas expuesto mediante un `Service` de tipo `NodePort`. Al finalizar, habrás completado el flujo completo de despliegue —desde el código fuente hasta el acceso a la aplicación en ejecución— y habrás explorado los componentes reales del clúster usando `kubectl`.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Identificar los componentes del control plane y los worker nodes de un clúster Minikube usando comandos `kubectl` de inspección.
- [ ] Construir una imagen Docker de una aplicación Node.js y cargarla en el entorno de Minikube.
- [ ] Crear manifiestos YAML válidos para un `Deployment` y un `Service` de tipo `NodePort`, comprendiendo cada campo de la especificación.
- [ ] Desplegar la aplicación en Kubernetes usando `kubectl apply` y verificar su estado con comandos de inspección.
- [ ] Acceder a la aplicación desplegada desde el navegador o `curl` usando la URL proporcionada por `minikube service`.

---

## Prerrequisitos

### Conocimientos previos
- Manejo básico de la línea de comandos en Linux/macOS (navegación de directorios, edición de archivos).
- Comprensión básica de Docker: qué es una imagen, qué es un contenedor, comandos `docker build` y `docker run`.
- Lectura básica de archivos YAML (indentación con espacios, listas con `-`, mapas clave-valor).
- Haber revisado la Lección 1.1: *¿Qué es Kubernetes?*

### Acceso y software requerido

| Herramienta   | Versión mínima | Verificación                        |
|---------------|----------------|-------------------------------------|
| `kubectl`     | 1.28.x         | `kubectl version --client`          |
| Minikube      | 1.31.x         | `minikube version`                  |
| Docker Engine | 24.x           | `docker --version`                  |
| Node.js       | 18.x LTS       | `node --version` *(solo referencia)*|
| `curl`        | 7.x            | `curl --version`                    |

---

## Entorno de Laboratorio

### Recursos de hardware recomendados

| Recurso    | Mínimo     | Recomendado |
|------------|------------|-------------|
| CPU        | 4 núcleos  | 8 núcleos   |
| RAM        | 8 GB       | 16 GB       |
| Disco      | 40 GB libres | 60 GB SSD |

### Configuración inicial del clúster

Este laboratorio funciona con un nodo, pero se recomienda iniciar Minikube con 3 nodos desde el principio para reutilizar el clúster en laboratorios posteriores.

```bash
# Opción A — Clúster de 3 nodos (recomendado para el curso completo)
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Opción B — Nodo único (suficiente para este laboratorio)
minikube start --driver=docker --cpus=2 --memory=2048
```

> **Nota para macOS/Windows con WSL2:** Al usar el driver Docker, el acceso a servicios NodePort requiere el comando `minikube service <nombre> --url` en lugar de la IP directa del nodo. Este laboratorio utiliza ese comando, por lo que el procedimiento es compatible con todas las plataformas.

### Pre-descarga de imágenes (entornos con conectividad limitada)

```bash
# Pre-descargar imágenes necesarias para este laboratorio
for img in node:18-alpine nginx:1.25 busybox:latest; do
  docker pull $img
done
```

---

## Pasos del Laboratorio

### Paso 1 — Exploración de la arquitectura del clúster

**Objetivo:** Identificar los componentes reales del clúster Kubernetes usando comandos de inspección, conectando la teoría de la Lección 1.1 con la práctica.

**Tiempo estimado:** 10 minutos

#### Instrucciones

1. Verifica que Minikube esté en ejecución y lista los nodos disponibles:

```bash
kubectl get nodes
```

2. Examina el detalle del nodo control plane. Sustituye `minikube` por el nombre real del nodo si usaste `--nodes=3`:

```bash
kubectl describe node minikube
```

Busca en la salida las secciones `Roles`, `Conditions`, `Capacity` y `Allocated resources`. Observa cómo Kubernetes reporta el estado del nodo.

3. Consulta la información general del clúster:

```bash
kubectl cluster-info
```

4. Lista los componentes del sistema de Kubernetes que se ejecutan como Pods en el namespace `kube-system`:

```bash
kubectl get pods -n kube-system
```

5. Examina el estado de los componentes del control plane:

```bash
kubectl get componentstatuses
```

> **Nota:** En versiones de Kubernetes ≥ 1.19, `componentstatuses` puede mostrar advertencias de deprecación. La información sigue siendo válida para propósitos de aprendizaje.

6. Si iniciaste con 3 nodos, lista todos los nodos y observa sus roles:

```bash
kubectl get nodes -o wide
```

#### Salida esperada — `kubectl get nodes`

```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   2m    v1.28.3
minikube-m02   Ready    <none>          90s   v1.28.3
minikube-m03   Ready    <none>          75s   v1.28.3
```

#### Salida esperada — `kubectl cluster-info`

```
Kubernetes control plane is running at https://127.0.0.1:PORT
CoreDNS is running at https://127.0.0.1:PORT/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

#### Verificación

Confirma que todos los nodos muestran estado `Ready` y que el control plane está accesible. Si algún nodo muestra `NotReady`, espera 60 segundos y vuelve a ejecutar `kubectl get nodes`.

---

### Paso 2 — Creación del código fuente de la aplicación Node.js

**Objetivo:** Preparar el código fuente de la aplicación y el `Dockerfile` necesarios para construir la imagen del contenedor.

**Tiempo estimado:** 8 minutos

#### Instrucciones

1. Crea un directorio de trabajo para el laboratorio:

```bash
mkdir -p ~/k8s-lab-01 && cd ~/k8s-lab-01
```

2. Crea el archivo principal de la aplicación Node.js:

```bash
cat > app.js << 'EOF'
const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const response = {
    message: 'Hola desde Kubernetes',
    hostname: os.hostname(),       // Nombre del Pod (útil para ver el balanceo)
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  };

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(response, null, 2));
});

server.listen(PORT, () => {
  console.log(`Servidor escuchando en el puerto ${PORT}`);
  console.log(`Hostname: ${os.hostname()}`);
});
EOF
```

3. Crea el archivo `package.json`:

```bash
cat > package.json << 'EOF'
{
  "name": "k8s-node-app",
  "version": "1.0.0",
  "description": "Aplicación Node.js de ejemplo para Kubernetes",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
```

4. Crea el `Dockerfile`:

```bash
cat > Dockerfile << 'EOF'
# Imagen base oficial de Node.js (Alpine = imagen mínima)
FROM node:18-alpine

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar archivos de dependencias primero (optimización de capas Docker)
COPY package.json ./

# Instalar dependencias de producción
RUN npm install --omit=dev

# Copiar el código fuente de la aplicación
COPY app.js ./

# Puerto que expone la aplicación
EXPOSE 3000

# Usuario no-root por seguridad
USER node

# Comando de inicio
CMD ["node", "app.js"]
EOF
```

5. Crea un archivo `.dockerignore` para excluir archivos innecesarios:

```bash
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
*.md
EOF
```

6. Verifica la estructura del directorio:

```bash
ls -la ~/k8s-lab-01/
```

#### Salida esperada

```
total 24
drwxr-xr-x  2 usuario usuario 4096 ...
-rw-r--r--  1 usuario usuario  ...  .dockerignore
-rw-r--r--  1 usuario usuario  ...  Dockerfile
-rw-r--r--  1 usuario usuario  ...  app.js
-rw-r--r--  1 usuario usuario  ...  package.json
```

#### Verificación

Asegúrate de que los cuatro archivos (`app.js`, `package.json`, `Dockerfile`, `.dockerignore`) existen en el directorio `~/k8s-lab-01/`.

---

### Paso 3 — Construcción de la imagen Docker en el entorno de Minikube

**Objetivo:** Construir la imagen Docker directamente dentro del daemon de Docker de Minikube para que esté disponible sin necesidad de un registro externo.

**Tiempo estimado:** 10 minutos

#### Instrucciones

1. Configura el shell para usar el daemon Docker de Minikube. **Este paso es fundamental:** si construyes la imagen con el Docker del host, Kubernetes no podrá encontrarla.

```bash
# Configura las variables de entorno para apuntar al Docker de Minikube
eval $(minikube docker-env)

# Verifica que ahora apuntas al Docker de Minikube
docker info | grep "Name:"
```

La salida debe mostrar el nombre del nodo de Minikube, no el host local.

2. Construye la imagen Docker con la etiqueta `k8s-node-app:1.0.0`:

```bash
cd ~/k8s-lab-01
docker build -t k8s-node-app:1.0.0 .
```

3. Verifica que la imagen fue construida correctamente:

```bash
docker images | grep k8s-node-app
```

4. Realiza una prueba local del contenedor antes de desplegarlo en Kubernetes:

```bash
# Ejecuta el contenedor localmente
docker run --rm -d --name test-app -p 3000:3000 k8s-node-app:1.0.0

# Espera 2 segundos y prueba la respuesta
sleep 2
curl http://localhost:3000

# Detén el contenedor de prueba
docker stop test-app
```

#### Salida esperada — `docker images`

```
REPOSITORY      TAG       IMAGE ID       CREATED          SIZE
k8s-node-app    1.0.0     abc123def456   30 seconds ago   ~130MB
```

#### Salida esperada — `curl http://localhost:3000`

```json
{
  "message": "Hola desde Kubernetes",
  "hostname": "test-app-container-id",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0"
}
```

#### Verificación

La imagen debe aparecer en `docker images` y el contenedor de prueba debe responder con el JSON esperado. Si `curl` no devuelve respuesta, revisa los logs con `docker logs test-app`.

> **Importante:** La sesión de terminal donde ejecutaste `eval $(minikube docker-env)` tiene las variables configuradas. Si abres una terminal nueva, debes ejecutar ese comando nuevamente.

---

### Paso 4 — Creación del manifiesto YAML del Deployment

**Objetivo:** Crear un manifiesto YAML válido para un `Deployment` de Kubernetes con 2 réplicas, comprendiendo el propósito de cada campo.

**Tiempo estimado:** 12 minutos

#### Instrucciones

1. Crea el directorio para los manifiestos Kubernetes:

```bash
mkdir -p ~/k8s-lab-01/k8s
```

2. Crea el manifiesto del `Deployment`:

```bash
cat > ~/k8s-lab-01/k8s/deployment.yaml << 'EOF'
# ============================================================
# Deployment: k8s-node-app
# Descripción: Despliega la aplicación Node.js con 2 réplicas
# ============================================================
apiVersion: apps/v1        # API group para Deployments
kind: Deployment           # Tipo de recurso Kubernetes
metadata:
  name: k8s-node-app       # Nombre único del Deployment en el clúster
  labels:
    app: k8s-node-app      # Etiqueta para identificar este recurso
    version: "1.0.0"
spec:
  replicas: 2              # Kubernetes mantendrá SIEMPRE 2 Pods activos

  # El selector define qué Pods gestiona este Deployment
  selector:
    matchLabels:
      app: k8s-node-app    # Debe coincidir con las etiquetas del template

  # Estrategia de actualización (RollingUpdate es el valor por defecto)
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # Máximo 1 Pod adicional durante la actualización
      maxUnavailable: 0    # Cero Pods no disponibles durante la actualización

  # Template: la "plantilla" usada para crear cada Pod
  template:
    metadata:
      labels:
        app: k8s-node-app  # DEBE coincidir con selector.matchLabels
        version: "1.0.0"
    spec:
      containers:
        - name: k8s-node-app          # Nombre del contenedor dentro del Pod
          image: k8s-node-app:1.0.0   # Imagen construida en el paso anterior
          imagePullPolicy: Never      # Usar imagen local (no buscar en registry)
          ports:
            - containerPort: 3000     # Puerto que expone el contenedor
              protocol: TCP
          env:
            - name: PORT
              value: "3000"           # Variable de entorno para la app
          resources:
            requests:
              memory: "64Mi"          # Memoria mínima garantizada
              cpu: "50m"              # 50 millicores de CPU garantizados
            limits:
              memory: "128Mi"         # Memoria máxima permitida
              cpu: "100m"             # 100 millicores máximo
          # Health checks: Kubernetes verifica que el contenedor está vivo
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 10   # Espera 10s antes del primer check
            periodSeconds: 15         # Verifica cada 15 segundos
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 5    # Espera 5s antes de declarar "listo"
            periodSeconds: 10
EOF
```

3. Valida la sintaxis del YAML antes de aplicarlo:

```bash
kubectl apply --dry-run=client -f ~/k8s-lab-01/k8s/deployment.yaml
```

#### Salida esperada — `dry-run`

```
deployment.apps/k8s-node-app created (dry run)
```

#### Verificación

Si el comando `dry-run` devuelve un error de validación, revisa la indentación del archivo YAML. Recuerda que YAML usa **espacios** (no tabulaciones). Cada nivel de indentación debe ser consistente (2 espacios recomendado).

> **Análisis del manifiesto:** Observa la estructura de cuatro secciones fundamentales presentes en todo recurso Kubernetes:
> - `apiVersion` + `kind`: identifican el tipo de recurso y la versión de la API.
> - `metadata`: nombre, namespace y etiquetas del recurso.
> - `spec`: la declaración del estado deseado — el corazón del modelo declarativo de Kubernetes.
> - `status`: (gestionado por Kubernetes, no se escribe manualmente) — el estado actual real.

---

### Paso 5 — Creación del manifiesto YAML del Service

**Objetivo:** Crear un `Service` de tipo `NodePort` que exponga la aplicación fuera del clúster.

**Tiempo estimado:** 7 minutos

#### Instrucciones

1. Crea el manifiesto del `Service`:

```bash
cat > ~/k8s-lab-01/k8s/service.yaml << 'EOF'
# ============================================================
# Service: k8s-node-app-service
# Descripción: Expone el Deployment mediante NodePort
# ============================================================
apiVersion: v1             # API core (sin group prefix) para Services
kind: Service
metadata:
  name: k8s-node-app-service
  labels:
    app: k8s-node-app
spec:
  # El selector conecta el Service con los Pods correctos
  # Kubernetes enviará tráfico a los Pods que tengan esta etiqueta
  selector:
    app: k8s-node-app      # Debe coincidir con las etiquetas del Pod template

  type: NodePort           # Expone el servicio en un puerto del nodo

  ports:
    - name: http
      protocol: TCP
      port: 80             # Puerto del Service (dentro del clúster)
      targetPort: 3000     # Puerto del contenedor al que reenviar el tráfico
      nodePort: 30080      # Puerto en el nodo (rango: 30000-32767)
EOF
```

2. Valida la sintaxis:

```bash
kubectl apply --dry-run=client -f ~/k8s-lab-01/k8s/service.yaml
```

3. Revisa la estructura final de los manifiestos:

```bash
ls -la ~/k8s-lab-01/k8s/
cat ~/k8s-lab-01/k8s/deployment.yaml
cat ~/k8s-lab-01/k8s/service.yaml
```

#### Salida esperada — `dry-run`

```
service/k8s-node-app-service created (dry run)
```

#### Verificación

Ambos manifiestos deben pasar la validación `dry-run` sin errores. Verifica que el campo `selector` del Service (`app: k8s-node-app`) coincide **exactamente** con las etiquetas del `template` en el Deployment. Esta coincidencia es el mecanismo por el cual Kubernetes conecta el tráfico del Service con los Pods correctos.

---

### Paso 6 — Despliegue de la aplicación en Kubernetes

**Objetivo:** Aplicar los manifiestos YAML al clúster y verificar que el Deployment y los Pods se crean correctamente.

**Tiempo estimado:** 10 minutos

#### Instrucciones

1. Aplica ambos manifiestos al clúster:

```bash
# Opción A: Aplicar el directorio completo (recomendado)
kubectl apply -f ~/k8s-lab-01/k8s/

# Opción B: Aplicar archivo por archivo
# kubectl apply -f ~/k8s-lab-01/k8s/deployment.yaml
# kubectl apply -f ~/k8s-lab-01/k8s/service.yaml
```

2. Observa el proceso de creación de los Pods en tiempo real:

```bash
kubectl get pods -w
```

Espera hasta que ambos Pods muestren estado `Running` y `READY 1/1`. Presiona `Ctrl+C` para salir del modo watch.

3. Verifica el estado del Deployment:

```bash
kubectl get deployment k8s-node-app
```

4. Verifica el estado del ReplicaSet (creado automáticamente por el Deployment):

```bash
kubectl get replicaset
```

5. Verifica el Service:

```bash
kubectl get service k8s-node-app-service
```

6. Obtén una vista completa de todos los recursos creados:

```bash
kubectl get all -l app=k8s-node-app
```

7. Examina el detalle del Deployment:

```bash
kubectl describe deployment k8s-node-app
```

Busca en la salida la sección `Events` para ver el historial de acciones que Kubernetes realizó para alcanzar el estado deseado.

8. Examina el detalle de uno de los Pods:

```bash
# Obtén el nombre exacto de un Pod
POD_NAME=$(kubectl get pods -l app=k8s-node-app -o jsonpath='{.items[0].metadata.name}')
echo "Pod seleccionado: $POD_NAME"

kubectl describe pod $POD_NAME
```

#### Salida esperada — `kubectl get pods`

```
NAME                            READY   STATUS    RESTARTS   AGE
k8s-node-app-7d4b9c8f6-abc12    1/1     Running   0          45s
k8s-node-app-7d4b9c8f6-def34    1/1     Running   0          45s
```

#### Salida esperada — `kubectl get deployment`

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
k8s-node-app   2/2     2            2           60s
```

#### Salida esperada — `kubectl get service`

```
NAME                    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
k8s-node-app-service    NodePort   10.96.xxx.xxx   <none>        80:30080/TCP   60s
```

#### Verificación

- El Deployment debe mostrar `READY 2/2`.
- Ambos Pods deben estar en estado `Running` con `READY 1/1`.
- El Service debe mostrar el mapeo de puertos `80:30080/TCP`.

Si los Pods muestran `CrashLoopBackOff` o `ImagePullBackOff`, consulta la sección de Troubleshooting.

---

### Paso 7 — Acceso a la aplicación y validación del balanceo de carga

**Objetivo:** Acceder a la aplicación desplegada usando `minikube service` y verificar el balanceo de carga entre los Pods.

**Tiempo estimado:** 10 minutos

#### Instrucciones

1. Obtén la URL de acceso al servicio usando Minikube:

```bash
minikube service k8s-node-app-service --url
```

Este comando devuelve la URL correcta independientemente de la plataforma (Linux, macOS, Windows/WSL2).

2. Asigna la URL a una variable para facilitar las pruebas:

```bash
APP_URL=$(minikube service k8s-node-app-service --url)
echo "URL de la aplicación: $APP_URL"
```

3. Realiza una solicitud HTTP a la aplicación:

```bash
curl $APP_URL
```

4. Realiza múltiples solicitudes para observar el balanceo de carga entre los dos Pods. Observa el campo `hostname` — debería alternar entre los nombres de los dos Pods:

```bash
# Ejecuta 6 solicitudes y muestra solo el hostname de cada respuesta
for i in {1..6}; do
  echo "Solicitud $i:"
  curl -s $APP_URL | grep hostname
  echo "---"
done
```

5. Verifica los logs de ambos Pods para confirmar que están recibiendo tráfico:

```bash
# Logs del primer Pod
kubectl logs -l app=k8s-node-app --prefix=true
```

6. Ejecuta un comando interactivo dentro de uno de los Pods para explorar el entorno:

```bash
POD_NAME=$(kubectl get pods -l app=k8s-node-app -o jsonpath='{.items[0].metadata.name}')

# Ejecuta un shell dentro del Pod
kubectl exec -it $POD_NAME -- sh

# Dentro del Pod, ejecuta:
# hostname
# env | grep PORT
# wget -qO- http://localhost:3000
# exit
```

#### Salida esperada — `curl $APP_URL`

```json
{
  "message": "Hola desde Kubernetes",
  "hostname": "k8s-node-app-7d4b9c8f6-abc12",
  "timestamp": "2024-01-15T10:35:22.000Z",
  "version": "1.0.0"
}
```

#### Salida esperada — Múltiples solicitudes (balanceo de carga)

```
Solicitud 1:
  "hostname": "k8s-node-app-7d4b9c8f6-abc12",
---
Solicitud 2:
  "hostname": "k8s-node-app-7d4b9c8f6-def34",
---
Solicitud 3:
  "hostname": "k8s-node-app-7d4b9c8f6-abc12",
---
```

> **Observación clave:** El campo `hostname` en la respuesta JSON corresponde al nombre del Pod que procesó la solicitud. Esto ilustra en tiempo real cómo el Service de Kubernetes actúa como balanceador de carga, distribuyendo las solicitudes entre los Pods disponibles — exactamente el comportamiento que Kubernetes automatiza según la Lección 1.1.

#### Verificación

La aplicación debe responder con el JSON completo. Si el `hostname` no varía entre solicitudes, es normal: el balanceo de carga de Kubernetes no garantiza alternancia estricta (round-robin), sino distribución probabilística.

---

## Validación y Pruebas

Ejecuta las siguientes verificaciones para confirmar que el laboratorio se completó correctamente:

```bash
echo "=== VALIDACIÓN DEL LABORATORIO 01-00-01 ==="
echo ""

echo "1. Nodos del clúster:"
kubectl get nodes
echo ""

echo "2. Estado del Deployment:"
kubectl get deployment k8s-node-app
echo ""

echo "3. Estado de los Pods:"
kubectl get pods -l app=k8s-node-app
echo ""

echo "4. Estado del Service:"
kubectl get service k8s-node-app-service
echo ""

echo "5. ReplicaSet creado automáticamente:"
kubectl get replicaset -l app=k8s-node-app
echo ""

echo "6. Prueba de conectividad:"
APP_URL=$(minikube service k8s-node-app-service --url)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $APP_URL)
echo "Código HTTP recibido: $HTTP_CODE (esperado: 200)"
echo ""

echo "7. Respuesta completa de la aplicación:"
curl -s $APP_URL | python3 -m json.tool 2>/dev/null || curl -s $APP_URL
echo ""

echo "=== FIN DE VALIDACIÓN ==="
```

**Criterios de éxito:**

| Criterio                               | Estado esperado       |
|----------------------------------------|-----------------------|
| Nodos en estado `Ready`                | ✅ Todos `Ready`      |
| Deployment `READY`                     | ✅ `2/2`              |
| Pods en estado `Running`               | ✅ `1/1` ambos        |
| Service tipo `NodePort`                | ✅ `80:30080/TCP`     |
| Código HTTP de la aplicación           | ✅ `200`              |
| Campo `message` en la respuesta JSON   | ✅ `"Hola desde Kubernetes"` |

---

## Troubleshooting

### Problema 1: Los Pods muestran estado `ImagePullBackOff` o `ErrImageNeverPull`

**Síntomas:**
```
NAME                            READY   STATUS             RESTARTS   AGE
k8s-node-app-7d4b9c8f6-abc12    0/1     ImagePullBackOff   0          30s
```

**Causa:**
La imagen `k8s-node-app:1.0.0` fue construida con el Docker del host, pero Kubernetes (dentro de Minikube) usa su propio daemon Docker y no tiene acceso a las imágenes del host. Esto ocurre cuando se omite el comando `eval $(minikube docker-env)` antes de ejecutar `docker build`.

**Solución:**

```bash
# Paso 1: Configura el entorno Docker de Minikube en la terminal actual
eval $(minikube docker-env)

# Paso 2: Verifica que apuntas al Docker de Minikube
docker info | grep "Name:"
# La salida debe mostrar el nombre del nodo Minikube, NO el host

# Paso 3: Reconstruye la imagen en el contexto correcto
cd ~/k8s-lab-01
docker build -t k8s-node-app:1.0.0 .

# Paso 4: Verifica que la imagen existe en el contexto de Minikube
docker images | grep k8s-node-app

# Paso 5: Fuerza la recreación de los Pods
kubectl rollout restart deployment k8s-node-app

# Paso 6: Monitorea el estado
kubectl get pods -w
```

**Verificación adicional:** Confirma que el campo `imagePullPolicy: Never` está presente en el manifiesto del Deployment. Este campo indica a Kubernetes que **nunca** intente descargar la imagen de un registry externo y que use exclusivamente la imagen local.

---

### Problema 2: `minikube service` no devuelve URL o la aplicación no responde

**Síntomas:**
```bash
$ minikube service k8s-node-app-service --url
# No devuelve output, o devuelve una URL que no responde con curl
```

**Causa:**
En entornos macOS o Windows con WSL2 usando el driver Docker, el acceso directo a la IP del nodo no funciona porque la red de Docker está aislada del host. Adicionalmente, el Service puede no estar correctamente configurado si el selector no coincide con las etiquetas de los Pods.

**Solución:**

```bash
# Paso 1: Verifica que el Service existe y tiene el selector correcto
kubectl get service k8s-node-app-service -o yaml | grep -A 3 "selector:"

# Paso 2: Verifica que los Pods tienen las etiquetas correctas
kubectl get pods -l app=k8s-node-app --show-labels

# Paso 3: Verifica los Endpoints del Service (debe listar las IPs de los Pods)
kubectl get endpoints k8s-node-app-service
# Si muestra "<none>" en ENDPOINTS, el selector no coincide con las etiquetas

# Paso 4: En macOS/Windows, usa minikube service en modo túnel
minikube service k8s-node-app-service --url
# Copia la URL completa y úsala con curl

# Paso 5: Alternativa — usa port-forward para pruebas locales
kubectl port-forward service/k8s-node-app-service 8080:80 &
curl http://localhost:8080
# Ctrl+C para detener el port-forward cuando termines

# Paso 6: Si los Endpoints están vacíos, corrige el selector en service.yaml
# Asegúrate que spec.selector.app: k8s-node-app coincide exactamente
# con metadata.labels.app: k8s-node-app en el template del Deployment
kubectl apply -f ~/k8s-lab-01/k8s/service.yaml
```

**Verificación:** `kubectl get endpoints k8s-node-app-service` debe mostrar las IPs internas de los Pods en la columna `ENDPOINTS`, por ejemplo: `10.244.0.5:3000,10.244.1.3:3000`.

---

## Limpieza

Una vez completado el laboratorio, puedes optar por mantener los recursos (serán reutilizados en laboratorios posteriores) o eliminarlos.

> **Recomendación del curso:** NO elimines el clúster Minikube entre módulos. Usa `minikube stop` para pausar el clúster y `minikube start` para reanudarlo.

```bash
# Opción A: Eliminar solo los recursos de este laboratorio (conservar el clúster)
kubectl delete -f ~/k8s-lab-01/k8s/

# Verifica que los recursos fueron eliminados
kubectl get all -l app=k8s-node-app

# Opción B: Eliminar recursos y directorio de trabajo
kubectl delete -f ~/k8s-lab-01/k8s/
rm -rf ~/k8s-lab-01/

# Opción C: Pausar el clúster (conserva todos los recursos para el próximo lab)
minikube stop

# Opción D: Eliminar completamente el clúster (NO recomendado entre módulos)
# minikube delete
```

**Restablecer el entorno Docker del host** (si ya no necesitas trabajar con el Docker de Minikube):

```bash
# Deshacer la configuración del Docker de Minikube
eval $(minikube docker-env --unset)

# Verifica que apuntas nuevamente al Docker del host
docker info | grep "Name:"
```

---

## Resumen

En este laboratorio completaste el flujo completo de despliegue de una aplicación contenerizada en Kubernetes, conectando directamente los conceptos de la Lección 1.1 con la práctica:

| Concepto (Lección 1.1)            | Implementación práctica (Lab)                                      |
|-----------------------------------|--------------------------------------------------------------------|
| Modelo declarativo                | Manifiestos YAML con `kubectl apply`                               |
| Reconciliación continua           | Kubernetes mantiene siempre 2 réplicas activas                     |
| Programación automática           | Kubernetes asigna los Pods a los nodos disponibles                 |
| Control Plane vs Worker Nodes     | Explorado con `kubectl get nodes` y `kubectl describe node`        |
| Abstracción de infraestructura    | La app funciona igual independientemente de cuántos nodos hay      |
| Escalamiento y alta disponibilidad| 2 réplicas con balanceo de carga via Service                       |

**Recursos clave creados:**

- **`Deployment`** (`apps/v1`): Gestiona el ciclo de vida de los Pods, garantiza el número de réplicas y permite actualizaciones sin downtime.
- **`ReplicaSet`**: Creado automáticamente por el Deployment; garantiza que el número deseado de Pods esté siempre en ejecución.
- **`Pod`**: La unidad mínima de despliegue en Kubernetes; cada Pod ejecuta una instancia del contenedor Node.js.
- **`Service`** (`NodePort`): Expone los Pods al exterior del clúster y actúa como balanceador de carga interno.

### Recursos adicionales

- [Documentación oficial — Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Documentación oficial — Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Referencia de kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Kubernetes Basics — Tutorial interactivo oficial](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Minikube — Documentación de drivers](https://minikube.sigs.k8s.io/docs/drivers/)

---

---

# Práctica complementaria 1.1: Validación básica con kubectl y manifiestos YAML

## Metadatos

| Campo        | Detalle                                      |
|--------------|----------------------------------------------|
| **Duración** | 22 minutos                                   |
| **Complejidad** | Fácil                                     |
| **Nivel Bloom** | Aplicar (Apply)                           |
| **Módulo**   | 1 — Fundamentos de Kubernetes                |
| **Lab ID**   | 01-00-02                                     |

---

## Descripción General

Este laboratorio consolida los conceptos introducidos en la Lección 1.1 mediante la práctica directa con `kubectl`. Recibirás cinco manifiestos YAML con errores intencionales que representan los fallos más comunes al escribir recursos de Kubernetes: `apiVersion` incorrecta, indentación rota, campos inexistentes y valores inválidos. Utilizarás `kubectl apply --dry-run=client`, `kubectl explain` y comandos de observación del clúster para diagnosticar y corregir cada error de forma sistemática. Al finalizar, habrás desarrollado un flujo de trabajo de debugging básico que será fundamental en todos los laboratorios posteriores del curso.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Aplicar comandos esenciales de `kubectl` (`get`, `describe`, `logs`, `events`) para inspeccionar el estado del clúster y sus recursos de forma sistemática.
- [ ] Utilizar `kubectl apply --dry-run=client` y `kubectl explain` para detectar y corregir errores en manifiestos YAML antes de aplicarlos al clúster.
- [ ] Identificar los cinco tipos de error más comunes en manifiestos YAML de Kubernetes (apiVersion incorrecta, indentación rota, campo inexistente, valor inválido, selector inconsistente).
- [ ] Ejecutar un flujo de trabajo de validación reproducible que sirva como base metodológica para todos los laboratorios del curso.

---

## Prerrequisitos

### Conocimiento previo

- Haber completado el laboratorio **01-00-01** o tener un clúster Minikube operativo con al menos un Deployment desplegado.
- Familiaridad con la estructura básica de un manifiesto YAML de Kubernetes (`apiVersion`, `kind`, `metadata`, `spec`).
- Comprensión del modelo declarativo de Kubernetes: describir el estado deseado y dejar que el clúster lo reconcilie.

### Acceso y herramientas

| Herramienta | Versión mínima | Verificación |
|-------------|---------------|--------------|
| `kubectl`   | 1.28.x        | `kubectl version --client` |
| Minikube    | 1.31.x        | `minikube version` |
| Docker Engine | 24.x        | `docker version` |
| Editor de texto | cualquiera | `code --version` (VS Code recomendado) |

---

## Entorno del Laboratorio

### Especificaciones de hardware recomendadas

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU     | 4 núcleos | 8 núcleos |
| RAM     | 8 GB   | 16 GB       |
| Disco   | 40 GB libres | 60 GB SSD |

### Configuración del clúster

Si el clúster del laboratorio anterior sigue activo, puedes reutilizarlo. Si necesitas iniciarlo desde cero, ejecuta:

```bash
# Iniciar Minikube con 3 nodos (configuración recomendada para el curso completo)
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar que el clúster esté operativo
kubectl get nodes
```

**Salida esperada (referencia):**

```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
minikube-m03   Ready    <none>          Xm    v1.28.x
```

> **Nota para macOS/Windows con WSL2:** Si usas el driver Docker en estos sistemas operativos, el acceso a NodePort requiere `minikube service <nombre> --url` en lugar de la IP directa del nodo. Este laboratorio no requiere acceso a NodePort, por lo que no afecta los ejercicios.

### Preparación del directorio de trabajo

```bash
# Crear directorio de trabajo para este laboratorio
mkdir -p ~/k8s-labs/lab-01-00-02/manifests
cd ~/k8s-labs/lab-01-00-02
```

---

## Pasos del Laboratorio

---

### Paso 1 — Inspección del estado del clúster con comandos de observación

**Objetivo:** Establecer una línea base del estado actual del clúster usando los comandos de inspección fundamentales de `kubectl` que utilizarás en todos los laboratorios del curso.

#### Instrucciones

1. Verifica el estado de todos los nodos del clúster:

```bash
kubectl get nodes -o wide
```

2. Lista todos los recursos en el namespace `default`:

```bash
kubectl get all -n default
```

3. Consulta los eventos recientes del clúster (útil para detectar errores de scheduling):

```bash
kubectl get events -n default --sort-by='.lastTimestamp'
```

4. Si el laboratorio anterior dejó un Deployment activo, inspecciónalo. Si no existe ninguno, crea uno de referencia para los ejercicios de observación:

```bash
# Crear un Deployment de referencia (solo si no existe uno del lab anterior)
kubectl create deployment nginx-ref --image=nginx:1.25 --replicas=2

# Esperar a que los pods estén Running
kubectl rollout status deployment/nginx-ref
```

5. Practica los comandos de observación sobre este Deployment:

```bash
# Ver el estado de los pods con etiquetas
kubectl get pods -n default --show-labels

# Describir el Deployment (muestra eventos, condiciones y configuración completa)
kubectl describe deployment nginx-ref

# Ver los logs de uno de los pods (reemplaza <pod-name> con el nombre real)
kubectl get pods -n default
kubectl logs <pod-name>
```

#### Salida esperada

```
# kubectl get nodes -o wide
NAME           STATUS   ROLES           AGE   VERSION    INTERNAL-IP    ...
minikube       Ready    control-plane   Xm    v1.28.x    192.168.49.2   ...
minikube-m02   Ready    <none>          Xm    v1.28.x    192.168.49.3   ...

# kubectl get all -n default
NAME                             READY   STATUS    RESTARTS   AGE
pod/nginx-ref-xxxxxxxxx-xxxxx    1/1     Running   0          30s
pod/nginx-ref-xxxxxxxxx-yyyyy    1/1     Running   0          30s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-ref   2/2     2            2           30s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-ref-xxxxxxxxx    2         2         2       30s
```

#### Verificación

```bash
# Confirmar que al menos 2 pods están en estado Running
kubectl get pods -n default | grep -c "Running"
# Debe retornar 2 o más
```

> **Concepto clave:** `kubectl get all` muestra Pods, Services, Deployments y ReplicaSets. Es el primer comando que debes ejecutar al diagnosticar cualquier problema en un namespace. Recuerda que Kubernetes opera con un modelo declarativo: lo que ves aquí es el estado **actual** del clúster, que Kubernetes intenta reconciliar continuamente con el estado **deseado** definido en tus manifiestos.

---

### Paso 2 — Uso de `kubectl explain` para consultar la API de Kubernetes

**Objetivo:** Aprender a usar `kubectl explain` como herramienta de referencia integrada para conocer los campos válidos de cualquier recurso de Kubernetes sin salir de la terminal.

#### Instrucciones

1. Consulta la estructura raíz del recurso `Pod`:

```bash
kubectl explain pod
```

2. Navega a campos anidados usando notación de punto:

```bash
# Ver los campos de spec de un Pod
kubectl explain pod.spec

# Ver la definición de containers dentro de spec
kubectl explain pod.spec.containers

# Ver los campos de un Deployment
kubectl explain deployment.spec.template.spec.containers
```

3. Usa la bandera `--recursive` para ver el árbol completo de campos de un recurso:

```bash
kubectl explain deployment --recursive | head -60
```

4. Verifica qué `apiVersion` es la correcta para los recursos más comunes:

```bash
# Consultar apiVersion y kind para Deployment
kubectl explain deployment | grep -E "VERSION|KIND"

# Consultar apiVersion para Pod
kubectl explain pod | grep -E "VERSION|KIND"

# Consultar apiVersion para Service
kubectl explain service | grep -E "VERSION|KIND"
```

#### Salida esperada

```
# kubectl explain deployment | grep -E "VERSION|KIND"
KIND:       Deployment
VERSION:    apps/v1

# kubectl explain pod | grep -E "VERSION|KIND"
KIND:     Pod
VERSION:  v1

# kubectl explain service | grep -E "VERSION|KIND"
KIND:     Service
VERSION:  v1
```

#### Verificación

```bash
# Confirmar que conoces el apiVersion correcto para ConfigMap
kubectl explain configmap | grep VERSION
# Debe mostrar: VERSION: v1
```

> **Consejo de examen CKA:** `kubectl explain` es tu mejor aliado cuando no recuerdas el nombre exacto de un campo. Es más rápido y confiable que buscar en Internet durante el examen. Úsalo constantemente durante este curso para desarrollar el hábito.

---

### Paso 3 — Crear los cinco manifiestos con errores intencionales

**Objetivo:** Preparar el conjunto de manifiestos defectuosos que serán diagnosticados y corregidos en el Paso 4.

#### Instrucciones

Crea los siguientes cinco archivos en el directorio `~/k8s-labs/lab-01-00-02/manifests/`. Cada archivo contiene **un error intencional** diferente. No los corrijas todavía.

**Archivo 1: `error-01-apiversion.yaml`** — apiVersion incorrecta

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-01-apiversion.yaml << 'EOF'
apiVersion: apps/v2          # ERROR: La versión correcta es apps/v1
kind: Deployment
metadata:
  name: web-apiversion
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-apiversion
  template:
    metadata:
      labels:
        app: web-apiversion
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
```

**Archivo 2: `error-02-indentation.yaml`** — Indentación rota

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-02-indentation.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-indentation
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
      - containerPort: 80    # ERROR: esta línea debería tener 8 espacios de indentación (estar bajo containers[0])
    resources:               # ERROR: resources está al nivel de ports, debe estar al nivel de name/image
      requests:
        memory: "64Mi"
        cpu: "250m"
EOF
```

**Archivo 3: `error-03-invalidfield.yaml`** — Campo inexistente en la API

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-03-invalidfield.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-invalidfield
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
  restartPolicy: Always
  priorityLevel: high        # ERROR: este campo no existe en la API de Pod
EOF
```

**Archivo 4: `error-04-invalidvalue.yaml`** — Valor inválido para un campo

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-04-invalidvalue.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-invalidvalue
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
  restartPolicy: WhenFails    # ERROR: los valores válidos son Always, OnFailure, Never
EOF
```

**Archivo 5: `error-05-selector.yaml`** — Selector inconsistente con las etiquetas del template

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-selector
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-selector       # El selector busca esta etiqueta
  template:
    metadata:
      labels:
        app: web-backend      # ERROR: la etiqueta no coincide con el selector
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
```

#### Verificación

```bash
# Confirmar que los 5 archivos fueron creados
ls -la ~/k8s-labs/lab-01-00-02/manifests/
# Debe mostrar 5 archivos .yaml
```

---

### Paso 4 — Diagnóstico y corrección de manifiestos con `--dry-run=client`

**Objetivo:** Aplicar `kubectl apply --dry-run=client` para detectar los errores en cada manifiesto y corregirlos usando `kubectl explain` como referencia.

> **Flujo de trabajo recomendado para cada archivo:**
> 1. Ejecutar `kubectl apply --dry-run=client -f <archivo>`
> 2. Leer el mensaje de error
> 3. Consultar `kubectl explain` para verificar el campo/valor correcto
> 4. Corregir el archivo
> 5. Re-ejecutar `--dry-run=client` para confirmar que el error desapareció
> 6. Aplicar al clúster con `kubectl apply -f <archivo>`

---

#### 4.1 — Error 01: apiVersion incorrecta

```bash
# Paso 1: Detectar el error
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-01-apiversion.yaml
```

**Salida esperada del error:**
```
error: resource mapping not found for name: "web-apiversion" namespace: "default"
from "error-01-apiversion.yaml": no matches for kind "Deployment" in version "apps/v2"
ensure CRDs are installed first, resource.group/version is not registered
```

```bash
# Paso 2: Verificar la apiVersion correcta
kubectl explain deployment | grep VERSION
```

```bash
# Paso 3: Corregir el archivo (cambiar apps/v2 por apps/v1)
sed -i 's/apiVersion: apps\/v2/apiVersion: apps\/v1/' \
  ~/k8s-labs/lab-01-00-02/manifests/error-01-apiversion.yaml

# Paso 4: Verificar la corrección
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-01-apiversion.yaml
```

**Salida esperada tras la corrección:**
```
deployment.apps/web-apiversion created (dry run)
```

```bash
# Paso 5: Aplicar al clúster
kubectl apply -f ~/k8s-labs/lab-01-00-02/manifests/error-01-apiversion.yaml
```

---

#### 4.2 — Error 02: Indentación rota

```bash
# Paso 1: Detectar el error
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-02-indentation.yaml
```

**Salida esperada del error:**
```
error: error parsing error-02-indentation.yaml: error converting YAML to JSON:
yaml: line X: mapping values are not allowed in this context
```

> **Nota:** Los errores de YAML puro (indentación) son detectados antes de que Kubernetes valide los campos. El número de línea en el mensaje te orienta hacia el problema.

```bash
# Paso 2: Abrir el archivo y corregir la indentación manualmente
# La estructura correcta de containers[0] debe ser:
#   containers:
#     - name: nginx
#       image: nginx:1.25
#       ports:
#         - containerPort: 80
#       resources:          <- al mismo nivel que name, image, ports
#         requests:
#           memory: "64Mi"
#           cpu: "250m"
```

Reemplaza el contenido del archivo con la versión corregida:

```bash
cat > ~/k8s-labs/lab-01-00-02/manifests/error-02-indentation.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-indentation
  namespace: default
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
EOF
```

```bash
# Paso 3: Verificar la corrección
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-02-indentation.yaml
# Salida esperada: pod/pod-indentation created (dry run)

# Paso 4: Aplicar al clúster
kubectl apply -f ~/k8s-labs/lab-01-00-02/manifests/error-02-indentation.yaml
```

---

#### 4.3 — Error 03: Campo inexistente en la API

```bash
# Paso 1: Detectar el error
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-03-invalidfield.yaml
```

**Salida esperada del error:**
```
error: error validating "error-03-invalidfield.yaml": error validating data:
ValidationError(Pod.spec): unknown field "priorityLevel" in io.k8s.api.core.v1.PodSpec
```

```bash
# Paso 2: Verificar los campos válidos de pod.spec
kubectl explain pod.spec | grep -A2 priority
# Verás que el campo correcto es 'priorityClassName', no 'priorityLevel'
```

```bash
# Paso 3: Corregir el archivo (eliminar el campo inválido)
sed -i '/priorityLevel: high/d' \
  ~/k8s-labs/lab-01-00-02/manifests/error-03-invalidfield.yaml

# Paso 4: Verificar la corrección
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-03-invalidfield.yaml
# Salida esperada: pod/pod-invalidfield created (dry run)

# Paso 5: Aplicar al clúster
kubectl apply -f ~/k8s-labs/lab-01-00-02/manifests/error-03-invalidfield.yaml
```

---

#### 4.4 — Error 04: Valor inválido para un campo

```bash
# Paso 1: Detectar el error
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-04-invalidvalue.yaml
```

**Salida esperada del error:**
```
error: error validating "error-04-invalidvalue.yaml": error validating data:
ValidationError(Pod.spec.restartPolicy): invalid value for io.k8s.api.core.v1.PodSpec.restartPolicy:
supported values: "Always", "OnFailure", "Never"
```

```bash
# Paso 2: Confirmar los valores válidos con kubectl explain
kubectl explain pod.spec.restartPolicy
```

```bash
# Paso 3: Corregir el valor (cambiar WhenFails por OnFailure)
sed -i 's/restartPolicy: WhenFails/restartPolicy: OnFailure/' \
  ~/k8s-labs/lab-01-00-02/manifests/error-04-invalidvalue.yaml

# Paso 4: Verificar la corrección
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-04-invalidvalue.yaml
# Salida esperada: pod/pod-invalidvalue created (dry run)

# Paso 5: Aplicar al clúster
kubectl apply -f ~/k8s-labs/lab-01-00-02/manifests/error-04-invalidvalue.yaml
```

---

#### 4.5 — Error 05: Selector inconsistente con etiquetas del template

```bash
# Paso 1: Detectar el error
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml
```

**Salida esperada del error:**
```
error: error validating "error-05-selector.yaml": error validating data:
ValidationError(Deployment.spec): invalid value for io.k8s.apps.v1.DeploymentSpec.selector:
field is immutable && The Deployment "web-selector" is invalid:
spec.template.metadata.labels: Invalid value: map[string]string{"app":"web-backend"}:
`selector` does not match template `labels`
```

```bash
# Paso 2: Consultar la estructura del selector en Deployment
kubectl explain deployment.spec.selector
kubectl explain deployment.spec.template.metadata.labels
```

```bash
# Paso 3: Corregir el archivo (alinear la etiqueta del template con el selector)
sed -i 's/app: web-backend/app: web-selector/' \
  ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml

# Paso 4: Verificar que la corrección es completa
grep -n "app:" ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml
# Todas las líneas con 'app:' deben mostrar 'web-selector'

# Paso 5: Verificar con dry-run
kubectl apply --dry-run=client -f ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml
# Salida esperada: deployment.apps/web-selector created (dry run)

# Paso 6: Aplicar al clúster
kubectl apply -f ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml
```

---

### Paso 5 — Verificación del estado de todos los recursos creados

**Objetivo:** Confirmar que todos los recursos corregidos fueron aplicados exitosamente al clúster y están en estado operativo.

#### Instrucciones

1. Lista todos los recursos en el namespace `default`:

```bash
kubectl get all -n default
```

2. Verifica el estado de cada Pod individualmente:

```bash
kubectl get pods -n default -o wide
```

3. Inspecciona los eventos del namespace para confirmar que no hay errores de scheduling o imagen:

```bash
kubectl get events -n default --sort-by='.lastTimestamp' | tail -20
```

4. Describe uno de los Pods creados para ver su configuración completa:

```bash
# Obtener el nombre del pod pod-indentation
kubectl describe pod pod-indentation -n default
```

5. Verifica los logs de uno de los pods nginx:

```bash
kubectl logs pod-indentation -n default
```

#### Salida esperada

```
# kubectl get pods -n default
NAME                                READY   STATUS    RESTARTS   AGE
pod-indentation                     1/1     Running   0          Xm
pod-invalidfield                    1/1     Running   0          Xm
pod-invalidvalue                    1/1     Running   0          Xm
web-apiversion-xxxxxxxxx-xxxxx      1/1     Running   0          Xm
web-selector-xxxxxxxxx-xxxxx        1/1     Running   0          Xm
web-selector-xxxxxxxxx-yyyyy        1/1     Running   0          Xm
nginx-ref-xxxxxxxxx-xxxxx           1/1     Running   0          Xm
nginx-ref-xxxxxxxxx-yyyyy           1/1     Running   0          Xm
```

> **Nota:** `pod-invalidvalue` tiene `restartPolicy: OnFailure`. Si nginx termina con código 0 (éxito), el pod pasará a `Completed`. Esto es comportamiento esperado con esa política de reinicio.

#### Verificación

```bash
# Confirmar que no hay pods en estado Error o CrashLoopBackOff
kubectl get pods -n default | grep -E "Error|CrashLoopBackOff|Pending"
# No debe retornar ninguna línea
```

---

## Validación y Pruebas

Ejecuta el siguiente script de validación para confirmar que completaste correctamente todos los objetivos del laboratorio:

```bash
#!/bin/bash
echo "=== Validación Lab 01-00-02 ==="
echo ""

PASS=0
FAIL=0

check() {
  local desc=$1
  local cmd=$2
  local expected=$3
  result=$(eval "$cmd" 2>/dev/null)
  if echo "$result" | grep -q "$expected"; then
    echo "  ✅ PASS: $desc"
    ((PASS++))
  else
    echo "  ❌ FAIL: $desc"
    echo "     Comando: $cmd"
    echo "     Resultado: $result"
    ((FAIL++))
  fi
}

echo "--- Verificando nodos del clúster ---"
check "Clúster tiene al menos 1 nodo Ready" \
  "kubectl get nodes --no-headers" "Ready"

echo ""
echo "--- Verificando recursos corregidos ---"
check "Deployment web-apiversion existe y usa apps/v1" \
  "kubectl get deployment web-apiversion -o jsonpath='{.apiVersion}'" "apps/v1"

check "Pod pod-indentation está Running o Completed" \
  "kubectl get pod pod-indentation --no-headers" -E "Running|Completed"

check "Pod pod-invalidfield está Running" \
  "kubectl get pod pod-invalidfield --no-headers" "Running"

check "Pod pod-invalidvalue tiene restartPolicy OnFailure" \
  "kubectl get pod pod-invalidvalue -o jsonpath='{.spec.restartPolicy}'" "OnFailure"

check "Deployment web-selector: selector coincide con labels del template" \
  "kubectl get deployment web-selector -o jsonpath='{.spec.selector.matchLabels.app}'" "web-selector"

check "Deployment web-selector: labels del template son correctas" \
  "kubectl get deployment web-selector -o jsonpath='{.spec.template.metadata.labels.app}'" "web-selector"

echo ""
echo "--- Verificando herramientas de diagnóstico ---"
check "kubectl explain pod retorna información" \
  "kubectl explain pod" "KIND"

check "kubectl explain deployment retorna apps/v1" \
  "kubectl explain deployment" "apps/v1"

echo ""
echo "=== Resultado: ${PASS} pasaron / $((PASS+FAIL)) total ==="
if [ $FAIL -eq 0 ]; then
  echo "🎉 ¡Laboratorio completado exitosamente!"
else
  echo "⚠️  Revisa los ítems marcados con ❌ antes de continuar."
fi
```

Para ejecutarlo:

```bash
# Guardar el script y ejecutarlo
cat > ~/k8s-labs/lab-01-00-02/validate.sh << 'SCRIPT'
# (pegar el contenido del script de arriba)
SCRIPT

chmod +x ~/k8s-labs/lab-01-00-02/validate.sh
bash ~/k8s-labs/lab-01-00-02/validate.sh
```

**Resultado esperado:** `8 pasaron / 8 total` con el mensaje de éxito.

---

## Resolución de Problemas

### Problema 1: `--dry-run=client` no detecta errores de campos desconocidos

**Síntomas:**
```
# El dry-run retorna "created (dry run)" pero el recurso falla al aplicarse
deployment.apps/web-selector created (dry run)
# Sin embargo, kubectl apply -f ... retorna un error de validación
```

**Causa:**
`--dry-run=client` valida la estructura YAML y el `apiVersion`/`kind` localmente, pero **no consulta el servidor de API** para validar todos los campos. Algunos errores de validación semántica (como selectores inconsistentes en ciertos contextos) solo son detectados por el servidor.

**Solución:**
Usa `--dry-run=server` para una validación completa contra el API Server:

```bash
# Validación del lado del servidor (más completa)
kubectl apply --dry-run=server -f ~/k8s-labs/lab-01-00-02/manifests/error-05-selector.yaml

# Si no tienes permisos de escritura en el clúster, usa --validate=strict
kubectl apply --dry-run=client --validate=strict -f <archivo.yaml>
```

> **Cuándo usar cada uno:**
> - `--dry-run=client`: Rápido, sin acceso al clúster, valida YAML y apiVersion/kind.
> - `--dry-run=server`: Completo, requiere acceso al clúster, detecta errores de validación semántica y conflictos.

---

### Problema 2: Pod en estado `Pending` después de aplicar el manifiesto corregido

**Síntomas:**
```bash
kubectl get pods -n default
# NAME                READY   STATUS    RESTARTS   AGE
# pod-indentation     0/1     Pending   0          2m
```

```bash
kubectl describe pod pod-indentation -n default
# Events:
#   Warning  FailedScheduling  2m  default-scheduler
#   0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
```

**Causa:**
El clúster Minikube no tiene suficientes recursos disponibles para programar el pod. Esto puede ocurrir si el clúster fue iniciado con parámetros de CPU/memoria muy bajos (`--cpus=1 --memory=1024`) o si hay demasiados pods corriendo simultáneamente en los nodos disponibles.

**Solución:**

```bash
# Opción 1: Verificar los recursos disponibles en los nodos
kubectl describe nodes | grep -A5 "Allocated resources"

# Opción 2: Reducir los requests de recursos en el manifiesto
# Editar error-02-indentation.yaml y cambiar:
#   requests:
#     memory: "32Mi"   # Reducir de 64Mi
#     cpu: "100m"      # Reducir de 250m

# Opción 3: Si el clúster fue iniciado con muy pocos recursos, reiniciarlo con más
minikube stop
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Opción 4: Eliminar pods de referencia que ya no necesitas
kubectl delete deployment nginx-ref
```

---

## Limpieza

Al finalizar el laboratorio, elimina los recursos creados para liberar recursos del clúster. **No elimines el clúster Minikube**, ya que se reutilizará en laboratorios posteriores.

```bash
# Eliminar los pods individuales creados en el laboratorio
kubectl delete pod pod-indentation pod-invalidfield pod-invalidvalue -n default

# Eliminar los Deployments creados en el laboratorio
kubectl delete deployment web-apiversion web-selector -n default

# Eliminar el Deployment de referencia (si fue creado en el Paso 1)
kubectl delete deployment nginx-ref -n default --ignore-not-found=true

# Verificar que el namespace default quedó limpio
kubectl get all -n default
# Debe mostrar solo el service/kubernetes (que es del sistema)
```

**Salida esperada tras la limpieza:**
```
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   Xh
```

> **Persistencia entre laboratorios:** Si el laboratorio 01-00-03 o posteriores requieren recursos de este laboratorio, omite los pasos de limpieza correspondientes. Consulta las notas de prerrequisitos del siguiente laboratorio antes de limpiar.

---

## Resumen

En este laboratorio aplicaste un flujo de trabajo sistemático de validación y diagnóstico de manifiestos YAML en Kubernetes. Los puntos clave que debes retener son:

| Herramienta | Cuándo usarla |
|-------------|---------------|
| `kubectl apply --dry-run=client` | Validación rápida de YAML y apiVersion antes de aplicar |
| `kubectl apply --dry-run=server` | Validación completa incluyendo semántica del API Server |
| `kubectl explain <recurso>.<campo>` | Consultar campos válidos y sus tipos sin salir de la terminal |
| `kubectl get all -n <namespace>` | Vista general del estado de todos los recursos en un namespace |
| `kubectl describe <tipo>/<nombre>` | Inspección detallada con eventos y condiciones |
| `kubectl get events --sort-by='.lastTimestamp'` | Diagnóstico de fallos de scheduling y errores recientes |
| `kubectl logs <pod>` | Ver salida estándar de un contenedor en ejecución |

Los **cinco tipos de error** que practicaste son los más frecuentes en el examen CKA y en entornos reales:

1. **apiVersion incorrecta** → Usar `kubectl explain <kind> | grep VERSION`
2. **Indentación YAML rota** → El parser YAML falla antes de llegar a Kubernetes; usar un editor con soporte YAML
3. **Campo inexistente** → `kubectl explain <recurso.campo>` muestra los campos válidos
4. **Valor inválido** → El mensaje de error del API Server lista los valores permitidos
5. **Selector inconsistente** → `spec.selector.matchLabels` debe ser un subconjunto de `spec.template.metadata.labels`

### Conexión con la Lección 1.1

Este laboratorio refuerza directamente el modelo **declarativo** de Kubernetes descrito en la Lección 1.1: los manifiestos YAML son la forma en que describes el estado deseado del clúster. Dominar su validación antes de aplicarlos es la primera línea de defensa para mantener la integridad del estado declarado. El proceso de reconciliación de Kubernetes solo puede funcionar correctamente si los manifiestos que le proporcionas son semánticamente válidos.

### Recursos adicionales

- [Referencia de la API de Kubernetes v1.28](https://kubernetes.io/docs/reference/kubernetes-api/)
- [Guía de kubectl: comandos de uso frecuente](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Validación de YAML en línea](https://www.yamllint.com/) — útil para diagnosticar errores de indentación complejos
- [kubectl explain — documentación oficial](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#explain)

---
