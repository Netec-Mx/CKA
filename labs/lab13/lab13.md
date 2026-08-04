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
  - Esta práctica utiliza el namespace lab13.
  - El PV estático usa hostPath únicamente con fines de laboratorio y queda asociado al nodo minikube mediante nodeAffinity.
  - En producción se utilizan normalmente soluciones CSI y almacenamiento proporcionado por infraestructura externa.
  - No elimines el clúster Minikube durante la práctica.
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

En esta práctica crearás recursos de almacenamiento con alcance de clúster y recursos namespaced dentro de `lab13`.

### 🗂️ Preparar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que el motor continúa activo antes de verificar los nodos y el almacenamiento disponible.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio correspondiente al laboratorio.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab13
  cd /c/LABS/kubernetes/lab13
  ```

- {% include step_label.html %} Comprueba que Minikube continúa activo y que los nodos del clúster permanecen en estado `Ready`.

  ```bash
  minikube status
  kubectl get nodes
  ```

- {% include step_label.html %} Crea el namespace `lab13` y establécelo temporalmente como namespace predeterminado del contexto actual.

  ```bash
  kubectl create namespace lab13
  kubectl config set-context --current --namespace=lab13
  ```

- {% include step_label.html %} Consulta las StorageClasses existentes para identificar la opción predeterminada disponible en Minikube.

  ```bash
  kubectl get storageclass
  ```

> **IMPORTANTE:** No asumas el nombre de la StorageClass predeterminada hasta revisar esta salida. En instalaciones habituales de Minikube aparece `standard`, pero debes utilizar el valor real de tu clúster.
{: .lab-note .important .compact}

---

## 💾 Tarea 1. Crear un PV estático y vincularlo con un PVC

En esta tarea crearás almacenamiento estático mediante `hostPath` y limitarás su uso al nodo `minikube` para evitar que el volumen apunte a directorios diferentes en un clúster multinodo.

### Tarea 1.1. Preparar el directorio del nodo

- {% include step_label.html %} Crea el directorio que respaldará el PV dentro del nodo principal de Minikube.

  ```bash
  minikube ssh -- \
    "sudo mkdir -p /mnt/data/lab13-pv && sudo chmod 777 /mnt/data/lab13-pv"
  ```

- {% include step_label.html %} Comprueba que el directorio existe en el nodo antes de definir el PersistentVolume.

  ```bash
  minikube ssh -- \
    "ls -ld /mnt/data/lab13-pv"
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
    name: pv-lab13-static
    labels:
      lab: lab13
      type: static
  spec:
    capacity:
      storage: 1Gi
    accessModes:
      - ReadWriteOnce
    persistentVolumeReclaimPolicy: Retain
    storageClassName: ""
    hostPath:
      path: /mnt/data/lab13-pv
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
  kubectl apply -f pv-static.yaml
  ```

- {% include step_label.html %} Comprueba que el PV se encuentra `Available` y todavía no está asociado con ningún PVC.

  ```bash
  kubectl get pv pv-lab13-static
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
    name: pvc-lab13-static
    namespace: lab13
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 500Mi
    storageClassName: ""
    volumeName: pv-lab13-static
  ```

- {% include step_label.html %} Aplica el PVC y comprueba que tanto el PV como el PVC cambian a estado `Bound`.

  ```bash
  kubectl apply -f pvc-static.yaml

  kubectl get pvc pvc-lab13-static -n lab13
  kubectl get pv pv-lab13-static
  ```

**Salida esperada aproximada:**

```text
NAME               STATUS   VOLUME            CAPACITY   ACCESS MODES
pvc-lab13-static   Bound    pv-lab13-static   1Gi        RWO
```

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
  kubectl create secret generic mysql-secret \
    --from-literal=MYSQL_ROOT_PASSWORD='K8s-Lab13-2026!' \
    --from-literal=MYSQL_DATABASE=testdb \
    -n lab13
  ```

### Tarea 2.2. Crear el Pod MySQL

- {% include step_label.html %} Crea el archivo `mysql-pvc.yaml` para montar `pvc-lab13-static` en la ruta de datos utilizada por MySQL.

  ```bash
  touch mysql-pvc.yaml
  ```

- {% include step_label.html %} Agrega el manifiesto siguiente.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: mysql-persistente
    namespace: lab13
    labels:
      app: mysql
  spec:
    containers:
      - name: mysql
        image: mysql:8.0
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
          claimName: pvc-lab13-static
  ```

- {% include step_label.html %} Aplica el Pod y espera hasta que Kubernetes indique que el contenedor está preparado para recibir tráfico.

  ```bash
  kubectl apply -f mysql-pvc.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/mysql-persistente \
    -n lab13 \
    --timeout=180s
  ```

- {% include step_label.html %} Comprueba en qué nodo fue programado el Pod y confirma que respeta la afinidad del volumen.

  ```bash
  kubectl get pod mysql-persistente \
    -n lab13 \
    -o wide
  ```

**Resultado esperado:**

El Pod debe ejecutarse sobre el nodo `minikube`.

### Tarea 2.3. Crear datos persistentes

- {% include step_label.html %} Crea una tabla e inserta tres registros para disponer de información verificable antes de eliminar el Pod.

  ```bash
  kubectl exec mysql-persistente \
    -n lab13 -- \
    mysql \
    -uroot \
    -p'K8s-Lab13-2026!' \
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

- {% include step_label.html %} Obtén el número de registros y confirma que la base de datos contiene exactamente tres filas.

  ```bash
  kubectl exec mysql-persistente \
    -n lab13 -- \
    mysql \
    -uroot \
    -p'K8s-Lab13-2026!' \
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
  kubectl delete pod mysql-persistente -n lab13

  kubectl get pvc pvc-lab13-static -n lab13
  ```

- {% include step_label.html %} Recrea el Pod utilizando exactamente el mismo manifiesto y espera nuevamente hasta que esté listo.

  ```bash
  kubectl apply -f mysql-pvc.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/mysql-persistente \
    -n lab13 \
    --timeout=180s
  ```

- {% include step_label.html %} Consulta la tabla después de recrear el Pod para demostrar que el contenido persistió fuera del ciclo de vida del contenedor.

  ```bash
  kubectl exec mysql-persistente \
    -n lab13 -- \
    mysql \
    -uroot \
    -p'K8s-Lab13-2026!' \
    testdb \
    -e 'SELECT * FROM registros;'
  ```

**Resultado esperado:**

Los tres registros creados anteriormente deben continuar disponibles.

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
    name: pvc-lab13-dynamic
    namespace: lab13
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 200Mi
  ```

- {% include step_label.html %} Aplica el PVC y observa el nombre del PV generado automáticamente.

  ```bash
  kubectl apply -f pvc-dynamic.yaml

  kubectl get pvc pvc-lab13-dynamic \
    -n lab13 \
    -w
  ```

Presiona `Ctrl+C` cuando el PVC aparezca `Bound`.

- {% include step_label.html %} Consulta el nombre del PV creado por el provisioner y revisa la StorageClass utilizada.

  ```bash
  DYNAMIC_PV=$(kubectl get pvc pvc-lab13-dynamic \
    -n lab13 \
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
    namespace: lab13
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
          claimName: pvc-lab13-dynamic
  ```

- {% include step_label.html %} Aplica el Pod, espera a que esté listo y escribe un archivo dentro del volumen aprovisionado dinámicamente.

  ```bash
  kubectl apply -f pod-dynamic.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/nginx-dynamic \
    -n lab13 \
    --timeout=120s

  kubectl exec nginx-dynamic \
    -n lab13 -- \
    sh -c 'echo "<h1>PVC dinamico operativo</h1>" > /usr/share/nginx/html/index.html'
  ```

- {% include step_label.html %} Lee nuevamente el archivo para confirmar que el volumen se encuentra montado y disponible.

  ```bash
  kubectl exec nginx-dynamic \
    -n lab13 -- \
    cat /usr/share/nginx/html/index.html
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
    namespace: lab13
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
  kubectl apply -f pod-emptydir.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/emptydir-demo \
    -n lab13 \
    --timeout=60s
  ```

### Tarea 4.2. Escribir y perder el dato

- {% include step_label.html %} Crea manualmente un archivo dentro de `emptyDir` y comprueba que existe durante la vida actual del Pod.

  ```bash
  kubectl exec emptydir-demo \
    -n lab13 -- \
    sh -c 'echo "Dato temporal Lab13" > /datos/temporal.txt'

  kubectl exec emptydir-demo \
    -n lab13 -- \
    cat /datos/temporal.txt
  ```

- {% include step_label.html %} Elimina y recrea el Pod utilizando el mismo manifiesto.

  ```bash
  kubectl delete pod emptydir-demo -n lab13

  kubectl apply -f pod-emptydir.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/emptydir-demo \
    -n lab13 \
    --timeout=60s
  ```

- {% include step_label.html %} Intenta leer el archivo anterior y confirma que ya no existe.

  ```bash
  kubectl exec emptydir-demo \
    -n lab13 -- \
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
  kubectl get pvc -n lab13
  ```

### Tarea 5.2. Ejecutar validación final

- {% include step_label.html %} Ejecuta el bloque siguiente para confirmar binding, persistencia de MySQL y aprovisionamiento dinámico.

  ```bash
  echo "=== Validacion final de la Practica 7 ==="

  STATIC_PVC=$(kubectl get pvc pvc-lab13-static \
    -n lab13 \
    -o jsonpath='{.status.phase}')

  [ "$STATIC_PVC" = "Bound" ] \
    && echo "✅ PVC estatico Bound" \
    || echo "❌ PVC estatico: $STATIC_PVC"

  STATIC_PV=$(kubectl get pv pv-lab13-static \
    -o jsonpath='{.status.phase}')

  [ "$STATIC_PV" = "Bound" ] \
    && echo "✅ PV estatico Bound" \
    || echo "❌ PV estatico: $STATIC_PV"

  MYSQL_COUNT=$(kubectl exec mysql-persistente \
    -n lab13 -- \
    mysql \
    -uroot \
    -p'K8s-Lab13-2026!' \
    testdb \
    -sNe 'SELECT COUNT(*) FROM registros;' \
    2>/dev/null)

  [ "$MYSQL_COUNT" = "3" ] \
    && echo "✅ Datos MySQL persistentes: 3 registros" \
    || echo "❌ Registros encontrados: $MYSQL_COUNT"

  DYNAMIC_PVC=$(kubectl get pvc pvc-lab13-dynamic \
    -n lab13 \
    -o jsonpath='{.status.phase}')

  [ "$DYNAMIC_PVC" = "Bound" ] \
    && echo "✅ PVC dinamico Bound" \
    || echo "❌ PVC dinamico: $DYNAMIC_PVC"

  EMPTY_FILE=$(kubectl exec emptydir-demo \
    -n lab13 -- \
    sh -c 'test -f /datos/temporal.txt && echo existe || echo ausente')

  [ "$EMPTY_FILE" = "ausente" ] \
    && echo "✅ emptyDir perdio el dato al recrear el Pod" \
    || echo "❌ El archivo temporal sigue presente"

  echo "=== Fin de validacion ==="
  ```

**Salida esperada aproximada:**

```text
=== Validacion final de la Practica 7 ===
✅ PVC estatico Bound
✅ PV estatico Bound
✅ Datos MySQL persistentes: 3 registros
✅ PVC dinamico Bound
✅ emptyDir perdio el dato al recrear el Pod
=== Fin de validacion ===
```

> **IMPORTANTE:** No elimines el clúster Minikube. Puedes conservar los recursos de `lab13` hasta terminar la revisión de esta práctica.
{: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🛠️ Resolución de problemas

### Problema 1. El PVC estático permanece Pending

**Síntoma:** `pvc-lab13-static` no alcanza estado `Bound`.

**Causa probable:** El PV no existe, está ocupado, no coincide con el nombre solicitado o su capacidad y access mode no satisfacen el PVC.

**Solución:**

```bash
kubectl get pv pv-lab13-static
kubectl describe pv pv-lab13-static
kubectl describe pvc pvc-lab13-static -n lab13
```

Comprueba que `volumeName` sea `pv-lab13-static`, que el PV esté disponible y que `storageClassName` sea vacío en ambos recursos.

---

### Problema 2. mysql-persistente permanece Pending

**Síntoma:** El PVC está `Bound`, pero el Pod MySQL no se programa.

**Causa probable:** El PV está limitado mediante nodeAffinity al nodo `minikube` y ese nodo no está disponible o no dispone de recursos suficientes.

**Solución:**

```bash
kubectl describe pod mysql-persistente -n lab13
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
kubectl logs mysql-persistente -n lab13
kubectl describe pod mysql-persistente -n lab13
kubectl get secret mysql-secret -n lab13
```

No elimines el contenido del volumen hasta identificar la causa en los logs.

---

### Problema 4. El PVC dinámico permanece Pending

**Síntoma:** `pvc-lab13-dynamic` no obtiene un PV.

**Causa probable:** No existe una StorageClass predeterminada o el provisioner asociado no está disponible.

**Solución:**

```bash
kubectl get storageclass
minikube addons list | grep storage
kubectl describe pvc pvc-lab13-dynamic -n lab13
```

Si Minikube no tiene habilitado el provisioner predeterminado, revisa los addons de almacenamiento disponibles antes de cambiar el manifiesto.

---

### Problema 5. Los datos de MySQL desaparecieron después de recrear el Pod

**Síntoma:** La tabla o registros creados anteriormente ya no existen.

**Causa probable:** El Pod se recreó utilizando otro PVC, el volumen fue eliminado o el PV estático fue modificado.

**Solución:**

```bash
kubectl get pod mysql-persistente \
  -n lab13 \
  -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}{"\n"}'

kubectl get pvc pvc-lab13-static -n lab13
kubectl get pv pv-lab13-static
```

El Pod debe continuar utilizando `pvc-lab13-static`, y el PVC debe permanecer asociado con `pv-lab13-static`.
