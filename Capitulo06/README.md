# Exposición de aplicaciones con Services (ClusterIP, NodePort) e Ingress

## Metadatos

| Campo | Valor |
|---|---|
| **Duración estimada** | 78 minutos |
| **Complejidad** | Alta |
| **Nivel Bloom** | Crear (Create) |
| **Módulo** | 6 — Networking y Exposición de Aplicaciones |
| **Versión Kubernetes** | 1.28+ |

---

## Descripción General

En este laboratorio construirás desde cero una arquitectura de red completa en Kubernetes, desplegando dos microservicios (frontend y backend) y exponiéndolos progresivamente mediante los tres tipos principales de Services: **ClusterIP** para comunicación interna, **NodePort** para acceso externo directo, y **LoadBalancer** como concepto. Finalmente instalarás y configurarás el **NGINX Ingress Controller** para implementar enrutamiento avanzado basado en path y en host, explorando anotaciones de Ingress y verificando la resolución DNS interna de Kubernetes mediante CoreDNS. Este laboratorio integra los principios del modelo de red plana estudiados en la lección 6.1 con los mecanismos de abstracción que hacen posible la comunicación estable entre servicios efímeros.

---

## Objetivos de Aprendizaje

Al completar este laboratorio serás capaz de:

- [ ] Crear y comparar Services de tipo ClusterIP, NodePort y LoadBalancer, explicando el alcance de red y los casos de uso de cada tipo
- [ ] Verificar la resolución DNS interna de Kubernetes usando el formato FQDN (`<svc>.<ns>.svc.cluster.local`) desde dentro de un Pod de prueba con `nslookup` y `curl`
- [ ] Instalar el NGINX Ingress Controller mediante el addon de Minikube y crear reglas de Ingress para enrutamiento por path y por host hacia múltiples backends
- [ ] Aplicar anotaciones de Ingress (`rewrite-target`, `ssl-redirect`) para configuración avanzada del controlador NGINX
- [ ] Diagnosticar problemas de conectividad entre servicios usando `kubectl exec` y herramientas de red dentro de los Pods

---

## Prerrequisitos

### Conocimiento Previo

- Haber completado los laboratorios de Módulos 1–5 (Pods, Deployments, ReplicaSets, ConfigMaps, Secrets, RBAC)
- Comprensión del modelo de red plana de Kubernetes (Lección 6.1): IPs de Pod, Pod CIDR, Service CIDR
- Comprensión de conceptos de red básicos: puertos TCP/UDP, direcciones IP, DNS, protocolo HTTP
- Familiaridad con `kubectl apply`, `kubectl get`, `kubectl exec` y manifiestos YAML

### Acceso y Herramientas

- Clúster Minikube operativo con **mínimo 2 nodos** (idealmente 3)
- `kubectl` 1.28+ configurado y apuntando al clúster Minikube
- `curl` disponible en el sistema host
- Acceso a Internet para descarga de imágenes de contenedor
- Permisos de escritura en `/etc/hosts` del sistema host (para enrutamiento por host)

---

## Entorno de Laboratorio

### Hardware Recomendado

| Recurso | Mínimo | Recomendado |
|---|---|---|
| CPU (núcleos físicos) | 4 | 8 |
| RAM disponible | 8 GB | 16 GB |
| Almacenamiento libre | 40 GB | 60 GB |
| Conectividad | 10 Mbps | 25 Mbps |

### Software Requerido

| Herramienta | Versión | Propósito |
|---|---|---|
| Minikube | 1.31.x+ | Clúster local multi-nodo |
| kubectl | 1.28.x+ | Gestión del clúster |
| Docker Engine | 24.x+ | Driver de Minikube |
| curl | 7.x+ | Verificación HTTP |
| nslookup / dig | bind-utils 9.x | Verificación DNS |

### Preparación del Entorno

Antes de comenzar, verifica que tu clúster Minikube esté operativo con al menos 2 nodos. Si no lo tienes configurado, ejecuta:

```bash
# Iniciar Minikube con 3 nodos (configuración recomendada para todo el curso)
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# Verificar el estado del clúster
kubectl get nodes -o wide
```

**Salida esperada:**
```
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP
minikube       Ready    control-plane   Xm    v1.28.x   192.168.49.2
minikube-m02   Ready    <none>          Xm    v1.28.x   192.168.49.3
minikube-m03   Ready    <none>          Xm    v1.28.x   192.168.49.4
```

```bash
# Pre-descargar imágenes necesarias para el laboratorio
for img in nginx:1.25 nginx:1.26 node:18-alpine busybox:latest; do
  docker pull $img
done
```

> **⚠️ Nota importante:** El addon de Ingress de Minikube puede tardar 2–3 minutos en estar completamente operativo después de habilitarse. Si ves el pod en estado `ContainerCreating`, espera antes de continuar con la Parte 3.

---

## Instrucciones Paso a Paso

---

### Parte 1: Preparación — Namespace y Despliegue de Microservicios

---

#### Paso 1.1: Crear el Namespace de trabajo

**Objetivo:** Aislar todos los recursos del laboratorio en un namespace dedicado para facilitar la gestión y limpieza posterior.

**Instrucciones:**

1. Crea el namespace `lab06`:

```bash
kubectl create namespace lab06
```

2. Configura `lab06` como namespace por defecto para esta sesión:

```bash
kubectl config set-context --current --namespace=lab06
```

3. Verifica que el namespace existe y está activo:

```bash
kubectl get namespace lab06
kubectl config view --minify | grep namespace
```

**Salida esperada:**
```
NAME    STATUS   AGE
lab06   Active   5s

    namespace: lab06
```

---

#### Paso 1.2: Desplegar el microservicio Backend

**Objetivo:** Crear un Deployment para el servicio backend que simulará una API REST respondiendo en el puerto 80.

**Instrucciones:**

1. Crea el archivo de manifiesto del backend:

```bash
cat <<'EOF' > backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: lab06
  labels:
    app: backend
    tier: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: backend
        image: nginx:1.25
        ports:
        - containerPort: 80
        env:
        - name: SERVICE_NAME
          value: "backend-api"
        # Personalizar la respuesta del backend para identificarlo fácilmente
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo '<html><body><h1>BACKEND API v1.0</h1><p>Pod: '$(hostname)'</p></body></html>' > /usr/share/nginx/html/index.html
          echo '<html><body><h1>API Health OK</h1></body></html>' > /usr/share/nginx/html/health
          nginx -g 'daemon off;'
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f backend-deployment.yaml
```

3. Verifica que los Pods del backend se están ejecutando:

```bash
kubectl get pods -l app=backend -o wide
```

**Salida esperada:**
```
NAME                       READY   STATUS    RESTARTS   IP            NODE
backend-7d6f8b9c4-abc12    1/1     Running   0          10.244.1.x    minikube-m02
backend-7d6f8b9c4-def34    1/1     Running   0          10.244.2.x    minikube-m03
```

> **Concepto clave:** Observa que los dos Pods del backend tienen IPs diferentes y están distribuidos en nodos distintos. Gracias al modelo de red plana (Lección 6.1), ambos son accesibles directamente desde cualquier otro Pod del clúster usando esas IPs, sin NAT.

---

#### Paso 1.3: Desplegar el microservicio Frontend

**Objetivo:** Crear un segundo Deployment para el servicio frontend que servirá contenido web estático.

**Instrucciones:**

1. Crea el manifiesto del frontend:

```bash
cat <<'EOF' > frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: lab06
  labels:
    app: frontend
    tier: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: frontend
        image: nginx:1.26
        ports:
        - containerPort: 80
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo '<html><body><h1>FRONTEND v2.0</h1><p>Pod: '$(hostname)'</p><p>Served by: nginx 1.26</p></body></html>' > /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f frontend-deployment.yaml
```

3. Verifica que todos los Pods están en estado `Running`:

```bash
kubectl get pods -n lab06 -o wide
```

**Salida esperada:**
```
NAME                        READY   STATUS    IP            NODE
backend-7d6f8b9c4-abc12     1/1     Running   10.244.1.x    minikube-m02
backend-7d6f8b9c4-def34     1/1     Running   10.244.2.x    minikube-m03
frontend-6c8b7d9f5-ghi56    1/1     Running   10.244.1.y    minikube-m02
frontend-6c8b7d9f5-jkl78    1/1     Running   10.244.2.y    minikube-m03
```

**Verificación:**
```bash
# Confirmar que el modelo de red plana funciona: acceso directo por IP de Pod
BACKEND_IP=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')
echo "IP del primer Pod backend: $BACKEND_IP"

# Verificar conectividad directa desde un Pod frontend al backend por IP
FRONTEND_POD=$(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FRONTEND_POD -- curl -s http://$BACKEND_IP | grep -o '<h1>.*</h1>'
```

**Salida esperada:**
```
<h1>BACKEND API v1.0</h1>
```

---

### Parte 2: Services ClusterIP y DNS Interno

---

#### Paso 2.1: Crear Services de tipo ClusterIP

**Objetivo:** Exponer los microservicios backend y frontend mediante Services ClusterIP, que proveen una IP virtual estable y balanceo de carga interno, resolviendo el problema de las IPs efímeras de los Pods.

**Instrucciones:**

1. Crea el Service ClusterIP para el backend:

```bash
cat <<'EOF' > backend-service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: lab06
  labels:
    app: backend
spec:
  type: ClusterIP       # Tipo por defecto: solo accesible dentro del clúster
  selector:
    app: backend        # Selecciona todos los Pods con esta etiqueta
  ports:
  - name: http
    protocol: TCP
    port: 80            # Puerto del Service (ClusterIP)
    targetPort: 80      # Puerto del contenedor
EOF

kubectl apply -f backend-service-clusterip.yaml
```

2. Crea el Service ClusterIP para el frontend:

```bash
cat <<'EOF' > frontend-service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: lab06
  labels:
    app: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
EOF

kubectl apply -f frontend-service-clusterip.yaml
```

3. Verifica los Services creados y sus ClusterIPs asignadas:

```bash
kubectl get services -n lab06 -o wide
```

**Salida esperada:**
```
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
backend-svc    ClusterIP   10.96.x.x       <none>        80/TCP    30s   app=backend
frontend-svc   ClusterIP   10.96.y.y       <none>        80/TCP    15s   app=frontend
```

> **Concepto clave:** La columna `EXTERNAL-IP` muestra `<none>` porque ClusterIP solo es accesible desde dentro del clúster. La `CLUSTER-IP` es una IP virtual estable que no cambia aunque los Pods se reinicien o reprogramen.

4. Inspecciona los Endpoints para verificar que el Service está correctamente vinculado a los Pods:

```bash
kubectl get endpoints -n lab06
```

**Salida esperada:**
```
NAME           ENDPOINTS                         AGE
backend-svc    10.244.1.x:80,10.244.2.x:80       45s
frontend-svc   10.244.1.y:80,10.244.2.y:80       30s
```

---

#### Paso 2.2: Verificar el DNS interno de Kubernetes (CoreDNS)

**Objetivo:** Demostrar que CoreDNS registra automáticamente los Services y permite resolverlos por nombre usando el formato FQDN `<servicio>.<namespace>.svc.cluster.local`.

**Instrucciones:**

1. Despliega un Pod de prueba con herramientas de red (`busybox`):

```bash
kubectl run dns-test \
  --image=busybox:latest \
  --restart=Never \
  --namespace=lab06 \
  -it --rm \
  -- sh
```

2. Dentro del shell del Pod `dns-test`, ejecuta las siguientes verificaciones de DNS:

```bash
# Verificar resolución DNS del backend por nombre corto (mismo namespace)
nslookup backend-svc

# Verificar resolución DNS usando FQDN completo
nslookup backend-svc.lab06.svc.cluster.local

# Verificar resolución DNS del frontend
nslookup frontend-svc.lab06.svc.cluster.local

# Consultar el servidor DNS del clúster directamente
cat /etc/resolv.conf
```

**Salida esperada dentro del Pod:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      backend-svc
Address 1: 10.96.x.x backend-svc.lab06.svc.cluster.local

# /etc/resolv.conf muestra:
nameserver 10.96.0.10
search lab06.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

3. Verifica la conectividad HTTP usando el nombre DNS (aún dentro del Pod `dns-test`):

```bash
# Acceso al backend por nombre corto
wget -qO- http://backend-svc

# Acceso al backend por FQDN completo
wget -qO- http://backend-svc.lab06.svc.cluster.local

# Acceso al frontend por nombre corto
wget -qO- http://frontend-svc
```

**Salida esperada:**
```html
<html><body><h1>BACKEND API v1.0</h1><p>Pod: backend-7d6f8b9c4-abc12</p></body></html>
```

4. Sal del Pod de prueba:

```bash
exit
```

**Verificación adicional desde el host:**
```bash
# Verificar que CoreDNS está operativo en kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Describir el Service kube-dns para ver su ClusterIP
kubectl get svc kube-dns -n kube-system
```

---

#### Paso 2.3: Verificar comunicación entre servicios (modelo de red plana)

**Objetivo:** Confirmar que los Pods de frontend pueden comunicarse con el backend usando el nombre DNS del Service, demostrando el modelo de red plana en acción.

**Instrucciones:**

1. Obtén el nombre de un Pod frontend:

```bash
FRONTEND_POD=$(kubectl get pod -l app=frontend -n lab06 -o jsonpath='{.items[0].metadata.name}')
echo "Pod frontend seleccionado: $FRONTEND_POD"
```

2. Desde el Pod frontend, realiza una llamada HTTP al Service del backend:

```bash
# Llamada al backend usando nombre DNS del Service
kubectl exec -n lab06 $FRONTEND_POD -- \
  wget -qO- http://backend-svc.lab06.svc.cluster.local

# Múltiples llamadas para observar el balanceo de carga entre los 2 Pods backend
for i in $(seq 1 4); do
  kubectl exec -n lab06 $FRONTEND_POD -- \
    wget -qO- http://backend-svc 2>/dev/null | grep -o 'Pod: [^<]*'
done
```

**Salida esperada (el hostname del Pod varía, mostrando balanceo):**
```
Pod: backend-7d6f8b9c4-abc12
Pod: backend-7d6f8b9c4-def34
Pod: backend-7d6f8b9c4-abc12
Pod: backend-7d6f8b9c4-def34
```

> **Concepto clave:** El Service ClusterIP actúa como balanceador de carga interno usando `iptables`/`ipvs`. Cada petición puede ser dirigida a cualquiera de los Pods backend, distribuyendo la carga automáticamente.

---

### Parte 3: Service NodePort — Acceso Externo

---

#### Paso 3.1: Crear un Service NodePort para el Frontend

**Objetivo:** Exponer el frontend fuera del clúster mediante un Service NodePort, que abre un puerto en el rango 30000–32767 en todos los nodos del clúster.

**Instrucciones:**

1. Crea el Service NodePort para el frontend:

```bash
cat <<'EOF' > frontend-service-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-nodeport
  namespace: lab06
  labels:
    app: frontend
    exposure: external
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - name: http
    protocol: TCP
    port: 80          # Puerto del Service (ClusterIP interno)
    targetPort: 80    # Puerto del contenedor
    nodePort: 30080   # Puerto expuesto en cada nodo (rango 30000-32767)
EOF

kubectl apply -f frontend-service-nodeport.yaml
```

2. Verifica el Service creado:

```bash
kubectl get service frontend-nodeport -n lab06
```

**Salida esperada:**
```
NAME                 TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
frontend-nodeport    NodePort   10.96.z.z     <none>        80:30080/TCP   20s
```

3. Obtén la URL de acceso usando Minikube:

```bash
# En Linux con driver Docker, obtener la URL del NodePort
minikube service frontend-nodeport --namespace=lab06 --url

# Alternativamente, obtener la IP del nodo Minikube
MINIKUBE_IP=$(minikube ip)
echo "URL de acceso: http://$MINIKUBE_IP:30080"
```

4. Verifica el acceso externo desde el host:

```bash
# Acceso al frontend via NodePort
MINIKUBE_IP=$(minikube ip)
curl -s http://$MINIKUBE_IP:30080 | grep -o '<h1>.*</h1>'
```

**Salida esperada:**
```
<h1>FRONTEND v2.0</h1>
```

> **⚠️ Nota para macOS/Windows con WSL2:** Al usar el driver Docker en macOS o Windows, la IP directa del nodo puede no ser accesible. Usa el comando `minikube service frontend-nodeport --namespace=lab06` que abre un túnel automáticamente y proporciona la URL correcta.

---

#### Paso 3.2: Concepto LoadBalancer y sus limitaciones en Minikube

**Objetivo:** Crear un Service LoadBalancer para comprender su comportamiento en un entorno local (Minikube) versus un entorno cloud real.

**Instrucciones:**

1. Crea un Service LoadBalancer para el backend:

```bash
cat <<'EOF' > backend-service-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-lb
  namespace: lab06
  annotations:
    # En un cloud real (GKE, EKS, AKS), esta anotación configura el LB externo
    # En Minikube, permanecerá en estado Pending sin el addon tunnel
    kubernetes.io/description: "LoadBalancer para demostración - requiere minikube tunnel"
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
EOF

kubectl apply -f backend-service-loadbalancer.yaml
```

2. Observa el estado del Service LoadBalancer:

```bash
kubectl get service backend-lb -n lab06 -w
```

**Salida esperada (sin tunnel activo):**
```
NAME         TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
backend-lb   LoadBalancer   10.96.w.w     <pending>     80:3xxxx/TCP   30s
```

> **Concepto clave:** En Minikube, el `EXTERNAL-IP` permanece en `<pending>` porque no hay un proveedor de nube que asigne una IP pública. En producción (GKE, EKS, AKS), el controlador de nube asignaría automáticamente una IP pública. Para simularlo en Minikube, se puede usar `minikube tunnel` en otra terminal.

3. (Opcional) Simula el comportamiento en una terminal separada:

```bash
# En una SEGUNDA terminal, ejecutar:
minikube tunnel
# Esto asignará una IP local al LoadBalancer

# En la terminal principal, verificar:
kubectl get service backend-lb -n lab06
# Ahora mostrará una EXTERNAL-IP asignada (127.0.0.1 o similar)
```

4. Cancela la observación con `Ctrl+C` y continúa con la Parte 4.

---

### Parte 4: NGINX Ingress Controller y Reglas de Ingress

---

#### Paso 4.1: Instalar el NGINX Ingress Controller

**Objetivo:** Habilitar el addon de Ingress de Minikube para instalar el NGINX Ingress Controller, que actuará como punto de entrada único para el enrutamiento HTTP/HTTPS basado en reglas.

**Instrucciones:**

1. Habilita el addon de Ingress en Minikube:

```bash
minikube addons enable ingress
```

2. Espera a que el Ingress Controller esté completamente operativo (puede tardar 2–3 minutos):

```bash
# Monitorear el estado del pod del Ingress Controller
kubectl get pods -n ingress-nginx -w
```

**Espera hasta ver esta salida:**
```
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxxxx        0/1     Completed   0          2m
ingress-nginx-admission-patch-xxxxx         0/1     Completed   0          2m
ingress-nginx-controller-xxxxxxxxx-xxxxx    1/1     Running     0          2m
```

3. Presiona `Ctrl+C` cuando el controller esté en estado `Running` y verifica los recursos del namespace:

```bash
kubectl get all -n ingress-nginx
```

4. Verifica que el Ingress Controller tiene una dirección IP asignada:

```bash
kubectl get service ingress-nginx-controller -n ingress-nginx
```

**Salida esperada:**
```
NAME                       TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller   NodePort   10.96.x.x     <none>        80:3xxxx/TCP,443:3xxxx/TCP   3m
```

---

#### Paso 4.2: Ingress con Enrutamiento por Path

**Objetivo:** Crear una regla de Ingress que enrute el tráfico hacia diferentes backends según el path de la URL: `/api` → backend, `/` → frontend.

**Instrucciones:**

1. Crea el manifiesto de Ingress con enrutamiento por path:

```bash
cat <<'EOF' > ingress-path-routing.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  namespace: lab06
  annotations:
    # Reescribir el path antes de enviarlo al backend
    # Sin esto, /api se enviaría tal cual al Pod, que no tiene esa ruta
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    # Deshabilitar redirección automática HTTP→HTTPS para pruebas locales
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      # Tráfico a /api o /api/* → Service backend
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
      # Tráfico a / → Service frontend (ruta catch-all)
      - path: /()(.*)
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
EOF

kubectl apply -f ingress-path-routing.yaml
```

2. Verifica el Ingress creado:

```bash
kubectl get ingress path-routing -n lab06
kubectl describe ingress path-routing -n lab06
```

**Salida esperada:**
```
NAME           CLASS   HOSTS   ADDRESS          PORTS   AGE
path-routing   nginx   *       192.168.49.2     80      30s

Rules:
  Host        Path            Backends
  ----        ----            --------
  *           /api(/|$)(.*)   backend-svc:80 (10.244.1.x:80,10.244.2.x:80)
              /()(.*)         frontend-svc:80 (10.244.1.y:80,10.244.2.y:80)
```

3. Obtén la IP del Ingress Controller y prueba el enrutamiento:

```bash
# Obtener la IP del Ingress (ADDRESS en el get ingress)
INGRESS_IP=$(kubectl get ingress path-routing -n lab06 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Si está vacío, usar la IP de Minikube directamente
if [ -z "$INGRESS_IP" ]; then
  INGRESS_IP=$(minikube ip)
fi

echo "IP del Ingress: $INGRESS_IP"

# Probar enrutamiento al frontend (/)
echo "=== Acceso al FRONTEND (/) ==="
curl -s http://$INGRESS_IP/ | grep -o '<h1>.*</h1>'

# Probar enrutamiento al backend (/api)
echo "=== Acceso al BACKEND (/api) ==="
curl -s http://$INGRESS_IP/api | grep -o '<h1>.*</h1>'
```

**Salida esperada:**
```
=== Acceso al FRONTEND (/) ===
<h1>FRONTEND v2.0</h1>

=== Acceso al BACKEND (/api) ===
<h1>BACKEND API v1.0</h1>
```

---

#### Paso 4.3: Desplegar Servicios Adicionales para Enrutamiento por Host

**Objetivo:** Preparar dos servicios adicionales (`app1` y `app2`) que serán expuestos mediante virtual hosting en el Ingress, demostrando el enrutamiento basado en el header `Host` de HTTP.

**Instrucciones:**

1. Crea los Deployments y Services para app1 y app2:

```bash
cat <<'EOF' > apps-host-routing.yaml
# Deployment app1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: lab06
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app1
        image: nginx:1.25
        ports:
        - containerPort: 80
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo '<html><body style="background:#3498db"><h1>APP 1 - app1.local</h1><p>Host-based routing funcionando!</p></body></html>' > /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
---
# Service app1
apiVersion: v1
kind: Service
metadata:
  name: app1-svc
  namespace: lab06
spec:
  type: ClusterIP
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 80
---
# Deployment app2
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: lab06
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app2
        image: nginx:1.26
        ports:
        - containerPort: 80
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo '<html><body style="background:#2ecc71"><h1>APP 2 - app2.local</h1><p>Virtual hosting con Ingress!</p></body></html>' > /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
---
# Service app2
apiVersion: v1
kind: Service
metadata:
  name: app2-svc
  namespace: lab06
spec:
  type: ClusterIP
  selector:
    app: app2
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl apply -f apps-host-routing.yaml
```

2. Verifica que los nuevos Pods están en estado `Running`:

```bash
kubectl get pods -n lab06 -l 'app in (app1,app2)'
kubectl get services -n lab06 | grep -E "app1|app2"
```

**Salida esperada:**
```
NAME    READY   STATUS    RESTARTS   AGE
app1-x  1/1     Running   0          30s
app2-x  1/1     Running   0          30s

app1-svc   ClusterIP   10.96.a.a   <none>   80/TCP   30s
app2-svc   ClusterIP   10.96.b.b   <none>   80/TCP   30s
```

---

#### Paso 4.4: Ingress con Enrutamiento por Host (Virtual Hosting)

**Objetivo:** Crear reglas de Ingress que enruten el tráfico según el header `Host` de la petición HTTP: `app1.local` → app1-svc, `app2.local` → app2-svc.

**Instrucciones:**

1. Crea el Ingress con enrutamiento por host:

```bash
cat <<'EOF' > ingress-host-routing.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing
  namespace: lab06
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  # Regla para app1.local → app1-svc
  - host: app1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-svc
            port:
              number: 80
  # Regla para app2.local → app2-svc
  - host: app2.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-svc
            port:
              number: 80
EOF

kubectl apply -f ingress-host-routing.yaml
```

2. Verifica los Ingress creados:

```bash
kubectl get ingress -n lab06
```

**Salida esperada:**
```
NAME           CLASS   HOSTS                 ADDRESS          PORTS   AGE
path-routing   nginx   *                     192.168.49.2     80      5m
host-routing   nginx   app1.local,app2.local 192.168.49.2     80      15s
```

3. Configura `/etc/hosts` para resolver los dominios locales hacia la IP de Minikube:

```bash
# Obtener la IP de Minikube
MINIKUBE_IP=$(minikube ip)
echo "IP de Minikube: $MINIKUBE_IP"

# Agregar entradas al /etc/hosts (requiere sudo)
echo "# Kubernetes Lab06 - Host-based Ingress routing" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP app1.local app2.local" | sudo tee -a /etc/hosts

# Verificar que las entradas se agregaron correctamente
grep -E "app1.local|app2.local" /etc/hosts
```

**Salida esperada:**
```
192.168.49.2 app1.local app2.local
```

4. Prueba el enrutamiento por host:

```bash
# Acceso a app1.local
echo "=== Acceso a app1.local ==="
curl -s http://app1.local | grep -o '<h1>.*</h1>'

# Acceso a app2.local
echo "=== Acceso a app2.local ==="
curl -s http://app2.local | grep -o '<h1>.*</h1>'

# Verificar que el header Host determina el enrutamiento
echo "=== Forzando header Host manualmente ==="
curl -s -H "Host: app1.local" http://$MINIKUBE_IP | grep -o '<h1>.*</h1>'
curl -s -H "Host: app2.local" http://$MINIKUBE_IP | grep -o '<h1>.*</h1>'
```

**Salida esperada:**
```
=== Acceso a app1.local ===
<h1>APP 1 - app1.local</h1>

=== Acceso a app2.local ===
<h1>APP 2 - app2.local</h1>

=== Forzando header Host manualmente ===
<h1>APP 1 - app1.local</h1>
<h1>APP 2 - app2.local</h1>
```

---

#### Paso 4.5: Explorar Anotaciones de Ingress

**Objetivo:** Aplicar y verificar anotaciones de Ingress para configuración avanzada del controlador NGINX, incluyendo `rewrite-target` y `ssl-redirect`.

**Instrucciones:**

1. Inspecciona las anotaciones actuales del Ingress de path-routing:

```bash
kubectl describe ingress path-routing -n lab06 | grep -A 10 "Annotations:"
```

2. Agrega una anotación de rate limiting al Ingress existente:

```bash
kubectl annotate ingress path-routing \
  --namespace=lab06 \
  nginx.ingress.kubernetes.io/limit-rps="10" \
  --overwrite
```

3. Crea un Ingress adicional que demuestre la redirección de paths con `rewrite-target`:

```bash
cat <<'EOF' > ingress-rewrite-demo.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-demo
  namespace: lab06
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    # Esta anotación reescribe el path: /health-check → /health en el Pod
    nginx.ingress.kubernetes.io/rewrite-target: /health
spec:
  ingressClassName: nginx
  rules:
  - host: app1.local
    http:
      paths:
      - path: /health-check
        pathType: Exact
        backend:
          service:
            name: backend-svc
            port:
              number: 80
EOF

kubectl apply -f ingress-rewrite-demo.yaml
```

4. Verifica el rewrite funcionando:

```bash
# Sin rewrite, /health-check no existe en el backend → 404
# Con rewrite-target: /health, la petición llega al Pod como /health → 200
curl -sv http://app1.local/health-check 2>&1 | grep -E "< HTTP|<h1>"
```

**Salida esperada:**
```
< HTTP/1.1 200 OK
<h1>API Health OK</h1>
```

5. Verifica el estado completo de todos los Ingress del namespace:

```bash
kubectl get ingress -n lab06 -o wide
kubectl describe ingress -n lab06 | grep -E "Name:|Host:|Path:|Service:"
```

---

### Parte 5: kubectl port-forward como Alternativa de Debugging

---

#### Paso 5.1: Usar port-forward para Debugging

**Objetivo:** Demostrar `kubectl port-forward` como herramienta de debugging que permite acceder a un Service o Pod directamente desde el host sin necesidad de NodePort ni Ingress.

**Instrucciones:**

1. Crea un port-forward hacia el Service backend (ClusterIP):

```bash
# Ejecutar en segundo plano con &
kubectl port-forward service/backend-svc 8080:80 --namespace=lab06 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"

# Esperar un momento para que se establezca la conexión
sleep 2
```

2. Accede al backend a través del port-forward:

```bash
# Acceso al backend via port-forward (localhost:8080 → backend-svc:80)
curl -s http://localhost:8080 | grep -o '<h1>.*</h1>'
```

**Salida esperada:**
```
Forwarding from 127.0.0.1:8080 -> 80
<h1>BACKEND API v1.0</h1>
```

3. Termina el port-forward:

```bash
kill $PF_PID 2>/dev/null
echo "Port-forward detenido"
```

> **Concepto clave:** `kubectl port-forward` es ideal para debugging porque no requiere modificar los Services ni crear reglas de Ingress. Sin embargo, **no es adecuado para producción** ya que el túnel pasa por el API Server de Kubernetes y tiene limitaciones de rendimiento.

---

## Validación y Pruebas Finales

Ejecuta el siguiente script de validación completo para verificar que todos los componentes del laboratorio funcionan correctamente:

```bash
#!/bin/bash
echo "========================================"
echo "  VALIDACIÓN LAB 06-00-01"
echo "========================================"

NAMESPACE="lab06"
MINIKUBE_IP=$(minikube ip)
PASS=0
FAIL=0

check() {
  local description="$1"
  local command="$2"
  local expected="$3"
  
  result=$(eval "$command" 2>/dev/null)
  if echo "$result" | grep -q "$expected"; then
    echo "✅ PASS: $description"
    ((PASS++))
  else
    echo "❌ FAIL: $description"
    echo "   Esperado: '$expected'"
    echo "   Obtenido: '$result'"
    ((FAIL++))
  fi
}

echo ""
echo "--- Verificando Deployments ---"
check "Deployment backend (2 réplicas)" \
  "kubectl get deployment backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}'" "2"
check "Deployment frontend (2 réplicas)" \
  "kubectl get deployment frontend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}'" "2"

echo ""
echo "--- Verificando Services ---"
check "Service backend-svc (ClusterIP)" \
  "kubectl get svc backend-svc -n $NAMESPACE -o jsonpath='{.spec.type}'" "ClusterIP"
check "Service frontend-svc (ClusterIP)" \
  "kubectl get svc frontend-svc -n $NAMESPACE -o jsonpath='{.spec.type}'" "ClusterIP"
check "Service frontend-nodeport (NodePort 30080)" \
  "kubectl get svc frontend-nodeport -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}'" "30080"

echo ""
echo "--- Verificando Endpoints ---"
check "Endpoints backend-svc (2 endpoints)" \
  "kubectl get endpoints backend-svc -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' | grep -o 'ip' | wc -l" "2"

echo ""
echo "--- Verificando Ingress ---"
check "Ingress path-routing existe" \
  "kubectl get ingress path-routing -n $NAMESPACE -o jsonpath='{.metadata.name}'" "path-routing"
check "Ingress host-routing existe" \
  "kubectl get ingress host-routing -n $NAMESPACE -o jsonpath='{.metadata.name}'" "host-routing"

echo ""
echo "--- Verificando Conectividad HTTP ---"
check "NodePort frontend accesible" \
  "curl -s -o /dev/null -w '%{http_code}' http://$MINIKUBE_IP:30080" "200"
check "Ingress path / → frontend" \
  "curl -s http://$MINIKUBE_IP/ | grep -o 'FRONTEND'" "FRONTEND"
check "Ingress path /api → backend" \
  "curl -s http://$MINIKUBE_IP/api | grep -o 'BACKEND'" "BACKEND"
check "Ingress host app1.local" \
  "curl -s -H 'Host: app1.local' http://$MINIKUBE_IP | grep -o 'APP 1'" "APP 1"
check "Ingress host app2.local" \
  "curl -s -H 'Host: app2.local' http://$MINIKUBE_IP | grep -o 'APP 2'" "APP 2"

echo ""
echo "--- Verificando DNS Interno ---"
check "CoreDNS operativo" \
  "kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.phase}'" "Running"

echo ""
echo "========================================"
echo "  RESULTADO: $PASS pasaron, $FAIL fallaron"
echo "========================================"

if [ $FAIL -eq 0 ]; then
  echo "🎉 ¡Laboratorio completado exitosamente!"
else
  echo "⚠️  Revisa los items fallidos antes de continuar."
fi
```

```bash
# Guarda el script y ejecútalo
chmod +x validate-lab06.sh
bash validate-lab06.sh
```

**Salida esperada al completar exitosamente:**
```
========================================
  VALIDACIÓN LAB 06-00-01
========================================
✅ PASS: Deployment backend (2 réplicas)
✅ PASS: Deployment frontend (2 réplicas)
✅ PASS: Service backend-svc (ClusterIP)
✅ PASS: Service frontend-svc (ClusterIP)
✅ PASS: Service frontend-nodeport (NodePort 30080)
✅ PASS: Endpoints backend-svc (2 endpoints)
✅ PASS: Ingress path-routing existe
✅ PASS: Ingress host-routing existe
✅ PASS: NodePort frontend accesible
✅ PASS: Ingress path / → frontend
✅ PASS: Ingress path /api → backend
✅ PASS: Ingress host app1.local
✅ PASS: Ingress host app2.local
✅ PASS: CoreDNS operativo
========================================
  RESULTADO: 14 pasaron, 0 fallaron
========================================
🎉 ¡Laboratorio completado exitosamente!
```

---

## Troubleshooting

### Problema 1: El Ingress devuelve `404 Not Found` o `503 Service Unavailable`

**Síntomas:**
- `curl http://<minikube-ip>/api` devuelve `404 Not Found` o `503 Service Unavailable`
- `kubectl get ingress` muestra el Ingress con ADDRESS asignada pero las peticiones fallan
- El log del Ingress Controller muestra `no endpoints available for service`

**Causa probable:**
Existen dos causas frecuentes: (1) El selector del Service no coincide con las etiquetas de los Pods (Endpoints vacíos), o (2) El NGINX Ingress Controller aún no ha terminado de sincronizar las reglas después de aplicar el manifiesto.

**Diagnóstico:**
```bash
# 1. Verificar que los Endpoints del Service tienen IPs asignadas
kubectl get endpoints backend-svc -n lab06
# Si muestra "<none>" o la lista está vacía, el selector es incorrecto

# 2. Comparar las etiquetas del Service con las del Pod
kubectl get svc backend-svc -n lab06 -o jsonpath='{.spec.selector}'
kubectl get pods -n lab06 -l app=backend --show-labels

# 3. Revisar los logs del Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=20

# 4. Verificar que el Ingress Controller está en Running
kubectl get pods -n ingress-nginx
```

**Solución:**
```bash
# Si los Endpoints están vacíos, corregir el selector del Service
# Ejemplo: si el Pod tiene etiqueta "app: backend" pero el Service busca "app: backend-api"
kubectl patch service backend-svc -n lab06 \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend"}]'

# Verificar que los Endpoints se poblaron
kubectl get endpoints backend-svc -n lab06

# Si el problema es timing, esperar y reintentar
sleep 30 && curl -v http://$(minikube ip)/api
```

---

### Problema 2: `nslookup backend-svc` falla dentro del Pod de prueba

**Síntomas:**
- Dentro del Pod `dns-test`, `nslookup backend-svc` devuelve `nslookup: can't resolve 'backend-svc'`
- `wget http://backend-svc` falla con `bad address 'backend-svc'`
- El Pod de prueba fue creado en un namespace diferente al de los Services

**Causa probable:**
El Pod de prueba fue creado en el namespace `default` en lugar de `lab06`. La resolución DNS por nombre corto solo funciona dentro del mismo namespace. Si el Pod está en `default` y el Service en `lab06`, el nombre corto `backend-svc` no resolverá porque el `search` en `/etc/resolv.conf` busca en `default.svc.cluster.local`, no en `lab06.svc.cluster.local`.

**Diagnóstico:**
```bash
# Verificar en qué namespace está el Pod de prueba
kubectl get pod dns-test --all-namespaces

# Desde dentro del Pod, verificar el search domain en resolv.conf
# (si el Pod aún existe)
kubectl exec -n default dns-test -- cat /etc/resolv.conf
# Si muestra "search default.svc.cluster.local", el Pod está en namespace incorrecto
```

**Solución:**
```bash
# Opción 1: Crear el Pod de prueba en el namespace correcto
kubectl run dns-test \
  --image=busybox:latest \
  --restart=Never \
  --namespace=lab06 \
  -it --rm \
  -- sh

# Dentro del Pod (ahora en namespace lab06):
nslookup backend-svc                              # Nombre corto → funciona
nslookup backend-svc.lab06.svc.cluster.local      # FQDN → siempre funciona

# Opción 2: Si el Pod está en namespace diferente, usar el FQDN completo
# El FQDN siempre funciona independientemente del namespace del Pod
nslookup backend-svc.lab06.svc.cluster.local

# Verificar que CoreDNS está operativo
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
```

---

## Limpieza

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
# 1. Eliminar las entradas agregadas a /etc/hosts
sudo sed -i '/# Kubernetes Lab06/d' /etc/hosts
sudo sed -i '/app1.local app2.local/d' /etc/hosts

# Verificar que se eliminaron
grep -E "app1.local|app2.local" /etc/hosts || echo "Entradas eliminadas correctamente"

# 2. Eliminar todos los recursos del namespace lab06
kubectl delete namespace lab06

# Este comando elimina en cascada: Deployments, Pods, Services, Ingress, etc.
# Verificar la eliminación (puede tardar 30-60 segundos)
kubectl get namespace lab06
# Debe mostrar "Error from server (NotFound)" cuando termine

# 3. Deshabilitar el addon de Ingress (opcional, comentar si lo necesitas en labs posteriores)
# minikube addons disable ingress

# 4. Restaurar el namespace por defecto del contexto
kubectl config set-context --current --namespace=default

# 5. Limpiar archivos YAML del laboratorio (opcional)
rm -f backend-deployment.yaml frontend-deployment.yaml \
      backend-service-clusterip.yaml frontend-service-clusterip.yaml \
      frontend-service-nodeport.yaml backend-service-loadbalancer.yaml \
      apps-host-routing.yaml ingress-path-routing.yaml \
      ingress-host-routing.yaml ingress-rewrite-demo.yaml \
      validate-lab06.sh

echo "✅ Limpieza completada"
```

> **⚠️ Importante:** Si planeas continuar con laboratorios posteriores que requieran el Ingress Controller, **no deshabilites el addon**. El addon de Ingress puede ser reutilizado entre laboratorios.

---

## Resumen

En este laboratorio construiste una arquitectura de networking completa en Kubernetes, aplicando los siguientes conceptos clave:

| Concepto | Lo que aprendiste |
|---|---|
| **Red plana de Kubernetes** | Los Pods se comunican directamente por IP sin NAT, confirmado con `kubectl exec` y `curl` entre Pods en nodos distintos |
| **Service ClusterIP** | Proporciona una IP virtual estable y balanceo de carga interno; solo accesible dentro del clúster |
| **DNS interno (CoreDNS)** | Registra automáticamente los Services con el formato FQDN `<svc>.<ns>.svc.cluster.local`; verificado con `nslookup` desde un Pod de prueba |
| **Service NodePort** | Expone el Service en un puerto del rango 30000–32767 en todos los nodos; accesible desde fuera del clúster |
| **Service LoadBalancer** | Solicita una IP externa al proveedor de nube; en Minikube permanece `<pending>` sin `minikube tunnel` |
| **NGINX Ingress Controller** | Punto de entrada único HTTP/HTTPS; instalado via `minikube addons enable ingress` |
| **Ingress por path** | `rewrite-target` permite mapear `/api` → backend y `/` → frontend con reescritura de paths |
| **Ingress por host** | Virtual hosting: `app1.local` → app1-svc, `app2.local` → app2-svc usando el header `Host` HTTP |
| **Anotaciones de Ingress** | `ssl-redirect`, `rewrite-target`, `limit-rps` configuran el comportamiento avanzado del controlador NGINX |
| **kubectl port-forward** | Herramienta de debugging que tuneliza tráfico del host a un Service/Pod sin modificar la configuración del clúster |

### Arquitectura Final Construida

```
Internet / Host
     │
     ▼
[NodePort :30080] ──────────────────────► frontend-svc (ClusterIP)
                                               │
[Ingress Controller]                           ▼
  path: /    ──────────────────────────► frontend-svc ──► Pod frontend (x2)
  path: /api ──────────────────────────► backend-svc  ──► Pod backend  (x2)
  host: app1.local ────────────────────► app1-svc     ──► Pod app1
  host: app2.local ────────────────────► app2-svc     ──► Pod app2
                                               │
[CoreDNS]                                      ▼
  backend-svc.lab06.svc.cluster.local ──► 10.96.x.x (ClusterIP)
```

### Recursos Adicionales

- [Documentación oficial: Services en Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Documentación oficial: Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Documentación oficial: DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Anotaciones del NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Documentación de Minikube: addons](https://minikube.sigs.k8s.io/docs/handbook/addons/)

---
*Lab 06-00-01 — Módulo 6: Networking y Exposición de Aplicaciones | Kubernetes CKA Preparation*

---

---LAB_START---
LAB_ID: 06-00-02
---MARKDOWN---
# Práctica complementaria 6.1 — Diagnóstico de Service y Endpoints

## 1. Metadatos

| Campo        | Detalle                          |
|--------------|----------------------------------|
| **Duración** | 17 minutos                       |
| **Complejidad** | Media                         |
| **Nivel Bloom** | Aplicar (Apply)              |
| **Módulo**   | 6 — Redes en Kubernetes          |
| **Sección**  | 6.2 — Services y Endpoints       |

---

## 2. Descripción General

En este laboratorio el estudiante enfrentará tres escenarios de fallo reales en Services de Kubernetes: un selector de etiquetas incorrecto que produce endpoints vacíos, un `targetPort` mal configurado que impide el enrutamiento del tráfico, y pods en estado no-Ready por una `readinessProbe` fallida. Usando `kubectl describe`, `kubectl get endpoints` y pruebas de conectividad con `curl` desde un pod de diagnóstico, el estudiante diagnosticará cada fallo, identificará la causa raíz y aplicará la corrección correspondiente, validando que el tráfico fluye correctamente al final de cada escenario.

---

## 3. Objetivos de Aprendizaje

- [ ] Identificar la relación entre un Service y sus Endpoints inspeccionando selectores de etiquetas y el recurso `Endpoints` asociado.
- [ ] Diagnosticar por qué un Service ClusterIP no enruta tráfico cuando el selector no coincide con las etiquetas del Pod destino.
- [ ] Detectar y corregir un `targetPort` incorrecto que impide que el Service alcance el puerto real del contenedor.
- [ ] Reconocer cómo una `readinessProbe` fallida excluye un Pod de los Endpoints de un Service NodePort.
- [ ] Validar la conectividad de un Service usando `curl` desde un pod de diagnóstico dentro del clúster.

---

## 4. Prerrequisitos

### Conocimiento previo
- Comprensión de qué es un Service de Kubernetes y sus tipos (ClusterIP, NodePort).
- Familiaridad con etiquetas (`labels`) y selectores (`selector`) en Kubernetes.
- Capacidad de leer e interpretar manifiestos YAML de Services y Pods.
- Conocimiento básico de los campos `port`, `targetPort` y `containerPort`.
- Haber completado el Lab 06-00-01 o tener el clúster multi-nodo levantado.

### Acceso requerido
- Clúster Minikube con al menos 1 nodo activo (se recomienda 2–3 nodos).
- `kubectl` configurado y apuntando al clúster local.
- Acceso a Internet para descargar imágenes (`nginx:1.25`, `busybox:latest`).

---

## 5. Entorno de Laboratorio

### Requisitos de hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU     | 4 núcleos | 8 núcleos |
| RAM     | 8 GB   | 16 GB       |
| Disco   | 40 GB libres | 60 GB SSD |

### Software requerido

| Herramienta | Versión mínima |
|-------------|---------------|
| Minikube    | 1.31.x        |
| kubectl     | 1.28.x        |
| Docker Engine | 24.x        |
| curl        | 7.x           |

### Verificación del entorno

Antes de iniciar, confirma que el clúster está activo:

```bash
# Verificar estado del clúster
minikube status

# Si el clúster no está corriendo, iniciarlo
minikube start --nodes=2 --driver=docker --cpus=2 --memory=2048

# Confirmar nodos disponibles
kubectl get nodes
```

**Salida esperada:**

```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   Xm    v1.28.x
minikube-m02   Ready    <none>          Xm    v1.28.x
```

### Preparación del namespace y manifiestos del laboratorio

Ejecuta el siguiente bloque completo para crear el namespace `lab-svc-debug` y desplegar los tres escenarios de fallo. Copia y pega cada sección en orden.

```bash
# Crear el namespace dedicado para este laboratorio
kubectl create namespace lab-svc-debug
```

#### Escenario 1 — Selector incorrecto (endpoints vacíos)

```bash
cat <<'EOF' | kubectl apply -f -
# Deployment con etiqueta correcta: app=web-server
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: lab-svc-debug
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
# Service con selector INCORRECTO: app=webserver (sin guión)
apiVersion: v1
kind: Service
metadata:
  name: svc-scenario1
  namespace: lab-svc-debug
spec:
  selector:
    app: webserver
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

#### Escenario 2 — targetPort incorrecto

```bash
cat <<'EOF' | kubectl apply -f -
# Deployment con nginx escuchando en puerto 80
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: lab-svc-debug
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
# Service con targetPort INCORRECTO: apunta al puerto 8080 en lugar de 80
apiVersion: v1
kind: Service
metadata:
  name: svc-scenario2
  namespace: lab-svc-debug
spec:
  selector:
    app: api-server
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF
```

#### Escenario 3 — Pods no-Ready por readinessProbe fallida

```bash
cat <<'EOF' | kubectl apply -f -
# Deployment con readinessProbe que apunta a una ruta inexistente
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: lab-svc-debug
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-app
  template:
    metadata:
      labels:
        app: backend-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
          failureThreshold: 2
---
# Service NodePort (selector correcto, pero pods no estarán Ready)
apiVersion: v1
kind: Service
metadata:
  name: svc-scenario3
  namespace: lab-svc-debug
spec:
  selector:
    app: backend-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30083
  type: NodePort
EOF
```

#### Pod de diagnóstico

```bash
# Desplegar pod de diagnóstico con curl disponible
kubectl run diag-pod \
  --image=busybox:latest \
  --restart=Never \
  --namespace=lab-svc-debug \
  -- sleep 3600
```

Espera a que todos los recursos estén creados antes de continuar:

```bash
# Esperar a que los Deployments estén disponibles (excepto scenario3 que fallará)
kubectl wait deployment/web-server --for=condition=Available \
  --namespace=lab-svc-debug --timeout=60s

kubectl wait deployment/api-server --for=condition=Available \
  --namespace=lab-svc-debug --timeout=60s

# Verificar estado general
kubectl get all -n lab-svc-debug
```

> **Nota:** El Deployment `backend-app` del Escenario 3 mostrará `0/2 Ready` — esto es esperado y forma parte del escenario de fallo.

---

## 6. Procedimiento Paso a Paso

---

### Paso 1: Reconocimiento inicial del entorno

**Objetivo:** Obtener una visión general de todos los recursos desplegados en el namespace y sus estados actuales antes de comenzar el diagnóstico.

**Instrucciones:**

1. Lista todos los recursos del namespace con sus etiquetas:

```bash
kubectl get all -n lab-svc-debug -o wide
```

2. Muestra los Pods con sus etiquetas explícitas:

```bash
kubectl get pods -n lab-svc-debug --show-labels
```

3. Lista todos los Services y sus selectores:

```bash
kubectl get services -n lab-svc-debug
```

4. Obtén una vista rápida de todos los Endpoints del namespace:

```bash
kubectl get endpoints -n lab-svc-debug
```

**Salida esperada:**

```
NAME           ENDPOINTS           AGE
svc-scenario1  <none>              Xm
svc-scenario2  10.244.x.x:8080     Xm
svc-scenario3  <none>              Xm
```

> **Observación clave:** `svc-scenario1` y `svc-scenario3` muestran `<none>` en endpoints. `svc-scenario2` muestra una IP pero con el puerto incorrecto `8080`. Estos son los tres fallos que diagnosticarás en los siguientes pasos.

**Verificación:**

```bash
# Confirmar que el pod de diagnóstico está Running
kubectl get pod diag-pod -n lab-svc-debug
```

---

### Paso 2: Diagnóstico del Escenario 1 — Selector incorrecto

**Objetivo:** Identificar por qué `svc-scenario1` no tiene endpoints, rastrear la discrepancia entre el selector del Service y las etiquetas de los Pods, y aplicar la corrección.

**Instrucciones:**

1. Inspecciona el Service para ver su selector actual:

```bash
kubectl describe service svc-scenario1 -n lab-svc-debug
```

Localiza la sección `Selector:` en la salida. Anota el valor que ves.

2. Inspecciona las etiquetas reales de los Pods del Deployment `web-server`:

```bash
kubectl get pods -n lab-svc-debug -l app=web-server --show-labels
```

3. Compara explícitamente el selector del Service con las etiquetas del Pod:

```bash
# Ver selector del Service (campo .spec.selector)
kubectl get service svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.spec.selector}' && echo

# Ver etiquetas del Pod destino
kubectl get pods -n lab-svc-debug \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'
```

4. Confirma que los endpoints están vacíos:

```bash
kubectl get endpoints svc-scenario1 -n lab-svc-debug
kubectl describe endpoints svc-scenario1 -n lab-svc-debug
```

5. Realiza una prueba de conectividad desde el pod de diagnóstico para confirmar el fallo:

```bash
# Obtener la ClusterIP del Service
SVC1_IP=$(kubectl get service svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP svc-scenario1: $SVC1_IP"

# Intentar conectar desde el pod de diagnóstico (debe fallar o timeout)
kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 http://$SVC1_IP:80 || echo "FALLO CONFIRMADO: Sin endpoints"
```

**Salida esperada (fallo confirmado):**

```
wget: can't connect to remote host (10.96.x.x): Connection refused
FALLO CONFIRMADO: Sin endpoints
```

**Diagnóstico confirmado:** El selector del Service es `app: webserver` pero los Pods tienen la etiqueta `app: web-server` (con guión). La diferencia tipográfica rompe la asociación.

6. **Aplica la corrección** — Parchea el selector del Service para que coincida con la etiqueta real:

```bash
kubectl patch service svc-scenario1 -n lab-svc-debug \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/selector/app","value":"web-server"}]'
```

7. Verifica que los endpoints aparecen tras la corrección:

```bash
kubectl get endpoints svc-scenario1 -n lab-svc-debug
```

**Salida esperada (corregido):**

```
NAME           ENDPOINTS                         AGE
svc-scenario1  10.244.x.x:80,10.244.x.x:80      Xm
```

8. Valida la conectividad desde el pod de diagnóstico:

```bash
SVC1_IP=$(kubectl get service svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')

kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 http://$SVC1_IP:80 2>/dev/null | head -5
```

**Verificación:**

```bash
# Debe mostrar la página de bienvenida de nginx
# Confirmar que el selector fue actualizado
kubectl get service svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.spec.selector}' && echo
# Salida esperada: {"app":"web-server"}
```

---

### Paso 3: Diagnóstico del Escenario 2 — targetPort incorrecto

**Objetivo:** Identificar que `svc-scenario2` tiene endpoints registrados pero el tráfico no llega al contenedor porque el `targetPort` no coincide con el `containerPort` real del Pod.

**Instrucciones:**

1. Inspecciona el Service para revisar la configuración de puertos:

```bash
kubectl describe service svc-scenario2 -n lab-svc-debug
```

Localiza la sección `Port:` y `TargetPort:` en la salida.

2. Verifica que hay endpoints registrados (el selector sí coincide):

```bash
kubectl get endpoints svc-scenario2 -n lab-svc-debug
```

> **Observación:** Hay endpoints registrados, lo que indica que el selector es correcto. Sin embargo, el puerto en los endpoints es `8080`.

3. Inspecciona el Pod destino para ver el puerto real del contenedor:

```bash
# Obtener el nombre del pod del deployment api-server
kubectl get pods -n lab-svc-debug -l app=api-server

# Describir el pod para ver containerPort
kubectl describe pod -n lab-svc-debug -l app=api-server | grep -A5 "Ports:"
```

4. Confirma el fallo de conectividad desde el pod de diagnóstico:

```bash
SVC2_IP=$(kubectl get service svc-scenario2 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP svc-scenario2: $SVC2_IP"

kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 http://$SVC2_IP:80 || echo "FALLO CONFIRMADO: targetPort incorrecto"
```

**Salida esperada (fallo confirmado):**

```
wget: can't connect to remote host (10.96.x.x): Connection refused
FALLO CONFIRMADO: targetPort incorrecto
```

**Diagnóstico confirmado:** El Service apunta al puerto `8080` en el contenedor (`targetPort: 8080`), pero nginx escucha en el puerto `80` (`containerPort: 80`). Aunque hay endpoints, el tráfico llega al puerto equivocado y es rechazado.

5. **Aplica la corrección** — Actualiza el `targetPort` al valor correcto `80`:

```bash
kubectl patch service svc-scenario2 -n lab-svc-debug \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":80}]'
```

6. Confirma que los endpoints ahora muestran el puerto correcto:

```bash
kubectl get endpoints svc-scenario2 -n lab-svc-debug
```

**Salida esperada (corregido):**

```
NAME           ENDPOINTS            AGE
svc-scenario2  10.244.x.x:80        Xm
```

7. Valida la conectividad:

```bash
SVC2_IP=$(kubectl get service svc-scenario2 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')

kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 http://$SVC2_IP:80 2>/dev/null | head -5
```

**Verificación:**

```bash
# Confirmar targetPort actualizado
kubectl get service svc-scenario2 -n lab-svc-debug \
  -o jsonpath='{.spec.ports[0].targetPort}' && echo
# Salida esperada: 80
```

---

### Paso 4: Diagnóstico del Escenario 3 — Pods no-Ready por readinessProbe fallida

**Objetivo:** Identificar que `svc-scenario3` (NodePort) no tiene endpoints porque los Pods del Deployment `backend-app` están en estado no-Ready, causado por una `readinessProbe` que apunta a una ruta inexistente (`/healthz`).

**Instrucciones:**

1. Verifica el estado de los Pods del Deployment:

```bash
kubectl get pods -n lab-svc-debug -l app=backend-app
```

> **Observación:** Los Pods aparecen con `0/1 Ready` aunque el contenedor esté corriendo.

2. Inspecciona los endpoints del Service:

```bash
kubectl get endpoints svc-scenario3 -n lab-svc-debug
kubectl describe endpoints svc-scenario3 -n lab-svc-debug
```

3. Describe uno de los Pods no-Ready para ver los eventos y el estado de la probe:

```bash
# Obtener el nombre de un pod
POD_NAME=$(kubectl get pods -n lab-svc-debug -l app=backend-app \
  -o jsonpath='{.items[0].metadata.name}')

kubectl describe pod $POD_NAME -n lab-svc-debug
```

Localiza la sección `Conditions:` (busca `Ready: False`) y la sección `Events:` (busca mensajes de `Readiness probe failed`).

4. Examina específicamente la configuración de la `readinessProbe`:

```bash
kubectl get pod $POD_NAME -n lab-svc-debug \
  -o jsonpath='{.spec.containers[0].readinessProbe}' && echo
```

**Salida esperada:**

```json
{"failureThreshold":2,"httpGet":{"path":"/healthz","port":80,"scheme":"HTTP"},"initialDelaySeconds":2,"periodSeconds":5,"successThreshold":1,"timeoutSeconds":1}
```

5. Verifica manualmente que la ruta `/healthz` no existe en nginx:

```bash
kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 \
  http://$(kubectl get pod $POD_NAME -n lab-svc-debug \
    -o jsonpath='{.status.podIP}'):80/healthz || echo "Ruta /healthz no existe"
```

**Salida esperada:**

```
wget: server returned error: HTTP/1.1 404 Not Found
Ruta /healthz no existe
```

**Diagnóstico confirmado:** La `readinessProbe` verifica `GET /healthz:80`, pero nginx por defecto no tiene esa ruta y devuelve `404`. Kubernetes interpreta el `404` como fallo de la probe, marca el Pod como no-Ready y lo excluye de los Endpoints del Service.

6. **Aplica la corrección** — Parchea el Deployment para usar la ruta `/` que sí existe en nginx:

```bash
kubectl patch deployment backend-app -n lab-svc-debug \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

7. Espera a que los Pods se reinicien y pasen a estado Ready:

```bash
kubectl rollout status deployment/backend-app -n lab-svc-debug --timeout=60s
```

8. Verifica que los Pods ahora están Ready:

```bash
kubectl get pods -n lab-svc-debug -l app=backend-app
```

**Salida esperada (corregido):**

```
NAME                           READY   STATUS    RESTARTS   AGE
backend-app-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
backend-app-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
```

9. Confirma que los endpoints del Service NodePort ahora están poblados:

```bash
kubectl get endpoints svc-scenario3 -n lab-svc-debug
```

**Salida esperada (corregido):**

```
NAME           ENDPOINTS                         AGE
svc-scenario3  10.244.x.x:80,10.244.x.x:80      Xm
```

10. Valida la conectividad mediante ClusterIP desde el pod de diagnóstico:

```bash
SVC3_IP=$(kubectl get service svc-scenario3 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')

kubectl exec -it diag-pod -n lab-svc-debug -- \
  wget -O- --timeout=5 http://$SVC3_IP:80 2>/dev/null | head -5
```

**Verificación:**

```bash
# Confirmar readinessProbe actualizada
kubectl get deployment backend-app -n lab-svc-debug \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' && echo
# Salida esperada: /
```

---

### Paso 5: Validación del NodePort (Escenario 3)

**Objetivo:** Confirmar que el Service de tipo NodePort es accesible desde fuera del clúster usando la IP del nodo y el puerto `30083`.

**Instrucciones:**

1. Obtén la IP del nodo de Minikube:

```bash
MINIKUBE_IP=$(minikube ip)
echo "IP del nodo Minikube: $MINIKUBE_IP"
```

2. Verifica el NodePort asignado al Service:

```bash
kubectl get service svc-scenario3 -n lab-svc-debug \
  -o jsonpath='{.spec.ports[0].nodePort}' && echo
```

3. Accede al Service a través del NodePort:

```bash
# En Linux con driver Docker nativo
curl -s --max-time 5 http://$MINIKUBE_IP:30083 | head -5

# En macOS/Windows con WSL2 (usar minikube service)
# minikube service svc-scenario3 -n lab-svc-debug --url
```

> **Nota para macOS/Windows:** Si el comando `curl` directo no funciona, ejecuta `minikube service svc-scenario3 -n lab-svc-debug --url` para obtener la URL tuneada y úsala con `curl`.

**Salida esperada:**

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

**Verificación:**

```bash
# Resumen final: verificar todos los endpoints están poblados
kubectl get endpoints -n lab-svc-debug
```

---

## 7. Validación Final y Pruebas

Ejecuta este bloque de validación completo para confirmar que los tres escenarios fueron corregidos exitosamente:

```bash
echo "=== VALIDACIÓN FINAL DE LOS 3 ESCENARIOS ==="
echo ""

# --- Escenario 1 ---
echo "--- Escenario 1: Selector corregido ---"
EP1=$(kubectl get endpoints svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)
if [ -n "$EP1" ] && [ "$EP1" != "null" ]; then
  echo "[OK] svc-scenario1 tiene endpoints activos"
else
  echo "[FALLO] svc-scenario1 aún sin endpoints"
fi

SVC1_IP=$(kubectl get service svc-scenario1 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')
HTTP1=$(kubectl exec diag-pod -n lab-svc-debug -- \
  wget -q -O- --timeout=5 http://$SVC1_IP:80 2>/dev/null | grep -c "nginx" || true)
if [ "$HTTP1" -gt "0" ]; then
  echo "[OK] svc-scenario1 responde HTTP correctamente"
else
  echo "[FALLO] svc-scenario1 no responde HTTP"
fi

echo ""

# --- Escenario 2 ---
echo "--- Escenario 2: targetPort corregido ---"
TARGET_PORT=$(kubectl get service svc-scenario2 -n lab-svc-debug \
  -o jsonpath='{.spec.ports[0].targetPort}')
if [ "$TARGET_PORT" = "80" ]; then
  echo "[OK] svc-scenario2 targetPort=80 (correcto)"
else
  echo "[FALLO] svc-scenario2 targetPort=$TARGET_PORT (incorrecto)"
fi

SVC2_IP=$(kubectl get service svc-scenario2 -n lab-svc-debug \
  -o jsonpath='{.spec.clusterIP}')
HTTP2=$(kubectl exec diag-pod -n lab-svc-debug -- \
  wget -q -O- --timeout=5 http://$SVC2_IP:80 2>/dev/null | grep -c "nginx" || true)
if [ "$HTTP2" -gt "0" ]; then
  echo "[OK] svc-scenario2 responde HTTP correctamente"
else
  echo "[FALLO] svc-scenario2 no responde HTTP"
fi

echo ""

# --- Escenario 3 ---
echo "--- Escenario 3: readinessProbe corregida ---"
READY_PODS=$(kubectl get pods -n lab-svc-debug -l app=backend-app \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | grep -c "true" || true)
if [ "$READY_PODS" -ge "1" ]; then
  echo "[OK] backend-app tiene $READY_PODS pod(s) en estado Ready"
else
  echo "[FALLO] backend-app no tiene pods Ready"
fi

EP3=$(kubectl get endpoints svc-scenario3 -n lab-svc-debug \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)
if [ -n "$EP3" ] && [ "$EP3" != "null" ]; then
  echo "[OK] svc-scenario3 tiene endpoints activos"
else
  echo "[FALLO] svc-scenario3 aún sin endpoints"
fi

echo ""
echo "=== FIN DE VALIDACIÓN ==="
```

**Salida esperada completa:**

```
=== VALIDACIÓN FINAL DE LOS 3 ESCENARIOS ===

--- Escenario 1: Selector corregido ---
[OK] svc-scenario1 tiene endpoints activos
[OK] svc-scenario1 responde HTTP correctamente

--- Escenario 2: targetPort corregido ---
[OK] svc-scenario2 targetPort=80 (correcto)
[OK] svc-scenario2 responde HTTP correctamente

--- Escenario 3: readinessProbe corregida ---
[OK] backend-app tiene 2 pod(s) en estado Ready
[OK] svc-scenario3 tiene endpoints activos

=== FIN DE VALIDACIÓN ===
```

---

## 8. Resolución de Problemas

### Problema 1: El pod `diag-pod` está en estado `Error` o `CrashLoopBackOff`

**Síntomas:**
```
NAME        READY   STATUS             RESTARTS   AGE
diag-pod    0/1     CrashLoopBackOff   3          5m
```

**Causa:** El pod `busybox` con el comando `sleep 3600` puede fallar si la imagen no se descargó correctamente o si existe un pod anterior con el mismo nombre en estado fallido.

**Solución:**
```bash
# Eliminar el pod existente
kubectl delete pod diag-pod -n lab-svc-debug --force --grace-period=0

# Verificar que la imagen está disponible
docker pull busybox:latest

# Recrear el pod de diagnóstico
kubectl run diag-pod \
  --image=busybox:latest \
  --restart=Never \
  --namespace=lab-svc-debug \
  -- sleep 3600

# Esperar a que esté Running
kubectl wait pod/diag-pod -n lab-svc-debug \
  --for=condition=Ready --timeout=30s
```

---

### Problema 2: Después de parchear el Deployment `backend-app`, los Pods siguen apareciendo como no-Ready

**Síntomas:**
```bash
kubectl get pods -n lab-svc-debug -l app=backend-app
# NAME                          READY   STATUS    RESTARTS
# backend-app-xxxxxxx-xxxxx     0/1     Running   0
```
Los Pods están `Running` pero `0/1 Ready` incluso después de aplicar el patch.

**Causa:** El `rollout` puede no haberse completado aún, o el patch no se aplicó correctamente al path correcto del JSON. También puede deberse a que el `initialDelaySeconds` aún no ha transcurrido.

**Solución:**
```bash
# Verificar que el patch se aplicó correctamente
kubectl get deployment backend-app -n lab-svc-debug \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' && echo

# Si el path sigue siendo /healthz, aplicar corrección mediante edición directa
kubectl edit deployment backend-app -n lab-svc-debug
# Buscar readinessProbe.httpGet.path y cambiar /healthz por /

# Esperar el rollout completo
kubectl rollout status deployment/backend-app \
  -n lab-svc-debug --timeout=90s

# Si persiste, forzar el rollout reiniciando el deployment
kubectl rollout restart deployment/backend-app -n lab-svc-debug
kubectl rollout status deployment/backend-app \
  -n lab-svc-debug --timeout=90s
```

---

## 9. Limpieza

Una vez completado y validado el laboratorio, elimina todos los recursos creados:

```bash
# Eliminar el namespace completo (elimina todos los recursos dentro)
kubectl delete namespace lab-svc-debug

# Verificar que el namespace fue eliminado
kubectl get namespace lab-svc-debug 2>/dev/null || echo "Namespace eliminado correctamente"
```

> **Nota de persistencia entre módulos:** Si planeas continuar con el Lab 06-00-03 u otros laboratorios del módulo 6, asegúrate de que el clúster Minikube sigue activo. Usa `minikube status` para confirmarlo. No ejecutes `minikube delete` entre módulos.

---

## 10. Resumen

En este laboratorio aplicaste una metodología sistemática de diagnóstico de Services en Kubernetes, trabajando con tres fallos reales y frecuentes en entornos de producción:

| Escenario | Fallo | Herramienta de diagnóstico | Corrección aplicada |
|-----------|-------|---------------------------|---------------------|
| 1 — ClusterIP | Selector `app: webserver` no coincide con etiqueta `app: web-server` | `kubectl describe service`, `kubectl get pods --show-labels` | `kubectl patch service` para corregir el selector |
| 2 — ClusterIP | `targetPort: 8080` no coincide con `containerPort: 80` | `kubectl describe service`, `kubectl describe pod` | `kubectl patch service` para corregir el targetPort |
| 3 — NodePort | `readinessProbe` apunta a `/healthz` inexistente → Pods no-Ready → endpoints vacíos | `kubectl describe pod`, inspección de Events | `kubectl patch deployment` para corregir la ruta de la probe |

### Conceptos clave reforzados

- **Endpoints vacíos** son siempre síntoma de un selector incorrecto o de Pods no-Ready; nunca de un problema en el contenedor en sí.
- **La existencia de endpoints no garantiza conectividad**: el `targetPort` debe coincidir exactamente con el puerto en que el proceso dentro del contenedor escucha.
- **La `readinessProbe`** es el mecanismo por el que Kubernetes decide si un Pod debe recibir tráfico; un fallo en la probe excluye al Pod de los endpoints aunque el contenedor esté corriendo.
- El flujo de diagnóstico recomendado es siempre: `kubectl get endpoints` → `kubectl describe service` → `kubectl get pods --show-labels` → `kubectl describe pod` → prueba de conectividad con `curl`/`wget`.

### Recursos adicionales

- [Documentación oficial — Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Documentación oficial — Endpoints](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- [Documentación oficial — Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Guía de debugging de Services en Kubernetes](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

---
LAB_END---

---

---LAB_START---
LAB_ID: 06-00-03
---MARKDOWN---
# Práctica complementaria 6.2: Validación de DNS interno

## Metadatos

| Campo        | Valor                                      |
|--------------|--------------------------------------------|
| Duración     | 17 minutos                                 |
| Complejidad  | Media                                      |
| Nivel Bloom  | Aplicar (Apply)                            |
| Módulo       | 6 — Redes en Kubernetes                    |
| Lab previo   | 06-00-02 (Services en Kubernetes)          |

---

## Descripción General

En este laboratorio validarás el funcionamiento del DNS interno de Kubernetes, implementado por **CoreDNS**, que permite a los Pods resolver nombres de Service sin depender de IPs efímeras. Desplegarás servicios en distintos namespaces, ejecutarás pruebas de resolución DNS desde pods de diagnóstico y analizarás escenarios de fallo comunes, incluyendo un pod con `dnsPolicy: None` mal configurado y una réplica de CoreDNS en estado `CrashLoopBackOff`. Este laboratorio refuerza directamente los conceptos de la sección 6.3 del módulo y se apoya en el modelo de red plana estudiado en la lección 6.1.

---

## Objetivos de Aprendizaje

- [ ] Verificar el funcionamiento del DNS interno de Kubernetes (CoreDNS) resolviendo nombres de Service dentro del clúster usando `dig` y `nslookup`.
- [ ] Aplicar el formato FQDN de Kubernetes (`<service>.<namespace>.svc.cluster.local`) para realizar resolución DNS cross-namespace.
- [ ] Diagnosticar fallos de resolución DNS causados por una `dnsPolicy: None` sin `dnsConfig` adecuada.
- [ ] Inspeccionar el ConfigMap `coredns` en `kube-system` para comprender la configuración del Corefile.
- [ ] Identificar el impacto de una réplica de CoreDNS en `CrashLoopBackOff` sobre la disponibilidad del DNS del clúster.

---

## Prerrequisitos

### Conocimiento previo
- Haber completado el Lab 06-00-02 o tener conocimiento equivalente de Services en Kubernetes.
- Fundamentos de DNS: registros A, resolución de nombres, servidores DNS recursivos.
- Comprensión del concepto de Namespaces en Kubernetes.
- Familiaridad básica con los comandos `dig` o `nslookup`.
- Comprensión del modelo de red plana de Kubernetes (lección 6.1): IPs de Pod, Pod CIDR y Service CIDR.

### Acceso requerido
- Clúster Minikube en ejecución con mínimo 1 nodo (preferiblemente 3 nodos iniciados desde el inicio del curso).
- `kubectl` configurado y con acceso al clúster.
- Acceso a Internet para descargar las imágenes `busybox:latest` y `nginx:1.25` si no están en caché.

---

## Entorno del Laboratorio

### Hardware mínimo recomendado

| Recurso    | Mínimo      | Recomendado  |
|------------|-------------|--------------|
| CPU        | 4 núcleos   | 8 núcleos    |
| RAM        | 8 GB        | 16 GB        |
| Disco      | 40 GB libre | 60 GB libre  |

### Software requerido

| Herramienta | Versión mínima | Propósito                        |
|-------------|----------------|----------------------------------|
| kubectl     | 1.28.x         | Gestión del clúster              |
| Minikube    | 1.31.x         | Clúster local                    |
| Docker      | 24.x           | Driver de Minikube               |
| curl        | 7.x            | Pruebas HTTP opcionales          |

### Preparación del entorno

Verifica que el clúster esté en ejecución y que CoreDNS esté operativo antes de comenzar:

```bash
# Verificar estado del clúster
kubectl cluster-info

# Verificar que CoreDNS está corriendo en kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Salida esperada (ambas réplicas en Running):
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-5d78c9869d-abc12   1/1     Running   0          2d
# coredns-5d78c9869d-def34   1/1     Running   0          2d
```

Si el clúster no está iniciado:

```bash
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048
```

Pre-descarga de imágenes (opcional, para entornos con conectividad limitada):

```bash
docker pull busybox:latest
docker pull nginx:1.25
# Cargar imágenes en Minikube si se usa driver Docker
minikube image load busybox:latest
minikube image load nginx:1.25
```

---

## Pasos del Laboratorio

---

### Paso 1: Crear los namespaces y servicios de prueba

**Objetivo:** Establecer el entorno base con dos namespaces (`dns-lab` y `dns-lab-b`) y un Service en cada uno, para poder probar resolución DNS dentro del mismo namespace y cross-namespace.

#### Instrucciones

1. Crea los dos namespaces de trabajo:

```bash
kubectl create namespace dns-lab
kubectl create namespace dns-lab-b
```

2. Despliega un Deployment y un Service `nginx` en el namespace `dns-lab`:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: dns-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: dns-lab
spec:
  selector:
    app: web-server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

3. Despliega un segundo Service en el namespace `dns-lab-b`:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: dns-lab-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: dns-lab-b
spec:
  selector:
    app: api-server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

4. Verifica que ambos Pods y Services estén listos:

```bash
kubectl get pods,svc -n dns-lab
kubectl get pods,svc -n dns-lab-b
```

#### Salida esperada

```
# Namespace dns-lab
NAME                              READY   STATUS    RESTARTS   AGE
pod/web-server-7d9f8b6c4-xk9pq   1/1     Running   0          30s

NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/web-svc   ClusterIP   10.96.45.123    <none>        80/TCP    30s

# Namespace dns-lab-b
NAME                               READY   STATUS    RESTARTS   AGE
pod/api-server-6c8d7b5f3-mn2rt    1/1     Running   0          25s

NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/api-svc   ClusterIP   10.96.78.200    <none>        80/TCP    25s
```

#### Verificación

```bash
# Confirmar que los Services tienen ClusterIP asignada
kubectl get svc web-svc -n dns-lab -o jsonpath='{.spec.clusterIP}'
kubectl get svc api-svc -n dns-lab-b -o jsonpath='{.spec.clusterIP}'
# Ambos deben retornar una IP del rango 10.96.0.0/12 (Service CIDR)
```

---

### Paso 2: Resolución DNS por nombre corto dentro del mismo namespace

**Objetivo:** Verificar que CoreDNS resuelve correctamente el nombre corto de un Service (`web-svc`) desde un pod de diagnóstico en el **mismo namespace** (`dns-lab`).

#### Instrucciones

1. Lanza un pod de diagnóstico `busybox` efímero en el namespace `dns-lab`:

```bash
kubectl run dns-debug \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm -it \
  -- sh
```

> **Nota:** El flag `--rm` elimina el pod automáticamente al salir del shell. Si la imagen no está disponible inmediatamente, espera 30 segundos y reintenta.

2. Dentro del pod, ejecuta una resolución DNS por **nombre corto**:

```sh
# Dentro del pod busybox
nslookup web-svc
```

3. Verifica también con `dig` (disponible en busybox):

```sh
# Dentro del pod busybox
nslookup web-svc.dns-lab.svc.cluster.local
```

4. Prueba conectividad HTTP hacia el Service:

```sh
# Dentro del pod busybox
wget -qO- http://web-svc
```

5. Sal del pod:

```sh
exit
```

#### Salida esperada

```
# nslookup web-svc
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-svc
Address 1: 10.96.45.123 web-svc.dns-lab.svc.cluster.local

# wget -qO- http://web-svc
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

> **Observación clave:** Cuando el pod está en `dns-lab`, el nombre corto `web-svc` se resuelve correctamente porque CoreDNS añade automáticamente el sufijo `.dns-lab.svc.cluster.local` basándose en el namespace del pod solicitante. Esto es el comportamiento de `dnsPolicy: ClusterFirst` (valor por defecto).

#### Verificación

```bash
# Confirmar que el pod dns-debug fue eliminado automáticamente
kubectl get pod dns-debug -n dns-lab 2>&1
# Debe retornar: Error from server (NotFound): pods "dns-debug" not found
```

---

### Paso 3: Resolución DNS cross-namespace con FQDN completo

**Objetivo:** Verificar que un pod en `dns-lab` puede resolver el Service `api-svc` ubicado en el namespace `dns-lab-b` usando el **FQDN completo**.

#### Instrucciones

1. Lanza un nuevo pod de diagnóstico en `dns-lab`:

```bash
kubectl run dns-cross \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm -it \
  -- sh
```

2. Dentro del pod, intenta primero con el nombre corto (esto **fallará**):

```sh
# Dentro del pod busybox — esto fallará intencionalmente
nslookup api-svc
```

3. Ahora usa el FQDN completo cross-namespace:

```sh
# Dentro del pod busybox — formato: <service>.<namespace>.svc.cluster.local
nslookup api-svc.dns-lab-b.svc.cluster.local
```

4. Verifica conectividad HTTP cross-namespace:

```sh
wget -qO- http://api-svc.dns-lab-b.svc.cluster.local
```

5. Inspecciona el archivo `/etc/resolv.conf` del pod para entender los search domains:

```sh
cat /etc/resolv.conf
```

6. Sal del pod:

```sh
exit
```

#### Salida esperada

```
# nslookup api-svc (falla esperada)
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

nslookup: can't resolve 'api-svc'

# nslookup api-svc.dns-lab-b.svc.cluster.local (éxito)
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      api-svc.dns-lab-b.svc.cluster.local
Address 1: 10.96.78.200 api-svc.dns-lab-b.svc.cluster.local

# cat /etc/resolv.conf
nameserver 10.96.0.10
search dns-lab.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

> **Observación clave:** El archivo `/etc/resolv.conf` muestra que el `search domain` está limitado al namespace actual (`dns-lab`). Por eso el nombre corto `api-svc` no se resuelve cross-namespace: no existe un search domain para `dns-lab-b`. El FQDN completo siempre funciona independientemente del namespace origen.

#### Verificación

```bash
# El FQDN debe resolver a la misma ClusterIP que obtuviste en el Paso 1
kubectl get svc api-svc -n dns-lab-b -o jsonpath='{.spec.clusterIP}'
# Compara esta IP con la retornada por nslookup — deben coincidir exactamente
```

---

### Paso 4: Diagnóstico de pod con `dnsPolicy: None` mal configurado

**Objetivo:** Reproducir y diagnosticar el fallo de resolución DNS causado por un pod con `dnsPolicy: None` que carece de una `dnsConfig` adecuada.

#### Instrucciones

1. Crea un pod con `dnsPolicy: None` **sin** `dnsConfig` (configuración incorrecta):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: broken-dns-pod
  namespace: dns-lab
spec:
  dnsPolicy: None
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
EOF
```

2. Espera a que el pod esté en estado `Running`:

```bash
kubectl wait pod broken-dns-pod -n dns-lab --for=condition=Ready --timeout=60s
```

3. Ejecuta una resolución DNS desde el pod con configuración rota:

```bash
kubectl exec -n dns-lab broken-dns-pod -- nslookup web-svc
```

4. Inspecciona el `/etc/resolv.conf` del pod afectado:

```bash
kubectl exec -n dns-lab broken-dns-pod -- cat /etc/resolv.conf
```

5. Ahora **corrige** el pod eliminándolo y recreándolo con una `dnsConfig` apropiada:

```bash
kubectl delete pod broken-dns-pod -n dns-lab

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fixed-dns-pod
  namespace: dns-lab
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 10.96.0.10
    searches:
    - dns-lab.svc.cluster.local
    - svc.cluster.local
    - cluster.local
    options:
    - name: ndots
      value: "5"
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
EOF
```

6. Espera a que el pod esté listo y verifica la resolución DNS:

```bash
kubectl wait pod fixed-dns-pod -n dns-lab --for=condition=Ready --timeout=60s

kubectl exec -n dns-lab fixed-dns-pod -- nslookup web-svc
kubectl exec -n dns-lab fixed-dns-pod -- cat /etc/resolv.conf
```

#### Salida esperada

```
# Paso 3 — nslookup en pod roto (falla esperada)
nslookup: write to '': Network unreachable
# O bien:
;; connection timed out; no servers could be reached

# Paso 4 — /etc/resolv.conf del pod roto (vacío o sin nameserver)
# (archivo vacío o solo comentarios)

# Paso 6 — /etc/resolv.conf del pod corregido
nameserver 10.96.0.10
search dns-lab.svc.cluster.local svc.cluster.local cluster.local
options ndots:5

# Paso 6 — nslookup en pod corregido (éxito)
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-svc
Address 1: 10.96.45.123 web-svc.dns-lab.svc.cluster.local
```

> **Concepto clave:** `dnsPolicy: None` desactiva completamente la inyección automática de configuración DNS de Kubernetes. Sin una `dnsConfig` explícita con al menos un `nameserver`, el pod no puede resolver ningún nombre. Esta política se usa cuando se necesita control total sobre el DNS del pod, pero requiere configuración manual completa.

#### Verificación

```bash
# Confirmar que el pod corregido resuelve nombres externos también
kubectl exec -n dns-lab fixed-dns-pod -- nslookup google.com
# Debe resolver correctamente si CoreDNS tiene forwarding configurado
```

---

### Paso 5: Inspección del ConfigMap de CoreDNS

**Objetivo:** Examinar la configuración del Corefile en el ConfigMap `coredns` del namespace `kube-system` para entender cómo CoreDNS gestiona las zonas, el forwarding y el health check.

#### Instrucciones

1. Visualiza el ConfigMap completo de CoreDNS:

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

2. Extrae únicamente el contenido del Corefile para mejor legibilidad:

```bash
kubectl get configmap coredns -n kube-system \
  -o jsonpath='{.data.Corefile}'
```

3. Identifica y anota los bloques principales del Corefile:

```bash
# Visualización formateada
kubectl get configmap coredns -n kube-system \
  -o jsonpath='{.data.Corefile}' | cat
```

4. Verifica el Service `kube-dns` que expone CoreDNS al clúster:

```bash
kubectl get svc kube-dns -n kube-system
kubectl get endpoints kube-dns -n kube-system
```

5. Confirma que la IP del Service `kube-dns` coincide con el `nameserver` en los pods:

```bash
kubectl get svc kube-dns -n kube-system \
  -o jsonpath='{.spec.clusterIP}'
# Debe ser 10.96.0.10 (valor por defecto en Minikube/kubeadm)
```

#### Salida esperada

```yaml
# kubectl get configmap coredns -n kube-system -o yaml (extracto)
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
```

```
# kubectl get svc kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   2d

# kubectl get endpoints kube-dns -n kube-system
NAME       ENDPOINTS                                                  AGE
kube-dns   10.244.0.5:53,10.244.0.6:53,10.244.0.5:53,10.244.0.6:53  2d
```

> **Elementos clave del Corefile:**
> - **`kubernetes cluster.local`**: Plugin que resuelve nombres dentro del clúster (Services y Pods).
> - **`forward . /etc/resolv.conf`**: Reenvía consultas externas (p.ej. `google.com`) al DNS del nodo host.
> - **`cache 30`**: Cachea respuestas durante 30 segundos para reducir latencia.
> - **`health`**: Expone endpoint `/health` en puerto 8080 para liveness probes.
> - **`prometheus :9153`**: Métricas de CoreDNS disponibles para Prometheus.

#### Verificación

```bash
# Confirmar que los Pods de CoreDNS tienen los endpoints registrados
kubectl describe endpoints kube-dns -n kube-system
# Los endpoints deben coincidir con las IPs de los Pods de CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

---

### Paso 6: Prueba de resolución de nombres externos (forwarding DNS)

**Objetivo:** Verificar que CoreDNS reenvía correctamente las consultas de nombres externos (fuera del clúster) al DNS del nodo host, validando la configuración de `forward` en el Corefile.

#### Instrucciones

1. Lanza un pod de diagnóstico interactivo en `dns-lab`:

```bash
kubectl run dns-external \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm -it \
  -- sh
```

2. Dentro del pod, resuelve un nombre externo:

```sh
# Dentro del pod busybox
nslookup google.com
```

3. Resuelve un nombre interno para comparar:

```sh
nslookup web-svc.dns-lab.svc.cluster.local
```

4. Verifica que el mismo servidor DNS (`10.96.0.10`) gestiona ambos tipos de consultas:

```sh
nslookup google.com 10.96.0.10
nslookup kubernetes.default.svc.cluster.local 10.96.0.10
```

5. Sal del pod:

```sh
exit
```

#### Salida esperada

```
# nslookup google.com
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      google.com
Address 1: 142.250.x.x <IP pública de Google>
Address 2: 2607:f8b0:xxxx::xxxx <IPv6 de Google>

# nslookup web-svc.dns-lab.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-svc.dns-lab.svc.cluster.local
Address 1: 10.96.45.123 web-svc.dns-lab.svc.cluster.local
```

> **Observación:** El mismo servidor DNS (`10.96.0.10`, que es el Service `kube-dns`) resuelve tanto nombres internos del clúster como nombres externos. Para los externos, CoreDNS actúa como proxy y reenvía la consulta al DNS configurado en `/etc/resolv.conf` del nodo (generalmente el DNS del sistema operativo host o el de la red del proveedor).

#### Verificación

```bash
# Verificar que el pod fue eliminado
kubectl get pod dns-external -n dns-lab 2>&1
# Debe retornar: Error from server (NotFound)
```

---

### Paso 7: Simulación de CoreDNS en CrashLoopBackOff e identificación del impacto

**Objetivo:** Simular el impacto de una réplica de CoreDNS en estado `CrashLoopBackOff` sobre la resolución DNS del clúster, sin modificar el despliegue real de CoreDNS.

> **⚠️ Nota importante:** En este paso **no modificaremos** el Deployment real de CoreDNS para evitar dañar el clúster. En su lugar, observaremos los síntomas mediante la eliminación temporal de un Pod de CoreDNS (que será recreado automáticamente por el Deployment) y aprenderemos a identificar el estado problemático.

#### Instrucciones

1. Identifica los pods actuales de CoreDNS:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

2. Anota el nombre del primer pod de CoreDNS y observa su estado de salud:

```bash
COREDNS_POD=$(kubectl get pods -n kube-system -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}')
echo "Pod de CoreDNS seleccionado: $COREDNS_POD"

kubectl describe pod $COREDNS_POD -n kube-system | grep -A5 "Liveness\|Readiness\|Restart"
```

3. Elimina un pod de CoreDNS para observar cómo el Deployment lo recrea (simula recuperación de un crash):

```bash
kubectl delete pod $COREDNS_POD -n kube-system
```

4. Observa la recreación del pod en tiempo real:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns -w
# Presiona Ctrl+C después de ver el nuevo pod en Running
```

5. Mientras el pod se está reiniciando, verifica si el DNS sigue funcionando (gracias a la segunda réplica):

```bash
kubectl run dns-resilience-test \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm -it \
  -- nslookup web-svc.dns-lab.svc.cluster.local
```

6. Aprende a identificar un pod en `CrashLoopBackOff` y sus síntomas:

```bash
# Comando para buscar pods problemáticos en kube-system
kubectl get pods -n kube-system | grep -E "CrashLoop|Error|0/1"

# Cómo revisar logs de un pod en CrashLoopBackOff
# (reemplaza <pod-name> con el nombre real si se presenta el escenario)
# kubectl logs <pod-name> -n kube-system --previous
# kubectl describe pod <pod-name> -n kube-system
```

7. Verifica que CoreDNS se haya recuperado completamente:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Ambas réplicas deben estar en Running
```

#### Salida esperada

```
# Paso 1 — Pods de CoreDNS
NAME                       READY   STATUS    RESTARTS   AGE   IP
coredns-5d78c9869d-abc12   1/1     Running   0          2d    10.244.0.5
coredns-5d78c9869d-def34   1/1     Running   0          2d    10.244.0.6

# Paso 4 — Recreación del pod (observación con -w)
NAME                       READY   STATUS              RESTARTS   AGE
coredns-5d78c9869d-def34   1/1     Running             0          2d
coredns-5d78c9869d-abc12   0/1     Terminating         0          2d
coredns-5d78c9869d-gh789   0/1     ContainerCreating   0          2s
coredns-5d78c9869d-gh789   1/1     Running             0          8s

# Paso 5 — DNS sigue funcionando con una sola réplica
Name:      web-svc.dns-lab.svc.cluster.local
Address 1: 10.96.45.123
```

> **Lección sobre CrashLoopBackOff en CoreDNS:** Si **ambas** réplicas de CoreDNS entraran en `CrashLoopBackOff`, todos los pods del clúster perderían la capacidad de resolver nombres DNS. Los síntomas serían: `nslookup` retornando `connection timed out`, `wget` fallando con `bad address`, y cualquier aplicación que dependa de descubrimiento de servicios por nombre dejaría de funcionar. Los comandos clave para diagnosticar son:
> ```bash
> kubectl get pods -n kube-system -l k8s-app=kube-dns
> kubectl logs <coredns-pod> -n kube-system --previous
> kubectl describe pod <coredns-pod> -n kube-system
> ```

#### Verificación

```bash
# Confirmar recuperación completa de CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Ambos pods deben mostrar READY 1/1 y STATUS Running

# Test final de resolución DNS
kubectl run final-dns-check \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm \
  -- nslookup kubernetes.default.svc.cluster.local
```

---

## Validación y Pruebas

Ejecuta esta secuencia de validación completa para confirmar que todos los objetivos del laboratorio se han cumplido:

```bash
# ====================================================
# VALIDACIÓN COMPLETA — Lab 06-00-03
# ====================================================

echo "=== 1. Verificar Services en ambos namespaces ==="
kubectl get svc web-svc -n dns-lab
kubectl get svc api-svc -n dns-lab-b

echo ""
echo "=== 2. Resolución DNS nombre corto (mismo namespace) ==="
kubectl run val-test-1 \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm \
  -- nslookup web-svc

echo ""
echo "=== 3. Resolución DNS FQDN cross-namespace ==="
kubectl run val-test-2 \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm \
  -- nslookup api-svc.dns-lab-b.svc.cluster.local

echo ""
echo "=== 4. Resolución DNS nombre externo (forwarding) ==="
kubectl run val-test-3 \
  --image=busybox:latest \
  --restart=Never \
  --namespace=dns-lab \
  --rm \
  -- nslookup google.com

echo ""
echo "=== 5. Verificar pod con dnsConfig correcta ==="
kubectl exec -n dns-lab fixed-dns-pod -- nslookup web-svc

echo ""
echo "=== 6. Estado de CoreDNS ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns

echo ""
echo "=== 7. ConfigMap de CoreDNS presente ==="
kubectl get configmap coredns -n kube-system

echo ""
echo "=== Validación completada ==="
```

**Criterios de éxito:**

| Prueba | Resultado esperado |
|--------|--------------------|
| `nslookup web-svc` desde `dns-lab` | Resuelve a ClusterIP de `web-svc` |
| `nslookup api-svc.dns-lab-b.svc.cluster.local` | Resuelve a ClusterIP de `api-svc` |
| `nslookup api-svc` (sin FQDN, cross-namespace) | **Falla** — comportamiento esperado |
| `nslookup google.com` desde pod | Resuelve a IP pública |
| `fixed-dns-pod` con `dnsPolicy: None` + `dnsConfig` | Resuelve `web-svc` correctamente |
| CoreDNS pods en `kube-system` | Ambas réplicas en `Running` |

---

## Resolución de Problemas

### Problema 1: `nslookup` retorna `connection timed out` o `no servers could be reached`

**Síntomas:**
```
nslookup: write to '10.96.0.10': Connection refused
;; connection timed out; no servers could be reached
```
El pod de diagnóstico no puede contactar al servidor DNS en `10.96.0.10`.

**Causa probable:**
CoreDNS no está en ejecución o sus Pods están en estado `CrashLoopBackOff` / `Pending`. También puede ocurrir si el Service `kube-dns` no tiene endpoints activos porque los Pods de CoreDNS no pasan los health checks.

**Solución:**

```bash
# Paso 1: Verificar estado de los Pods de CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Paso 2: Si algún Pod está en CrashLoopBackOff, revisar logs
kubectl logs -n kube-system -l k8s-app=kube-dns --previous

# Paso 3: Verificar que el Service kube-dns tiene endpoints
kubectl get endpoints kube-dns -n kube-system

# Paso 4: Si los endpoints están vacíos, verificar que los Pods tienen la label correcta
kubectl get pods -n kube-system -l k8s-app=kube-dns --show-labels

# Paso 5: Reiniciar los Pods de CoreDNS (el Deployment los recreará)
kubectl rollout restart deployment coredns -n kube-system

# Paso 6: Esperar a que estén listos
kubectl rollout status deployment coredns -n kube-system

# Paso 7: Verificar ConfigMap no corrompido
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
```

---

### Problema 2: El pod `fixed-dns-pod` no resuelve nombres a pesar de tener `dnsConfig`

**Síntomas:**
```
kubectl exec -n dns-lab fixed-dns-pod -- nslookup web-svc
nslookup: can't resolve 'web-svc'
```
El pod tiene `dnsPolicy: None` con `dnsConfig`, pero la resolución DNS sigue fallando.

**Causa probable:**
La IP del `nameserver` en `dnsConfig` es incorrecta (no coincide con la ClusterIP del Service `kube-dns`), o los `searches` no incluyen el sufijo correcto del namespace. En algunos entornos, la ClusterIP de `kube-dns` puede no ser `10.96.0.10`.

**Solución:**

```bash
# Paso 1: Obtener la ClusterIP REAL del Service kube-dns
KDNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP de kube-dns: $KDNS_IP"

# Paso 2: Verificar el /etc/resolv.conf actual del pod
kubectl exec -n dns-lab fixed-dns-pod -- cat /etc/resolv.conf

# Paso 3: Si el nameserver no coincide, eliminar y recrear el pod con la IP correcta
kubectl delete pod fixed-dns-pod -n dns-lab

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fixed-dns-pod
  namespace: dns-lab
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - ${KDNS_IP}
    searches:
    - dns-lab.svc.cluster.local
    - svc.cluster.local
    - cluster.local
    options:
    - name: ndots
      value: "5"
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
EOF

# Paso 4: Esperar a que el pod esté listo y verificar
kubectl wait pod fixed-dns-pod -n dns-lab --for=condition=Ready --timeout=60s
kubectl exec -n dns-lab fixed-dns-pod -- cat /etc/resolv.conf
kubectl exec -n dns-lab fixed-dns-pod -- nslookup web-svc
```

---

## Limpieza

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio:

```bash
# Eliminar pods de diagnóstico persistentes
kubectl delete pod fixed-dns-pod -n dns-lab --ignore-not-found=true
kubectl delete pod broken-dns-pod -n dns-lab --ignore-not-found=true

# Eliminar Deployments y Services en dns-lab
kubectl delete deployment web-server -n dns-lab --ignore-not-found=true
kubectl delete service web-svc -n dns-lab --ignore-not-found=true

# Eliminar Deployments y Services en dns-lab-b
kubectl delete deployment api-server -n dns-lab-b --ignore-not-found=true
kubectl delete service api-svc -n dns-lab-b --ignore-not-found=true

# Eliminar namespaces (esto elimina todos los recursos restantes dentro de ellos)
kubectl delete namespace dns-lab --ignore-not-found=true
kubectl delete namespace dns-lab-b --ignore-not-found=true

# Verificar limpieza completa
echo "=== Verificando limpieza ==="
kubectl get namespace dns-lab dns-lab-b 2>&1
# Debe retornar: Error from server (NotFound) para ambos

# Verificar que CoreDNS sigue operativo tras el laboratorio
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Ambas réplicas deben estar en Running
```

> **Nota sobre persistencia:** Los namespaces `dns-lab` y `dns-lab-b` son específicos de este laboratorio y no son reutilizados en labs posteriores. El clúster Minikube debe mantenerse en ejecución para el siguiente laboratorio (`minikube stop && minikube start` si es necesario reiniciar, **nunca** `minikube delete`).

---

## Resumen

En este laboratorio has aplicado los conceptos fundamentales del DNS interno de Kubernetes mediante escenarios prácticos progresivos:

| Actividad | Concepto aplicado |
|-----------|-------------------|
| Resolución por nombre corto en mismo namespace | `dnsPolicy: ClusterFirst` + search domains automáticos |
| Resolución cross-namespace con FQDN | Formato `<svc>.<ns>.svc.cluster.local` |
| Pod con `dnsPolicy: None` sin `dnsConfig` | Fallo total de resolución DNS |
| Pod con `dnsPolicy: None` + `dnsConfig` correcta | Control explícito del DNS del pod |
| Inspección del Corefile de CoreDNS | Zonas, forwarding, cache, health |
| Forwarding de nombres externos | `forward . /etc/resolv.conf` en CoreDNS |
| Impacto de CoreDNS en CrashLoopBackOff | Alta disponibilidad y diagnóstico |

**Conceptos clave para recordar:**

- **CoreDNS** es el servidor DNS del clúster, expuesto como el Service `kube-dns` en `kube-system` (generalmente en `10.96.0.10`).
- El **FQDN completo** `<service>.<namespace>.svc.cluster.local` siempre funciona independientemente del namespace del pod solicitante.
- El **nombre corto** solo funciona dentro del mismo namespace porque los `search domains` en `/etc/resolv.conf` solo incluyen el namespace del pod.
- `dnsPolicy: None` requiere obligatoriamente una `dnsConfig` explícita con al menos un `nameserver`; sin ella, el pod queda sin resolución DNS.
- Si CoreDNS pierde **todas** sus réplicas, el DNS del clúster cae completamente, afectando cualquier aplicación que use descubrimiento de servicios por nombre.

### Recursos adicionales

- [Documentación oficial: DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [CoreDNS: documentación del plugin `kubernetes`](https://coredns.io/plugins/kubernetes/)
- [Kubernetes: debugging de resolución DNS](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [CoreDNS: configuración del Corefile](https://coredns.io/manual/toc/#configuration)
- [dnsPolicy y dnsConfig en PodSpec](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy)

---
LAB_END---
