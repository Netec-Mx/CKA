---
layout: lab
title: "Práctica 7: Despliegue con almacenamiento persistente usando PVC"
permalink: /lab13/lab13/
images_base: /labs/lab13/img
duration: "50 minutos"
objective:
  - Crear un PersistentVolume estático y vincularlo con un PersistentVolumeClaim.
  - Desplegar MySQL utilizando un PVC como almacenamiento persistente.
  - Verificar que los datos sobreviven a la eliminación y recreación del Pod.
  - Crear un PVC mediante aprovisionamiento dinámico utilizando la StorageClass predeterminada de Minikube.
  - Comparar de forma práctica el comportamiento de un volumen persistente con emptyDir.
prerequisites:
  - Haber completado las prácticas anteriores de Pods, Deployments, configuración, seguridad y networking.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Conservar el clúster Minikube de tres nodos utilizado en las prácticas anteriores.
  - Tener conocimientos básicos sobre sistemas de archivos y almacenamiento persistente.
introduction:
  - En esta práctica recorrerás el ciclo de vida básico del almacenamiento persistente en Kubernetes. Crearás un PersistentVolume manual, solicitarás capacidad mediante un PersistentVolumeClaim, montarás ese almacenamiento en MySQL y demostrarás que los datos permanecen aunque el Pod sea eliminado y recreado. Después compararás este modelo con aprovisionamiento dinámico y con emptyDir para distinguir almacenamiento persistente y efímero.
slug: lab13
lab_number: 13
final_result: >
  Al finalizar la práctica habrás creado y consumido almacenamiento persistente mediante PV y PVC, verificado la conservación de datos después de recrear un Pod y utilizado aprovisionamiento dinámico mediante StorageClass.
notes:
  - Esta práctica utiliza el namespace lab7.
  - El PV estático usa hostPath únicamente con fines de laboratorio y queda asociado al nodo minikube mediante nodeAffinity.
  - En producción se utilizan normalmente soluciones CSI y almacenamiento proporcionado por infraestructura externa.
  - No elimines el clúster Minikube durante la práctica.
  - En Git Bash, las rutas Linux utilizadas dentro de contenedores se ejecutan mediante `sh -c` para evitar la conversión automática de rutas de MSYS2.
  - El PV estático utiliza `storageClassName ""` para impedir que la StorageClass predeterminada intervenga en el binding manual.
  - La política `Retain` conserva los datos del PV aunque posteriormente se elimine el PVC; no elimina automáticamente el contenido de `hostPath`.
references:
  - text: Persistent Volumes
    url: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
  - text: Storage Classes
    url: https://kubernetes.io/docs/concepts/storage/storage-classes/
  - text: Volumes
    url: https://kubernetes.io/docs/concepts/storage/volumes/
  - text: Minikube Persistent Volumes
    url: https://minikube.sigs.k8s.io/docs/handbook/persistent_volumes/
prev: /lab12/lab12/
next: /lab14/lab14/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del directorio y namespace

En esta práctica crearás recursos de almacenamiento con alcance de clúster y recursos namespaced dentro de `lab7`.

### 🗂️ Preparar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que el motor continúa activo antes de verificar los nodos y el almacenamiento disponible.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio correspondiente al laboratorio.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab7
  cd /c/LABS/kubernetes/lab7
  ```

- {% include step_label.html %} Comprueba que Minikube continúa activo y que los nodos del clúster permanecen en estado `Ready`.

  ```bash
  minikube status
  kubectl get nodes
  ```

**Salida esperada aproximada:**

```text
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running

NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   ...   ...
minikube-m02   Ready    <none>          ...   ...
minikube-m03   Ready    <none>          ...   ...
```

Los nombres exactos, versión y antigüedad pueden variar, pero los tres nodos deben permanecer `Ready`.

- {% include step_label.html %} Crea el namespace `lab7` para aislar los PVC, Pods, Secret y demás recursos namespaced utilizados durante el ejercicio.

  ```bash
  kubectl create namespace lab7
  ```

**Salida esperada:**

```text
namespace/lab7 created
```

- {% include step_label.html %} Establece `lab7` como namespace predeterminado del contexto actual para reducir errores en comandos posteriores.

  ```bash
  kubectl config set-context --current --namespace=lab7
  ```

**Salida esperada aproximada:**

```text
Context "<nombre-del-contexto>" modified.
```

- {% include step_label.html %} Consulta las StorageClasses existentes para identificar la opción predeterminada disponible en Minikube.

  ```bash
  kubectl get storageclass
  ```

**Salida esperada aproximada:**

```text
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate
```

El nombre del provisioner y `VOLUMEBINDINGMODE` pueden variar entre versiones; debe existir una StorageClass marcada como `(default)` para la Tarea 3.

> **IMPORTANTE:** No asumas el nombre de la StorageClass predeterminada hasta revisar esta salida. En instalaciones habituales de Minikube aparece `standard`, pero debes utilizar el valor real de tu clúster.
{: .lab-note .important .compact}

---

## 💾 Tarea 1. Crear un PV estático y vincularlo con un PVC

En esta tarea crearás almacenamiento estático mediante `hostPath` y limitarás su uso al nodo `minikube` para evitar que el volumen apunte a directorios diferentes en un clúster multinodo.

### Tarea 1.1. Preparar el directorio del nodo

- {% include step_label.html %} Crea el directorio que respaldará el PV dentro del nodo principal de Minikube.

  ```bash
  minikube ssh -- "sudo mkdir -p /mnt/data/lab7-pv && sudo chmod 777 /mnt/data/lab7-pv"
  ```

**Salida esperada:**

El comando no debe mostrar errores. Puede finalizar sin imprimir texto.

- {% include step_label.html %} Comprueba que el directorio existe en el nodo antes de definir el PersistentVolume.

  ```bash
  minikube ssh -- "ls -ld /mnt/data/lab7-pv"
  ```

**Salida esperada aproximada:**

```text
drwxrwxrwx ... /mnt/data/lab7-pv
```

### Tarea 1.2. Crear el PersistentVolume

- {% include step_label.html %} Crea el archivo `pv-static.yaml` para definir un PV de 1 GiB con política `Retain`.

  ```bash
  touch pv-static.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente, incluyendo afinidad al nodo `minikube`.

  ```yaml
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: pv-lab7-static
    labels:
      lab: lab7
      type: static
  spec:
    capacity:
      storage: 1Gi
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: ""
    hostPath:
      path: /mnt/data/lab7-pv
      type: DirectoryOrCreate
    nodeAffinity:
      required:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                  - minikube
  ```

- {% include step_label.html %} Valida y aplica el PV antes de crear cualquier reclamación de almacenamiento.

  ```bash
  kubectl apply --dry-run=client -f pv-static.yaml
  ```

**Salida esperada:**

```text
persistentvolume/pv-lab7-static created (dry run)
```

- {% include step_label.html %} Aplica el manifiesto validado para crear el PV de alcance de clúster.

  ```bash
  kubectl apply -f pv-static.yaml
  ```

**Salida esperada:**

```text
persistentvolume/pv-lab7-static created
```

- {% include step_label.html %} Comprueba que el PV se encuentra `Available` y todavía no está asociado con ningún PVC.

  ```bash
  kubectl get pv pv-lab7-static
  ```

**Salida esperada aproximada:**

```text
NAME              CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      STORAGECLASS
pv-lab7-static   1Gi        RWO            Retain           Available
```

### Tarea 1.3. Crear el PersistentVolumeClaim

- {% include step_label.html %} Crea `pvc-static.yaml` para solicitar 500 MiB sobre el PV estático definido anteriormente.

  ```bash
  touch pvc-static.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: pvc-lab7-static
    namespace: lab7
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 500Mi
    storageClassName: ""
    volumeName: pv-lab7-static
  ```

- {% include step_label.html %} Valida el PVC antes de crearlo para confirmar que solicita explícitamente `pv-lab7-static` y no activa aprovisionamiento dinámico.

  ```bash
  kubectl apply --dry-run=client -f pvc-static.yaml
  ```

**Salida esperada:**

```text
persistentvolumeclaim/pvc-lab7-static created (dry run)
```

- {% include step_label.html %} Aplica el PVC y espera hasta que Kubernetes complete el binding con el PV estático.

  ```bash
  kubectl apply -f pvc-static.yaml

  kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/pvc-lab7-static -n lab7 --timeout=60s
  ```

**Salida esperada:**

```text
persistentvolumeclaim/pvc-lab7-static created
persistentvolumeclaim/pvc-lab7-static condition met
```

- {% include step_label.html %} Comprueba desde ambos recursos que el PVC quedó enlazado exactamente con `pv-lab7-static`.

  ```bash
  kubectl get pvc pvc-lab7-static -n lab7
  kubectl get pv pv-lab7-static
  ```

**Salida esperada aproximada:**

```text
NAME               STATUS   VOLUME            CAPACITY   ACCESS MODES
pvc-lab7-static   Bound    pv-lab7-static   1Gi        RWO
```

El PV `pv-lab7-static` también debe aparecer con estado `Bound` y con `CLAIM` igual a `lab7/pvc-lab7-static`.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🗄️ Tarea 2. Desplegar MySQL utilizando almacenamiento persistente

En esta tarea montarás el PVC en `/var/lib/mysql`, crearás datos de prueba y demostrarás que esos datos sobreviven al ciclo de vida del Pod.

### Tarea 2.1. Crear las credenciales

- {% include step_label.html %} Crea un Secret con credenciales exclusivamente destinadas al laboratorio.

  ```bash
  kubectl create secret generic mysql-secret --from-literal=MYSQL_ROOT_PASSWORD='K8s-lab7-2026!' --from-literal=MYSQL_DATABASE=testdb -n lab7
  ```

**Salida esperada:**

```text
secret/mysql-secret created
```

### Tarea 2.2. Crear el Pod MySQL

- {% include step_label.html %} Crea el archivo `mysql-pvc.yaml` para montar `pvc-lab7-static` en la ruta de datos utilizada por MySQL.

  ```bash
  touch mysql-pvc.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: mysql-persistente
    namespace: lab7
    labels:
      app: mysql
  spec:
    containers:
      - name: mysql
        image: mysql:8.0.42
        ports:
          - containerPort: 3306
        env:
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
          - name: mysql-data
            mountPath: /var/lib/mysql
        readinessProbe:
          exec:
            command:
              - sh
              - -c
              - mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 12
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
    volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: pvc-lab7-static
  ```

- {% include step_label.html %} Valida el manifiesto antes de crear el Pod, comprobando la referencia al Secret y al PVC sin modificar todavía el clúster.

  ```bash
  kubectl apply --dry-run=client -f mysql-pvc.yaml
  ```

**Salida esperada:**

```text
pod/mysql-persistente created (dry run)
```

- {% include step_label.html %} Aplica el Pod y espera hasta que la `readinessProbe` confirme que MySQL realmente acepta conexiones, no solo que el proceso arrancó.

  ```bash
  kubectl apply -f mysql-pvc.yaml

  kubectl wait --for=condition=Ready pod/mysql-persistente -n lab7 --timeout=180s
  ```

**Salida esperada:**

```text
pod/mysql-persistente created
pod/mysql-persistente condition met
```

- {% include step_label.html %} Comprueba en qué nodo fue programado el Pod y confirma que respeta la afinidad del volumen.

  ```bash
  kubectl get pod mysql-persistente \
    -n lab7 \
    -o wide
  ```

**Salida esperada aproximada:**

```text
NAME                 READY   STATUS    IP           NODE
mysql-persistente    1/1     Running   10.244.x.x   minikube
```

El Pod debe ejecutarse sobre `minikube` porque el PV está limitado mediante `nodeAffinity` a ese nodo.

### Tarea 2.3. Crear datos persistentes

- {% include step_label.html %} Crea una tabla e inserta tres registros para disponer de información verificable antes de eliminar el Pod.

  ```bash
  kubectl exec mysql-persistente \
    -n lab7 -- \
    mysql \
    -uroot \
    -p'K8s-lab7-2026!' \
    testdb \
    -e "
      CREATE TABLE IF NOT EXISTS registros (
        id INT AUTO_INCREMENT PRIMARY KEY,
        mensaje VARCHAR(100)
      );
      INSERT INTO registros (mensaje) VALUES
        ('Registro persistente 1'),
        ('Registro persistente 2'),
        ('Registro persistente 3');
      SELECT * FROM registros;
    "
  ```

**Salida esperada aproximada:**

```text
id  mensaje
1   Registro persistente 1
2   Registro persistente 2
3   Registro persistente 3
```

Puede aparecer una advertencia de MySQL por utilizar la contraseña desde la línea de comandos; para este laboratorio es esperada.

- {% include step_label.html %} Obtén el número de registros y confirma que la base de datos contiene exactamente tres filas.

  ```bash
  kubectl exec mysql-persistente \
    -n lab7 -- \
    mysql \
    -uroot \
    -p'K8s-lab7-2026!' \
    testdb \
    -sNe 'SELECT COUNT(*) FROM registros;'
  ```

**Salida esperada:**

```text
3
```

### Tarea 2.4. Eliminar y recrear el Pod

- {% include step_label.html %} Elimina únicamente el Pod y comprueba que el PVC continúa en estado `Bound`.

  ```bash
  kubectl delete pod mysql-persistente -n lab7

  kubectl get pvc pvc-lab7-static -n lab7
  ```

**Salida esperada aproximada:**

```text
pod "mysql-persistente" deleted

NAME               STATUS   VOLUME
pvc-lab7-static   Bound    pv-lab7-static
```

- {% include step_label.html %} Recrea el Pod utilizando exactamente el mismo manifiesto y espera nuevamente hasta que esté listo.

  ```bash
  kubectl apply -f mysql-pvc.yaml

  kubectl wait --for=condition=Ready pod/mysql-persistente -n lab7 --timeout=180s
  ```

**Salida esperada:**

```text
pod/mysql-persistente created
pod/mysql-persistente condition met
```

- {% include step_label.html %} Consulta la tabla después de recrear el Pod para demostrar que el contenido persistió fuera del ciclo de vida del contenedor.

  ```bash
  kubectl exec mysql-persistente \
    -n lab7 -- \
    mysql \
    -uroot \
    -p'K8s-lab7-2026!' \
    testdb \
    -e 'SELECT * FROM registros;'
  ```

**Salida esperada aproximada:**

```text
id  mensaje
1   Registro persistente 1
2   Registro persistente 2
3   Registro persistente 3
```

Los tres registros deben conservarse porque `/var/lib/mysql` continúa respaldado por el mismo PV/PVC.

> **Concepto clave:** El PVC no pertenece al ciclo de vida del Pod. El Pod puede eliminarse y recrearse mientras el volumen continúa conservando los datos almacenados.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## ⚙️ Tarea 3. Utilizar aprovisionamiento dinámico

En esta tarea crearás un PVC sin definir manualmente un PV y dejarás que la StorageClass predeterminada del clúster aprovisione el almacenamiento.

### Tarea 3.1. Identificar la StorageClass predeterminada

- {% include step_label.html %} Ejecuta el comando siguiente y localiza la StorageClass marcada como `(default)`.

  ```bash
  kubectl get storageclass
  ```

- {% include step_label.html %} Guarda automáticamente el nombre de la StorageClass predeterminada para utilizarlo en las comprobaciones posteriores.

  ```bash
  DEFAULT_SC=$(kubectl get storageclass \
    -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}')

  echo "StorageClass predeterminada: $DEFAULT_SC"
  ```

**Salida esperada aproximada:**

```text
StorageClass predeterminada: standard
```

El nombre puede ser diferente; la variable no debe quedar vacía.

> **IMPORTANTE:** Si la variable queda vacía, revisa `kubectl get storageclass` y confirma que existe una clase predeterminada antes de continuar.
{: .lab-note .important .compact}

### Tarea 3.2. Crear un PVC dinámico

- {% include step_label.html %} Crea `pvc-dynamic.yaml` sin especificar `storageClassName` ni `volumeName`, permitiendo que Kubernetes utilice la clase predeterminada.

  ```bash
  touch pvc-dynamic.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: pvc-lab7-dynamic
    namespace: lab7
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 200Mi
  ```

- {% include step_label.html %} Valida y aplica el PVC sin especificar `storageClassName`, permitiendo que Kubernetes seleccione la StorageClass predeterminada.

  ```bash
  kubectl apply --dry-run=client -f pvc-dynamic.yaml
  kubectl apply -f pvc-dynamic.yaml
  ```

**Salida esperada:**

```text
persistentvolumeclaim/pvc-lab7-dynamic created (dry run)
persistentvolumeclaim/pvc-lab7-dynamic created
```

- {% include step_label.html %} Consulta el estado del PVC y la modalidad de binding de la StorageClass para interpretar correctamente `Bound` o `Pending`.

  ```bash
  kubectl get pvc pvc-lab7-dynamic -n lab7

  kubectl get storageclass "$DEFAULT_SC" -o jsonpath='{.volumeBindingMode}{"\n"}'
  ```

**Salida esperada aproximada:**

```text
NAME                  STATUS   VOLUME
pvc-lab7-dynamic     Bound    pvc-...
Immediate
```

Si la StorageClass muestra `WaitForFirstConsumer`, es válido que el PVC continúe `Pending` hasta crear `nginx-dynamic` en la Tarea 3.3.

- {% include step_label.html %} Consulta el nombre del PV creado por el provisioner y revisa la StorageClass utilizada.

  ```bash
  DYNAMIC_PV=$(kubectl get pvc pvc-lab7-dynamic \
    -n lab7 \
    -o jsonpath='{.spec.volumeName}')

  echo "PV dinámico: $DYNAMIC_PV"

  kubectl get pv "$DYNAMIC_PV"
  ```

### Tarea 3.3. Consumir el PVC dinámico

- {% include step_label.html %} Crea el archivo `pod-dynamic.yaml` para montar el PVC dinámico dentro de un Pod NGINX.

  ```bash
  touch pod-dynamic.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: nginx-dynamic
    namespace: lab7
  spec:
    containers:
      - name: nginx
        image: nginx:1.27-alpine
        volumeMounts:
          - name: web-data
            mountPath: /usr/share/nginx/html
    volumes:
      - name: web-data
        persistentVolumeClaim:
          claimName: pvc-lab7-dynamic
  ```

- {% include step_label.html %} Aplica el Pod, espera a que esté listo y escribe un archivo dentro del volumen aprovisionado dinámicamente.

  ```bash
  kubectl apply -f pod-dynamic.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/nginx-dynamic \
    -n lab7 \
    --timeout=120s

  kubectl exec nginx-dynamic \
    -n lab7 -- \
    sh -c 'echo "<h1>PVC dinamico operativo</h1>" > /usr/share/nginx/html/index.html'
  ```

- {% include step_label.html %} Lee nuevamente el archivo para confirmar que el volumen se encuentra montado y disponible.

  ```bash
  kubectl exec nginx-dynamic -n lab7 -- sh -c 'cat /usr/share/nginx/html/index.html'
  ```

**Salida esperada:**

```html
<h1>PVC dinamico operativo</h1>
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🧪 Tarea 4. Comparar emptyDir y PVC

En esta tarea crearás un volumen efímero y demostrarás que sus datos desaparecen cuando el Pod deja de existir.

### Tarea 4.1. Crear el Pod con emptyDir

- {% include step_label.html %} Crea el archivo `pod-emptydir.yaml` con un contenedor que permanezca en ejecución sin generar automáticamente archivos dentro del volumen.

  ```bash
  touch pod-emptydir.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: emptydir-demo
    namespace: lab7
  spec:
    containers:
      - name: app
        image: busybox:1.36
        command:
          - sh
          - -c
          - sleep 3600
        volumeMounts:
          - name: temp-data
            mountPath: /datos
    volumes:
      - name: temp-data
        emptyDir: {}
  ```

- {% include step_label.html %} Aplica el Pod y espera hasta que se encuentre listo antes de escribir datos.

  ```bash
  kubectl apply --dry-run=client -f pod-emptydir.yaml
  kubectl apply -f pod-emptydir.yaml

  kubectl wait --for=condition=Ready pod/emptydir-demo -n lab7 --timeout=60s
  ```

**Salida esperada:**

```text
pod/emptydir-demo created (dry run)
pod/emptydir-demo created
pod/emptydir-demo condition met
```

### Tarea 4.2. Escribir y perder el dato

- {% include step_label.html %} Crea manualmente un archivo dentro de `emptyDir` y comprueba que existe durante la vida actual del Pod.

  ```bash
  kubectl exec emptydir-demo \
    -n lab7 -- \
    sh -c 'echo "Dato temporal lab7" > /datos/temporal.txt'

  kubectl exec emptydir-demo -n lab7 -- sh -c 'cat /datos/temporal.txt'
  ```

**Salida esperada:**

```text
Dato temporal lab7
```

- {% include step_label.html %} Elimina y recrea el Pod utilizando el mismo manifiesto.

  ```bash
  kubectl delete pod emptydir-demo -n lab7

  kubectl apply -f pod-emptydir.yaml

  kubectl wait --for=condition=Ready pod/emptydir-demo -n lab7 --timeout=60s
  ```

**Salida esperada:**

```text
pod "emptydir-demo" deleted
pod/emptydir-demo created
pod/emptydir-demo condition met
```

- {% include step_label.html %} Intenta leer el archivo anterior y confirma que ya no existe.

  ```bash
  kubectl exec emptydir-demo \
    -n lab7 -- \
    sh -c 'test -f /datos/temporal.txt && cat /datos/temporal.txt || echo "Archivo no encontrado"'
  ```

**Salida esperada:**

```text
Archivo no encontrado
```

> **Concepto clave:** `emptyDir` vive mientras existe el Pod. Un contenedor puede reiniciarse y conservar el volumen dentro del mismo Pod, pero al eliminar el Pod se elimina también `emptyDir`.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Validar almacenamiento persistente

En esta tarea comprobarás los estados esenciales del almacenamiento utilizado durante la práctica.

### Tarea 5.1. Revisar PV y PVC

- {% include step_label.html %} Consulta los PV y PVC creados para identificar claramente almacenamiento estático y dinámico.

  ```bash
  kubectl get pv
  kubectl get pvc -n lab7
  ```

**Salida esperada aproximada:**

```text
PV:
pv-lab7-static   1Gi    RWO   Retain   Bound   lab7/pvc-lab7-static
pvc-...           ...    RWO   Delete   Bound   lab7/pvc-lab7-dynamic

PVC:
pvc-lab7-static    Bound   pv-lab7-static
pvc-lab7-dynamic   Bound   pvc-...
```

El nombre del PV dinámico es generado por Kubernetes y será diferente en cada ejecución.

### Tarea 5.2. Ejecutar validación final

- {% include step_label.html %} Ejecuta el bloque siguiente para validar binding estático, ubicación de MySQL, persistencia, aprovisionamiento dinámico y pérdida de datos de `emptyDir`.

  ```bash
  echo "=== Validacion final de la Practica 7 ==="

  STATIC_PVC=$(kubectl get pvc pvc-lab7-static \
    -n lab7 \
    -o jsonpath='{.status.phase}')

  [ "$STATIC_PVC" = "Bound" ] \
    && echo "✅ PVC estatico Bound" \
    || echo "❌ PVC estatico: $STATIC_PVC"

  STATIC_PV=$(kubectl get pv pv-lab7-static \
    -o jsonpath='{.status.phase}')

  [ "$STATIC_PV" = "Bound" ] \
    && echo "✅ PV estatico Bound" \
    || echo "❌ PV estatico: $STATIC_PV"

  MYSQL_NODE=$(kubectl get pod mysql-persistente \
    -n lab7 \
    -o jsonpath='{.spec.nodeName}')

  [ "$MYSQL_NODE" = "minikube" ] \
    && echo "✅ MySQL programado en minikube" \
    || echo "❌ MySQL programado en: $MYSQL_NODE"

  MYSQL_COUNT=$(kubectl exec mysql-persistente \
    -n lab7 -- \
    mysql \
    -uroot \
    -p'K8s-lab7-2026!' \
    testdb \
    -sNe 'SELECT COUNT(*) FROM registros;' \
    2>/dev/null)

  [ "$MYSQL_COUNT" = "3" ] \
    && echo "✅ Datos MySQL persistentes: 3 registros" \
    || echo "❌ Registros encontrados: $MYSQL_COUNT"

  DYNAMIC_PVC=$(kubectl get pvc pvc-lab7-dynamic \
    -n lab7 \
    -o jsonpath='{.status.phase}')

  [ "$DYNAMIC_PVC" = "Bound" ] \
    && echo "✅ PVC dinamico Bound" \
    || echo "❌ PVC dinamico: $DYNAMIC_PVC"

  DYNAMIC_FILE=$(kubectl exec nginx-dynamic \
    -n lab7 -- \
    sh -c 'cat /usr/share/nginx/html/index.html' \
    2>/dev/null)

  echo "$DYNAMIC_FILE" | grep -q "PVC dinamico operativo" \
    && echo "✅ PVC dinamico montado y con datos" \
    || echo "❌ No se pudo validar el contenido del PVC dinamico"

  EMPTY_FILE=$(kubectl exec emptydir-demo \
    -n lab7 -- \
    sh -c 'test -f /datos/temporal.txt && echo existe || echo ausente')

  [ "$EMPTY_FILE" = "ausente" ] \
    && echo "✅ emptyDir perdio el dato al recrear el Pod" \
    || echo "❌ El archivo temporal sigue presente"

  echo "=== Fin de validacion ==="
  ```

**Salida esperada:**

```text
=== Validacion final de la Practica 7 ===
✅ PVC estatico Bound
✅ PV estatico Bound
✅ MySQL programado en minikube
✅ Datos MySQL persistentes: 3 registros
✅ PVC dinamico Bound
✅ PVC dinamico montado y con datos
✅ emptyDir perdio el dato al recrear el Pod
=== Fin de validacion ===
```

> **IMPORTANTE:** No elimines el clúster Minikube. Puedes conservar los recursos de `lab7` hasta terminar la revisión de esta práctica.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🛠️ Resolución de problemas

### Problema 1. El PVC estático permanece Pending

**Síntoma:** `pvc-lab7-static` no alcanza estado `Bound`.

**Causa probable:** El PV no existe, está ocupado, no coincide con el nombre solicitado o su capacidad y access mode no satisfacen el PVC.

**Solución:**

```bash
kubectl get pv pv-lab7-static
kubectl describe pv pv-lab7-static
kubectl describe pvc pvc-lab7-static -n lab7
```

Comprueba que `volumeName` sea `pv-lab7-static`, que el PV esté disponible y que `storageClassName` sea vacío en ambos recursos.

---

### Problema 2. mysql-persistente permanece Pending

**Síntoma:** El PVC está `Bound`, pero el Pod MySQL no se programa.

**Causa probable:** El PV está limitado mediante nodeAffinity al nodo `minikube` y ese nodo no está disponible o no dispone de recursos suficientes.

**Solución:**

```bash
kubectl describe pod mysql-persistente -n lab7
kubectl get node minikube
kubectl describe node minikube
```

Confirma que el nodo `minikube` esté `Ready` antes de modificar el volumen.

---

### Problema 3. MySQL entra en CrashLoopBackOff

**Síntoma:** El Pod se programa pero el contenedor reinicia repetidamente.

**Causa probable:** MySQL encuentra datos incompatibles en el volumen o existe un problema con las variables obtenidas desde el Secret.

**Solución:**

```bash
kubectl logs mysql-persistente -n lab7
kubectl describe pod mysql-persistente -n lab7
kubectl get secret mysql-secret -n lab7
```

No elimines el contenido del volumen hasta identificar la causa en los logs.

---

### Problema 4. El PVC dinámico permanece Pending

**Síntoma:** `pvc-lab7-dynamic` no obtiene un PV.

**Causa probable:** No existe una StorageClass predeterminada o el provisioner asociado no está disponible.

**Solución:**

```bash
kubectl get storageclass
minikube addons list | grep storage
kubectl describe pvc pvc-lab7-dynamic -n lab7
```

Si Minikube no tiene habilitado el provisioner predeterminado, revisa los addons de almacenamiento disponibles antes de cambiar el manifiesto.

---

### Problema 5. Los datos de MySQL desaparecieron después de recrear el Pod

**Síntoma:** La tabla o registros creados anteriormente ya no existen.

**Causa probable:** El Pod se recreó utilizando otro PVC, el volumen fue eliminado o el PV estático fue modificado.

**Solución:**

```bash
kubectl get pod mysql-persistente \
  -n lab7 \
  -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}{"\n"}'

kubectl get pvc pvc-lab7-static -n lab7
kubectl get pv pv-lab7-static
```

El Pod debe continuar utilizando `pvc-lab7-static`, y el PVC debe permanecer asociado con `pv-lab7-static`.


---

### Problema 6. Git Bash transforma rutas Linux dentro del contenedor

**Síntoma:** Un comando que intenta acceder a `/usr/share/nginx/html` o `/datos` termina utilizando una ruta similar a `C:/Program Files/Git/...`.

**Causa probable:** Git Bash/MSYS2 convierte automáticamente argumentos que comienzan con `/` antes de entregarlos a `kubectl`.

**Solución:**

Ejecuta la operación dentro de `sh -c`.

```bash
kubectl exec nginx-dynamic \
  -n lab7 -- \
  sh -c 'cat /usr/share/nginx/html/index.html'
```

El mismo patrón debe utilizarse para rutas como `/datos/temporal.txt`.

---

### Problema 7. MySQL está Running pero todavía no acepta consultas

**Síntoma:** El Pod aparece `Running`, pero `mysql` devuelve un error de conexión durante los primeros segundos.

**Causa probable:** El proceso principal ya inició, pero MySQL todavía está inicializando el directorio de datos o las tablas internas.

**Solución:**

La práctica utiliza una `readinessProbe` con `mysqladmin ping`. Espera a que Kubernetes marque el Pod como `Ready`.

```bash
kubectl wait \
  --for=condition=Ready \
  pod/mysql-persistente \
  -n lab7 \
  --timeout=180s
```

Si no alcanza `Ready`, revisa:

```bash
kubectl logs mysql-persistente -n lab7
kubectl describe pod mysql-persistente -n lab7
```

---

### Problema 8. El PVC dinámico está Pending antes de crear nginx-dynamic

**Síntoma:** El PVC dinámico no obtiene inmediatamente un PV aunque exista una StorageClass predeterminada.

**Causa probable:** La StorageClass utiliza `WaitForFirstConsumer`, por lo que el provisioner espera a conocer dónde se programará el primer Pod consumidor.

**Solución:**

Comprueba la modalidad:

```bash
kubectl get storageclass "$DEFAULT_SC" \
  -o jsonpath='{.volumeBindingMode}{"\n"}'
```

Si devuelve:

```text
WaitForFirstConsumer
```

continúa con la creación de `nginx-dynamic`. Después verifica nuevamente el PVC; debe pasar a `Bound`.
