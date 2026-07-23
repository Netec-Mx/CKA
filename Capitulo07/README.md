# Práctica 7 — Despliegue con almacenamiento persistente usando PVC

## Metadatos

| Campo        | Valor                          |
|--------------|-------------------------------|
| **Duración** | 56 minutos                    |
| **Complejidad** | Alta                       |
| **Nivel Bloom** | Crear (Create)             |
| **Módulo**   | 7 — Almacenamiento en Kubernetes |
| **Versión Kubernetes** | 1.28+              |

---

## Descripción General

En este laboratorio realizarás un recorrido completo del ciclo de vida del almacenamiento persistente en Kubernetes. Partirás desde la creación manual de un `PersistentVolume` (PV) de tipo `hostPath`, pasarás por el binding con un `PersistentVolumeClaim` (PVC), desplegarás una aplicación stateful que monte ese volumen, y finalmente explorarás el aprovisionamiento dinámico mediante la `StorageClass` `local-path` del provisioner de Rancher. La práctica cierra con un ejercicio comparativo entre `emptyDir` y `PVC` y un escenario de troubleshooting realista donde un PVC queda en estado `Pending`.

---

## Objetivos de Aprendizaje

Al finalizar este laboratorio serás capaz de:

- [ ] Crear un `PersistentVolume` de tipo `hostPath` con capacidad, `accessMode` y `reclaimPolicy` específicos, y verificar su estado `Available`.
- [ ] Crear un `PersistentVolumeClaim` y observar el proceso de binding automático con el PV disponible.
- [ ] Desplegar un Pod con MySQL que monte un PVC en `/var/lib/mysql` y demostrar que los datos persisten tras eliminar y recrear el Pod.
- [ ] Aprovisionar almacenamiento dinámicamente usando la `StorageClass` `local-path` sin necesidad de crear un PV manual.
- [ ] Distinguir el comportamiento de `emptyDir` frente a `PVC` mediante evidencia práctica y documentar las diferencias.

---

## Prerrequisitos

### Conocimiento previo

- Dominio de la creación y aplicación de manifiestos YAML en Kubernetes.
- Comprensión de Pods, Deployments y ReplicaSets (Labs anteriores).
- Familiaridad con sistemas de archivos Linux y el concepto de montaje de directorios.
- Comprensión básica de aplicaciones stateful vs. stateless.
- Haber estudiado la lección 7.1 sobre tipos de volúmenes (`emptyDir`, `hostPath`, `persistentVolumeClaim`).

### Acceso y herramientas requeridas

- Clúster Minikube activo con **mínimo 2 nodos** (recomendado 3).
- `kubectl` 1.28+ configurado y apuntando al clúster correcto.
- `docker` accesible en el host para pre-descarga de imágenes.
- Terminal con acceso a `curl`, `jq` y `bash`.

---

## Entorno del Laboratorio

### Hardware mínimo recomendado

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU (núcleos físicos) | 4 | 8 |
| RAM | 8 GB | 16 GB |
| Almacenamiento libre | 40 GB | 60 GB |

### Software requerido

| Herramienta | Versión mínima |
|-------------|---------------|
| Minikube | 1.31.x |
| kubectl | 1.28.x |
| Docker Engine | 24.x |
| local-path-provisioner | 0.0.24+ |

### Configuración inicial del entorno

Ejecuta los siguientes comandos **antes de comenzar** el laboratorio para asegurarte de que el clúster está listo y las imágenes necesarias están disponibles.

```bash
# ── 1. Verificar que Minikube está activo con al menos 2 nodos ──────────────
minikube status
kubectl get nodes

# Si el clúster no existe o tiene solo 1 nodo, créalo con 3 nodos:
minikube start --nodes=3 --driver=docker --cpus=2 --memory=2048

# ── 2. Pre-descargar imágenes necesarias ────────────────────────────────────
# (Ejecutar en el host; Minikube con driver Docker usa el daemon del host)
for img in mysql:8.0 busybox:latest nginx:1.25; do
  docker pull $img
done

# Cargar imágenes en el nodo Minikube (si usa driver Docker con red aislada)
minikube image load mysql:8.0
minikube image load busybox:latest
minikube image load nginx:1.25

# ── 3. Habilitar el addon local-path-provisioner (Rancher) ──────────────────
# Minikube incluye storage-provisioner por defecto; verificar StorageClasses:
kubectl get storageclass

# Si no aparece 'standard' o 'local-path', habilitar el addon:
minikube addons enable storage-provisioner

# ── 4. Crear namespace de trabajo para este laboratorio ─────────────────────
kubectl create namespace lab07

# ── 5. Confirmar estado del clúster ────────────────────────────────────────
kubectl get nodes -o wide
kubectl get storageclass
```

> **Nota sobre macOS/Windows con WSL2:** Al usar el driver Docker, el acceso a volúmenes `hostPath` se realiza dentro del contenedor Docker que representa el nodo Minikube, no en el sistema de archivos del host. Esto es transparente para los manifiestos YAML pero debes tenerlo en cuenta si intentas inspeccionar los datos directamente en el host.

---

## Pasos del Laboratorio

---

### FASE 1 — Almacenamiento Estático: PersistentVolume Manual

**Tiempo estimado: 14 minutos**

---

#### Paso 1.1 — Crear el directorio en el nodo Minikube

**Objetivo:** Preparar el directorio físico en el nodo que servirá como backend de almacenamiento para el PV de tipo `hostPath`.

**Instrucciones:**

1. Accede al nodo principal de Minikube y crea el directorio que usará el PV:

```bash
# Acceder al nodo control-plane de Minikube
minikube ssh

# Dentro del nodo: crear el directorio de datos
sudo mkdir -p /mnt/data/lab07-pv
sudo chmod 777 /mnt/data/lab07-pv

# Verificar que el directorio existe
ls -la /mnt/data/

# Salir del nodo
exit
```

**Salida esperada:**

```
drwxrwxrwx 2 root root 4096 Jan 15 10:00 lab07-pv
```

**Verificación:**

```bash
# Confirmar desde fuera que el nodo está accesible
kubectl get nodes
```

---

#### Paso 1.2 — Crear el PersistentVolume

**Objetivo:** Definir un recurso `PersistentVolume` a nivel de clúster con capacidad de 1Gi, `accessMode` `ReadWriteOnce` y `reclaimPolicy` `Retain`.

**Instrucciones:**

1. Crea el archivo de manifiesto:

```bash
cat > pv-lab07-static.yaml << 'EOF'
# PersistentVolume de tipo hostPath para aprovisionamiento estático
# NOTA: hostPath es adecuado para desarrollo/laboratorio; en producción
# se usarían tipos como local, nfs, o volúmenes de proveedor cloud.
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-lab07-static
  labels:
    tipo: estatico          # Etiqueta para identificar PVs estáticos
    lab: lab07
spec:
  capacity:
    storage: 1Gi            # Capacidad total del volumen
  accessModes:
    - ReadWriteOnce         # Solo un nodo puede montar en lectura/escritura
  reclaimPolicy: Retain     # Al liberar el PVC, el PV y sus datos se conservan
  storageClassName: ""      # Sin StorageClass = aprovisionamiento manual
  hostPath:
    path: /mnt/data/lab07-pv   # Directorio en el nodo Minikube
    type: DirectoryOrCreate    # Crea el directorio si no existe
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f pv-lab07-static.yaml
```

3. Verifica el estado del PV:

```bash
kubectl get pv pv-lab07-static
kubectl describe pv pv-lab07-static
```

**Salida esperada:**

```
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pv-lab07-static   1Gi        RWO            Retain           Available           
```

**Verificación:**

```bash
# El STATUS debe ser 'Available' (sin binding aún)
kubectl get pv pv-lab07-static -o jsonpath='{.status.phase}'
# Salida esperada: Available
```

---

#### Paso 1.3 — Crear el PersistentVolumeClaim y verificar el Binding

**Objetivo:** Crear un PVC que solicite 1Gi con `ReadWriteOnce` y observar cómo Kubernetes lo vincula automáticamente al PV disponible.

**Instrucciones:**

1. Crea el manifiesto del PVC:

```bash
cat > pvc-lab07-static.yaml << 'EOF'
# PersistentVolumeClaim que solicita el PV estático creado anteriormente
# Al no especificar storageClassName, Kubernetes busca PVs con storageClassName vacío
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-lab07-static
  namespace: lab07
  labels:
    lab: lab07
spec:
  accessModes:
    - ReadWriteOnce         # Debe coincidir con el accessMode del PV
  resources:
    requests:
      storage: 500Mi        # Solicita 500Mi; el PV tiene 1Gi (suficiente)
  storageClassName: ""      # Sin StorageClass = binding manual con PV disponible
  volumeName: pv-lab07-static   # Selector explícito al PV específico
EOF
```

2. Aplica el manifiesto:

```bash
kubectl apply -f pvc-lab07-static.yaml
```

3. Verifica el binding:

```bash
# Observar el proceso de binding (puede ser inmediato)
kubectl get pvc pvc-lab07-static -n lab07
kubectl get pv pv-lab07-static
```

**Salida esperada:**

```
NAME               STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-lab07-static   Bound    pv-lab07-static   1Gi        RWO                           5s
```

```
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       AGE
pv-lab07-static   1Gi        RWO            Retain           Bound    lab07/pvc-lab07-static      10s
```

**Verificación:**

```bash
# Ambos deben mostrar STATUS = Bound
kubectl get pvc pvc-lab07-static -n lab07 -o jsonpath='{.status.phase}'
# Salida esperada: Bound

kubectl get pv pv-lab07-static -o jsonpath='{.status.phase}'
# Salida esperada: Bound

# Ver el detalle completo del binding
kubectl describe pvc pvc-lab07-static -n lab07
```

---

### FASE 2 — Despliegue Stateful: MySQL con Almacenamiento Persistente

**Tiempo estimado: 18 minutos**

---

#### Paso 2.1 — Desplegar MySQL montando el PVC

**Objetivo:** Desplegar un Pod de MySQL que use el PVC creado en la Fase 1 para almacenar sus datos en `/var/lib/mysql`, demostrando el montaje de un PVC como volumen en un contenedor.

**Instrucciones:**

1. Primero crea un Secret para la contraseña de MySQL:

```bash
kubectl create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD=K8sLab2024! \
  --from-literal=MYSQL_DATABASE=testdb \
  -n lab07
```

2. Crea el manifiesto del Pod de MySQL:

```bash
cat > pod-mysql-pvc.yaml << 'EOF'
# Pod de MySQL que monta el PVC como volumen persistente
# En producción se usaría un StatefulSet; aquí usamos Pod para simplicidad pedagógica
apiVersion: v1
kind: Pod
metadata:
  name: mysql-estatico
  namespace: lab07
  labels:
    app: mysql
    fase: estatica
spec:
  containers:
    - name: mysql
      image: mysql:8.0
      ports:
        - containerPort: 3306
      env:
        # Credenciales obtenidas del Secret (nunca hardcodeadas en el manifiesto)
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_ROOT_PASSWORD
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: MYSQL_DATABASE
      volumeMounts:
        # Montar el PVC en la ruta donde MySQL almacena sus datos
        - name: datos-mysql          # Referencia al volumen declarado abajo
          mountPath: /var/lib/mysql  # Ruta estándar de datos de MySQL
      resources:
        requests:
          memory: "256Mi"
          cpu: "250m"
        limits:
          memory: "512Mi"
          cpu: "500m"
  volumes:
    # Declaración del volumen usando el PVC creado en la Fase 1
    - name: datos-mysql
      persistentVolumeClaim:
        claimName: pvc-lab07-static  # Nombre del PVC en el mismo namespace
EOF
```

3. Aplica el manifiesto y monitorea el arranque:

```bash
kubectl apply -f pod-mysql-pvc.yaml

# Monitorear el estado (MySQL tarda ~30-60 segundos en inicializarse)
kubectl get pod mysql-estatico -n lab07 -w
```

4. Espera hasta que el Pod esté en estado `Running` (presiona `Ctrl+C` para salir del watch):

```bash
# Verificar que MySQL está listo
kubectl logs mysql-estatico -n lab07 | tail -5
```

**Salida esperada (logs):**

```
[System] [MY-010931] [Server] /usr/sbin/mysqld: ready for connections.
```

**Verificación:**

```bash
kubectl get pod mysql-estatico -n lab07
# STATUS debe ser: Running

kubectl describe pod mysql-estatico -n lab07 | grep -A 5 "Volumes:"
# Debe mostrar el PVC montado en /var/lib/mysql
```

---

#### Paso 2.2 — Escribir datos en el volumen persistente

**Objetivo:** Insertar datos en la base de datos MySQL para poder verificar su persistencia después de eliminar el Pod.

**Instrucciones:**

1. Conéctate al Pod de MySQL y crea datos de prueba:

```bash
# Ejecutar un comando interactivo en el contenedor MySQL
kubectl exec -it mysql-estatico -n lab07 -- \
  mysql -u root -pK8sLab2024! testdb -e "
    CREATE TABLE IF NOT EXISTS registros (
      id INT AUTO_INCREMENT PRIMARY KEY,
      mensaje VARCHAR(255),
      fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO registros (mensaje) VALUES
      ('Dato persistente 1 - Lab07'),
      ('Dato persistente 2 - Lab07'),
      ('Dato persistente 3 - Lab07');
    SELECT * FROM registros;
  "
```

2. Confirma que los datos fueron insertados:

```bash
kubectl exec -it mysql-estatico -n lab07 -- \
  mysql -u root -pK8sLab2024! testdb -e "SELECT COUNT(*) as total FROM registros;"
```

**Salida esperada:**

```
+-------+
| total |
+-------+
|     3 |
+-------+
```

**Verificación:**

```bash
# Guardar el conteo para comparar después de recrear el Pod
echo "Registros antes de eliminar el Pod: $(kubectl exec mysql-estatico -n lab07 -- \
  mysql -u root -pK8sLab2024! testdb -sNe 'SELECT COUNT(*) FROM registros;' 2>/dev/null)"
```

---

#### Paso 2.3 — Demostrar la persistencia: eliminar y recrear el Pod

**Objetivo:** Eliminar el Pod de MySQL, recrearlo con el mismo PVC y verificar que los datos sobreviven, demostrando la diferencia fundamental entre almacenamiento efímero y persistente.

**Instrucciones:**

1. Elimina el Pod (los datos deben sobrevivir en el PV):

```bash
kubectl delete pod mysql-estatico -n lab07
# Verificar que el Pod fue eliminado
kubectl get pod mysql-estatico -n lab07
# Error esperado: "Error from server (NotFound)" → correcto

# Verificar que el PVC y PV siguen existiendo (no se eliminan con el Pod)
kubectl get pvc pvc-lab07-static -n lab07
kubectl get pv pv-lab07-static
```

2. Recrea el Pod usando el mismo manifiesto:

```bash
kubectl apply -f pod-mysql-pvc.yaml

# Esperar a que el Pod esté Running
kubectl get pod mysql-estatico -n lab07 -w
# (Ctrl+C cuando esté Running)
```

3. Verifica que los datos persisten:

```bash
kubectl exec -it mysql-estatico -n lab07 -- \
  mysql -u root -pK8sLab2024! testdb -e "SELECT * FROM registros;"
```

**Salida esperada (los datos deben estar intactos):**

```
+----+---------------------------+---------------------+
| id | mensaje                   | fecha               |
+----+---------------------------+---------------------+
|  1 | Dato persistente 1 - Lab07| 2024-01-15 10:15:00 |
|  2 | Dato persistente 2 - Lab07| 2024-01-15 10:15:00 |
|  3 | Dato persistente 3 - Lab07| 2024-01-15 10:15:00 |
+----+---------------------------+---------------------+
```

**Verificación:**

```bash
# Comparar el conteo: debe ser 3 (igual que antes de eliminar el Pod)
REGISTROS=$(kubectl exec mysql-estatico -n lab07 -- \
  mysql -u root -pK8sLab2024! testdb -sNe 'SELECT COUNT(*) FROM registros;' 2>/dev/null)
echo "Registros después de recrear el Pod: $REGISTROS"
[[ "$REGISTROS" == "3" ]] && echo "✅ PERSISTENCIA VERIFICADA" || echo "❌ ERROR: datos perdidos"
```

---

### FASE 3 — StorageClass Dinámica con local-path-provisioner

**Tiempo estimado: 12 minutos**

---

#### Paso 3.1 — Verificar la StorageClass disponible

**Objetivo:** Identificar la `StorageClass` disponible en el clúster Minikube que permite aprovisionamiento dinámico sin necesidad de crear PVs manualmente.

**Instrucciones:**

1. Inspecciona las StorageClasses disponibles:

```bash
kubectl get storageclass
kubectl describe storageclass standard
```

2. Identifica el provisioner activo:

```bash
# En Minikube, el provisioner por defecto suele ser:
# k8s.io/minikube-hostpath o rancher.io/local-path
kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.provisioner}{"\n"}{end}'
```

**Salida esperada (puede variar según la versión de Minikube):**

```
standard    k8s.io/minikube-hostpath
```

> **Nota:** En este laboratorio usaremos la StorageClass `standard` de Minikube, que funciona como provisioner dinámico. Si en tu entorno está disponible `local-path` (de Rancher), puedes usarla en su lugar. El comportamiento es equivalente para los objetivos de este lab.

**Verificación:**

```bash
# Identificar cuál es la StorageClass marcada como default
kubectl get storageclass | grep "(default)"
```

---

#### Paso 3.2 — Crear un PVC con aprovisionamiento dinámico

**Objetivo:** Crear un PVC que use la StorageClass `standard` para que Kubernetes aprovisione automáticamente un PV sin intervención manual.

**Instrucciones:**

1. Crea el manifiesto del PVC dinámico:

```bash
cat > pvc-lab07-dinamico.yaml << 'EOF'
# PVC con aprovisionamiento dinámico usando StorageClass
# A diferencia del PVC estático, NO se especifica volumeName
# Kubernetes creará automáticamente un PV cuando este PVC sea creado
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-lab07-dinamico
  namespace: lab07
  labels:
    lab: lab07
    tipo: dinamico
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi          # Capacidad solicitada al provisioner
  storageClassName: standard  # Referencia a la StorageClass del clúster
  # NOTA: No se especifica volumeName → el provisioner crea el PV automáticamente
EOF
```

2. Aplica el manifiesto y observa el aprovisionamiento dinámico:

```bash
kubectl apply -f pvc-lab07-dinamico.yaml

# Observar el binding (puede ser casi inmediato con el provisioner de Minikube)
kubectl get pvc pvc-lab07-dinamico -n lab07 -w
# (Ctrl+C cuando esté Bound)
```

3. Verifica que se creó automáticamente un PV:

```bash
# Listar todos los PVs: debe aparecer uno nuevo creado por el provisioner
kubectl get pv

# Ver los detalles del PV creado dinámicamente
kubectl get pvc pvc-lab07-dinamico -n lab07 -o jsonpath='{.spec.volumeName}'
```

**Salida esperada:**

```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                         STORAGECLASS   AGE
pv-lab07-static                            1Gi        RWO            Retain           Bound    lab07/pvc-lab07-static                       15m
pvc-lab07-dinamico-XXXX (auto-generado)    200Mi      RWO            Delete           Bound    lab07/pvc-lab07-dinamico       standard       5s
```

**Verificación:**

```bash
# El PVC debe estar Bound y el PV asociado debe tener reclaimPolicy=Delete
PV_NAME=$(kubectl get pvc pvc-lab07-dinamico -n lab07 -o jsonpath='{.spec.volumeName}')
echo "PV creado dinámicamente: $PV_NAME"
kubectl get pv $PV_NAME -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
# Salida esperada: Delete (el PV se elimina cuando se borra el PVC)
```

---

#### Paso 3.3 — Desplegar un Pod usando el PVC dinámico

**Objetivo:** Usar el PVC de aprovisionamiento dinámico en un Pod de nginx para confirmar que el volumen está operativo.

**Instrucciones:**

1. Crea un Pod de nginx que monte el PVC dinámico:

```bash
cat > pod-nginx-dinamico.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nginx-dinamico
  namespace: lab07
  labels:
    app: nginx
    fase: dinamica
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
      volumeMounts:
        - name: datos-nginx
          mountPath: /usr/share/nginx/html   # Directorio de contenido web de nginx
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "200m"
  volumes:
    - name: datos-nginx
      persistentVolumeClaim:
        claimName: pvc-lab07-dinamico   # PVC aprovisionado dinámicamente
EOF
```

2. Aplica y verifica:

```bash
kubectl apply -f pod-nginx-dinamico.yaml
kubectl get pod nginx-dinamico -n lab07 -w
# (Ctrl+C cuando esté Running)
```

3. Escribe un archivo en el volumen y verifica:

```bash
# Escribir un archivo HTML en el volumen persistente
kubectl exec nginx-dinamico -n lab07 -- \
  sh -c 'echo "<h1>Almacenamiento Dinamico Lab07</h1>" > /usr/share/nginx/html/index.html'

# Verificar que el archivo existe en el volumen
kubectl exec nginx-dinamico -n lab07 -- cat /usr/share/nginx/html/index.html
```

**Salida esperada:**

```
<h1>Almacenamiento Dinamico Lab07</h1>
```

**Verificación:**

```bash
kubectl get pod nginx-dinamico -n lab07
# STATUS: Running

kubectl describe pod nginx-dinamico -n lab07 | grep -A 3 "Mounts:"
# Debe mostrar: /usr/share/nginx/html from datos-nginx (rw)
```

---

### FASE 4 — Comparativa: emptyDir vs PVC

**Tiempo estimado: 7 minutos**

---

#### Paso 4.1 — Demostrar la pérdida de datos con emptyDir

**Objetivo:** Crear un Pod con `emptyDir` para contrastar su comportamiento efímero con el comportamiento persistente del PVC, completando el análisis comparativo del ciclo de vida del almacenamiento.

**Instrucciones:**

1. Crea un Pod con `emptyDir`:

```bash
cat > pod-emptydir-comparativa.yaml << 'EOF'
# Pod con volumen emptyDir para demostrar almacenamiento EFÍMERO
# Este volumen desaparece cuando el Pod es eliminado
apiVersion: v1
kind: Pod
metadata:
  name: pod-emptydir
  namespace: lab07
  labels:
    tipo: efimero
spec:
  containers:
    - name: escritor
      image: busybox
      command: ["sh", "-c", "echo 'Dato efimero Lab07' > /datos/archivo.txt && sleep 3600"]
      volumeMounts:
        - name: datos-efimeros
          mountPath: /datos
      resources:
        requests:
          memory: "32Mi"
          cpu: "50m"
  volumes:
    - name: datos-efimeros
      emptyDir: {}    # Volumen efímero: se crea vacío y desaparece con el Pod
EOF
```

2. Aplica, escribe datos y verifica:

```bash
kubectl apply -f pod-emptydir-comparativa.yaml
kubectl get pod pod-emptydir -n lab07 -w
# (Ctrl+C cuando esté Running)

# Verificar que el archivo existe
kubectl exec pod-emptydir -n lab07 -- cat /datos/archivo.txt
```

3. Elimina el Pod y recréalo para demostrar la pérdida de datos:

```bash
# Eliminar el Pod
kubectl delete pod pod-emptydir -n lab07

# Recrear el Pod
kubectl apply -f pod-emptydir-comparativa.yaml
kubectl get pod pod-emptydir -n lab07 -w
# (Ctrl+C cuando esté Running)

# Intentar leer el archivo: NO debe existir
kubectl exec pod-emptydir -n lab07 -- cat /datos/archivo.txt 2>&1 || \
  echo "❌ Archivo NO encontrado → datos perdidos (comportamiento esperado con emptyDir)"
```

**Salida esperada:**

```
cat: can't open '/datos/archivo.txt': No such file or directory
❌ Archivo NO encontrado → datos perdidos (comportamiento esperado con emptyDir)
```

**Verificación — Tabla Comparativa:**

```bash
echo "
╔══════════════════════════════════════════════════════════════════╗
║           COMPARATIVA: emptyDir vs PVC                          ║
╠══════════════════════╦═══════════════════╦══════════════════════╣
║ Característica       ║ emptyDir          ║ PVC (hostPath/local) ║
╠══════════════════════╬═══════════════════╬══════════════════════╣
║ Ciclo de vida        ║ Vida del Pod      ║ Independiente del Pod║
║ Datos tras delete Pod║ PERDIDOS          ║ CONSERVADOS          ║
║ Compartible (mismo Pod)║ Sí (entre cont.)║ Sí (entre cont.)    ║
║ Compartible (multi-Pod)║ No              ║ Sí (RWX)            ║
║ Requiere PV/PVC      ║ No               ║ Sí                   ║
║ Caso de uso típico   ║ Cache temporal    ║ Base de datos, logs  ║
╚══════════════════════╩═══════════════════╩══════════════════════╝
"
```

---

### FASE 4B — Escenario de Troubleshooting: PVC en estado Pending

**Tiempo estimado: 5 minutos**

---

#### Paso 4B.1 — Reproducir un PVC en estado Pending

**Objetivo:** Crear intencionalmente un PVC que no pueda hacer binding por incompatibilidad de capacidad, y diagnosticar el problema usando `kubectl describe`.

**Instrucciones:**

1. Crea un PVC que solicita más capacidad de la disponible:

```bash
cat > pvc-troubleshooting.yaml << 'EOF'
# PVC INTENCIONAL CON ERROR: solicita 10Gi pero el PV estático solo tiene 1Gi
# Esto causará que el PVC quede en estado Pending indefinidamente
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-troubleshooting
  namespace: lab07
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi       # ERROR INTENCIONAL: excede la capacidad del PV disponible
  storageClassName: ""    # Sin StorageClass → busca PV manual
EOF
```

2. Aplica y observa el estado:

```bash
kubectl apply -f pvc-troubleshooting.yaml
kubectl get pvc pvc-troubleshooting -n lab07
```

**Salida esperada:**

```
NAME                  STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-troubleshooting   Pending                                                     5s
```

3. Diagnostica el problema:

```bash
kubectl describe pvc pvc-troubleshooting -n lab07
```

**Salida esperada (sección Events):**

```
Events:
  Type     Reason         Age   From                         Message
  ----     ------         ----  ----                         -------
  Warning  VolumeMismatch  5s   persistentvolume-controller  Can't bind to requested volume "": volume capacity less than PVC capacity
  Normal   FailedBinding   5s   persistentvolume-controller  no persistent volumes available for this claim and no storage class is set
```

4. Soluciona el problema corrigiendo la capacidad:

```bash
# Corregir el PVC con una capacidad compatible
kubectl patch pvc pvc-troubleshooting -n lab07 \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/resources/requests/storage", "value": "500Mi"}]'

# Alternativamente, eliminar y recrear con la capacidad correcta:
kubectl delete pvc pvc-troubleshooting -n lab07

cat > pvc-troubleshooting-fixed.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-troubleshooting-fixed
  namespace: lab07
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi      # Corregido: dentro de la capacidad del PV
  storageClassName: ""
EOF

kubectl apply -f pvc-troubleshooting-fixed.yaml
kubectl get pvc pvc-troubleshooting-fixed -n lab07
```

**Verificación:**

```bash
kubectl get pvc pvc-troubleshooting-fixed -n lab07
# STATUS debe ser: Bound (si hay un PV disponible con storageClassName vacío)
# NOTA: Si el único PV estático ya está Bound por pvc-lab07-static, este PVC
# puede quedar Pending hasta que ese PV sea liberado. Esto es comportamiento correcto.
```

---

## Validación y Pruebas Finales

Ejecuta el siguiente script de validación para confirmar que todos los componentes del laboratorio están correctamente configurados:

```bash
#!/bin/bash
# Script de validación Lab 07-00-01
echo "════════════════════════════════════════════════════"
echo "   VALIDACIÓN FINAL - Lab 07-00-01"
echo "════════════════════════════════════════════════════"

PASS=0
FAIL=0

check() {
  local descripcion="$1"
  local comando="$2"
  local esperado="$3"
  local resultado
  resultado=$(eval "$comando" 2>/dev/null)
  if [[ "$resultado" == *"$esperado"* ]]; then
    echo "  ✅ $descripcion"
    ((PASS++))
  else
    echo "  ❌ $descripcion (obtenido: '$resultado', esperado: '$esperado')"
    ((FAIL++))
  fi
}

echo ""
echo "── FASE 1: Almacenamiento Estático ────────────────"
check "PV pv-lab07-static existe" \
  "kubectl get pv pv-lab07-static -o jsonpath='{.metadata.name}'" \
  "pv-lab07-static"

check "PV tiene capacidad 1Gi" \
  "kubectl get pv pv-lab07-static -o jsonpath='{.spec.capacity.storage}'" \
  "1Gi"

check "PV tiene reclaimPolicy Retain" \
  "kubectl get pv pv-lab07-static -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'" \
  "Retain"

check "PVC pvc-lab07-static está Bound" \
  "kubectl get pvc pvc-lab07-static -n lab07 -o jsonpath='{.status.phase}'" \
  "Bound"

echo ""
echo "── FASE 2: Despliegue Stateful ─────────────────────"
check "Pod mysql-estatico está Running" \
  "kubectl get pod mysql-estatico -n lab07 -o jsonpath='{.status.phase}'" \
  "Running"

check "MySQL tiene datos persistentes" \
  "kubectl exec mysql-estatico -n lab07 -- mysql -u root -pK8sLab2024! testdb -sNe 'SELECT COUNT(*) FROM registros;' 2>/dev/null" \
  "3"

echo ""
echo "── FASE 3: Aprovisionamiento Dinámico ──────────────"
check "PVC pvc-lab07-dinamico está Bound" \
  "kubectl get pvc pvc-lab07-dinamico -n lab07 -o jsonpath='{.status.phase}'" \
  "Bound"

check "Pod nginx-dinamico está Running" \
  "kubectl get pod nginx-dinamico -n lab07 -o jsonpath='{.status.phase}'" \
  "Running"

check "StorageClass standard existe" \
  "kubectl get storageclass standard -o jsonpath='{.metadata.name}'" \
  "standard"

echo ""
echo "── FASE 4: Comparativa ─────────────────────────────"
check "Namespace lab07 existe" \
  "kubectl get namespace lab07 -o jsonpath='{.metadata.name}'" \
  "lab07"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Resultado: ✅ $PASS pasaron | ❌ $FAIL fallaron"
echo "════════════════════════════════════════════════════"
```

```bash
# Guardar y ejecutar el script
chmod +x validacion-lab07.sh
bash validacion-lab07.sh
```

**Resultado esperado:** Todos los checks deben mostrar ✅. Si alguno falla, revisa el paso correspondiente.

---

## Troubleshooting

### Problema 1: El Pod de MySQL queda en estado `Pending` o `CrashLoopBackOff`

**Síntomas:**
```
NAME             READY   STATUS             RESTARTS   AGE
mysql-estatico   0/1     Pending            0          2m
# O bien:
mysql-estatico   0/1     CrashLoopBackOff   3          5m
```

**Causa raíz:**

Existen dos causas comunes:
- **`Pending`:** El PVC no está en estado `Bound` (el PV puede no existir, tener `storageClassName` incompatible, o la capacidad solicitada supera la disponible). También puede ocurrir si el nodo no tiene recursos suficientes.
- **`CrashLoopBackOff`:** MySQL falla al iniciar porque el directorio `/var/lib/mysql` ya contiene datos de una versión anterior incompatible, o la variable de entorno `MYSQL_ROOT_PASSWORD` no está correctamente configurada desde el Secret.

**Diagnóstico y solución:**

```bash
# Paso 1: Verificar eventos del Pod
kubectl describe pod mysql-estatico -n lab07 | grep -A 20 "Events:"

# Paso 2: Si el problema es el PVC, verificar su estado
kubectl describe pvc pvc-lab07-static -n lab07

# Paso 3: Si el PVC está Pending, verificar que el PV existe y tiene storageClassName vacío
kubectl get pv -o custom-columns=\
NAME:.metadata.name,CAPACITY:.spec.capacity.storage,\
STATUS:.status.phase,STORAGECLASS:.spec.storageClassName

# Paso 4: Si es CrashLoopBackOff, ver los logs del contenedor
kubectl logs mysql-estatico -n lab07 --previous

# Solución para datos corruptos en el hostPath:
# Acceder al nodo y limpiar el directorio
minikube ssh
sudo rm -rf /mnt/data/lab07-pv/*
exit

# Luego eliminar y recrear el Pod
kubectl delete pod mysql-estatico -n lab07
kubectl apply -f pod-mysql-pvc.yaml

# Solución para Secret incorrecto:
kubectl delete secret mysql-secret -n lab07
kubectl create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD=K8sLab2024! \
  --from-literal=MYSQL_DATABASE=testdb \
  -n lab07
kubectl delete pod mysql-estatico -n lab07
kubectl apply -f pod-mysql-pvc.yaml
```

---

### Problema 2: El PVC dinámico queda en estado `Pending` con el error `no storage class found`

**Síntomas:**
```
NAME                   STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-lab07-dinamico     Pending                                       standard       3m

# kubectl describe muestra:
# Warning  ProvisioningFailed  storageclass.storage.k8s.io "standard" not found
```

**Causa raíz:**

La `StorageClass` `standard` no existe en el clúster, o el addon `storage-provisioner` de Minikube no está habilitado. Esto ocurre frecuentemente cuando Minikube se inició con opciones que deshabilitan los addons por defecto, o cuando se usa un clúster `kind` sin configuración de StorageClass.

**Diagnóstico y solución:**

```bash
# Paso 1: Verificar qué StorageClasses existen
kubectl get storageclass

# Paso 2: Si no hay ninguna, habilitar el addon de Minikube
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Paso 3: Verificar que el addon está activo
minikube addons list | grep storage

# Paso 4: Esperar 30 segundos y verificar que la StorageClass apareció
sleep 30
kubectl get storageclass

# Paso 5: Si usas kind en lugar de Minikube, instalar local-path-provisioner manualmente
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml

# Verificar que el provisioner está corriendo
kubectl get pods -n local-path-storage

# Paso 6: Si la StorageClass tiene un nombre diferente, actualizar el PVC
# Por ejemplo, si la StorageClass se llama 'local-path':
kubectl delete pvc pvc-lab07-dinamico -n lab07
sed 's/storageClassName: standard/storageClassName: local-path/' \
  pvc-lab07-dinamico.yaml | kubectl apply -f -

# Paso 7: Verificar el nuevo estado del PVC
kubectl get pvc pvc-lab07-dinamico -n lab07
```

---

## Limpieza del Entorno

Ejecuta los siguientes comandos para eliminar todos los recursos creados en este laboratorio. Los recursos del namespace `lab07` se eliminarán en cascada.

```bash
# ── Opción 1: Eliminar todos los recursos del namespace (recomendado) ────────
echo "Eliminando recursos del namespace lab07..."
kubectl delete namespace lab07
# Esto elimina: Pods, PVCs, Secrets y todos los recursos con namespace

# ── Esperar a que el namespace sea eliminado completamente ──────────────────
kubectl get namespace lab07
# Debe mostrar: Error from server (NotFound)

# ── Eliminar los PVs (son recursos de clúster, no de namespace) ─────────────
kubectl delete pv pv-lab07-static
# El PV dinámico se elimina automáticamente al borrar el PVC (reclaimPolicy=Delete)
# Verificar que no quedan PVs del lab:
kubectl get pv | grep lab07

# ── Limpiar el directorio en el nodo Minikube ───────────────────────────────
minikube ssh -- sudo rm -rf /mnt/data/lab07-pv

# ── Eliminar archivos YAML locales (opcional) ────────────────────────────────
rm -f pv-lab07-static.yaml \
      pvc-lab07-static.yaml \
      pod-mysql-pvc.yaml \
      pvc-lab07-dinamico.yaml \
      pod-nginx-dinamico.yaml \
      pod-emptydir-comparativa.yaml \
      pvc-troubleshooting.yaml \
      pvc-troubleshooting-fixed.yaml \
      validacion-lab07.sh

echo "✅ Limpieza completada"

# ── Verificación final ───────────────────────────────────────────────────────
kubectl get all -n lab07 2>&1 || echo "Namespace lab07 eliminado correctamente"
kubectl get pv | grep lab07 || echo "No quedan PVs del laboratorio"
```

> **Importante:** Si planeas continuar con laboratorios posteriores que reutilicen recursos de almacenamiento, omite la eliminación del clúster Minikube. Usa `minikube stop && minikube start` para pausar y reanudar el entorno.

---

## Resumen

En este laboratorio recorriste el ciclo de vida completo del almacenamiento persistente en Kubernetes a través de cuatro fases progresivas:

| Fase | Concepto trabajado | Resultado clave |
|------|-------------------|-----------------|
| **1 — Estático** | PV manual + PVC + binding | Comprensión del proceso de binding PV↔PVC |
| **2 — Stateful** | MySQL con PVC montado | Datos persisten tras eliminar y recrear el Pod |
| **3 — Dinámico** | StorageClass + provisioner | PV creado automáticamente sin intervención manual |
| **4 — Comparativa** | emptyDir vs PVC | Evidencia práctica de almacenamiento efímero vs persistente |

### Conceptos clave consolidados

- **`PersistentVolume` (PV):** Recurso de clúster que representa almacenamiento físico. Puede ser provisionado manualmente (estático) o automáticamente (dinámico mediante StorageClass).
- **`PersistentVolumeClaim` (PVC):** Solicitud de almacenamiento por parte de un usuario/aplicación. Kubernetes realiza el binding automático con un PV compatible.
- **`reclaimPolicy: Retain`:** Los datos y el PV sobreviven a la eliminación del PVC. Requiere limpieza manual por parte del administrador.
- **`reclaimPolicy: Delete`:** El PV y sus datos se eliminan automáticamente cuando se borra el PVC. Estándar en aprovisionamiento dinámico.
- **`storageClassName: ""`:** Indica aprovisionamiento estático; Kubernetes busca PVs sin StorageClass asignada.
- **`emptyDir`:** Almacenamiento efímero vinculado al ciclo de vida del Pod. Útil para datos temporales o comunicación entre contenedores del mismo Pod.

### Recursos adicionales

- [Documentación oficial: Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Documentación oficial: Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Rancher local-path-provisioner en GitHub](https://github.com/rancher/local-path-provisioner)
- [Guía CKA: Storage (Linux Foundation)](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- [Kubernetes Storage Best Practices (CNCF)](https://www.cncf.io/blog/2020/09/22/kubernetes-storage-a-practical-guide/)

---
