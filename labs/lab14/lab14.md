---
layout: lab
title: "Práctica 8: Diagnóstico y resolución de fallos en Pods, Services y DNS"
permalink: /lab14/lab14/
images_base: /labs/lab14/img
duration: "80 minutos"
objective:
  - Aplicar una metodología sistemática de troubleshooting sobre recursos Kubernetes.
  - Diagnosticar Pods con ImagePullBackOff, CrashLoopBackOff y Pending.
  - Identificar fallos de Services provocados por selectors, targetPort y probes incorrectas.
  - Validar y corregir problemas de resolución DNS dentro del clúster.
  - Utilizar kubectl describe, logs, events, exec y Pods temporales de diagnóstico.
prerequisites:
  - Haber completado las prácticas anteriores de Pods, Deployments, Services y DNS.
  - Tener Docker Desktop, Minikube y kubectl disponibles.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Conservar el clúster Minikube de tres nodos utilizado en prácticas anteriores.
  - Comprender estados como Pending, Running, ImagePullBackOff y CrashLoopBackOff.
introduction:
  - En esta práctica recibirás ocho fallos intencionales distribuidos entre Pods, Services y DNS. No se trata únicamente de ejecutar correcciones: deberás observar síntomas, identificar evidencia en Events, logs y configuración, determinar la causa raíz y validar que la solución realmente restableció el comportamiento esperado.
slug: lab14
lab_number: 14
final_result: >
  Al finalizar la práctica habrás diagnosticado y corregido ocho escenarios de fallo utilizando un flujo sistemático basado en observación, descripción, análisis, corrección y validación funcional.
notes:
  - Todos los escenarios se despliegan dentro del namespace troubleshooting-lab.
  - Los errores iniciales son intencionales y forman parte del ejercicio.
  - Evita corregir recursos antes de revisar Events, logs o configuración efectiva.
  - No modifiques CoreDNS; los escenarios DNS se resuelven desde la configuración de los Pods.
references:
  - text: Debugging Pods
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
  - text: Debugging Services
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
  - text: Debugging DNS Resolution
    url: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
  - text: kubectl describe
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/
prev: /lab13/lab13/
next: /lab15/lab15/
---

---
<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 📁 Preparación del laboratorio

Crearás todos los escenarios dentro de un namespace dedicado para evitar interferencias con prácticas anteriores.

### 🗂️ Preparar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que Minikube continúa activo antes de desplegar escenarios defectuosos.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y crea el directorio del laboratorio.

  ```bash
  mkdir -p /c/LABS/kubernetes/lab14
  cd /c/LABS/kubernetes/lab14
  ```

- {% include step_label.html %} Comprueba que los nodos continúan disponibles y que CoreDNS se encuentra operativo antes de comenzar.

  ```bash
  kubectl get nodes
  kubectl get pods -n kube-system -l k8s-app=kube-dns
  ```

- {% include step_label.html %} Crea el namespace dedicado al troubleshooting y configúralo como namespace predeterminado del contexto.

  ```bash
  kubectl create namespace troubleshooting-lab
  kubectl config set-context --current --namespace=troubleshooting-lab
  ```

### 🧰 Crear los escenarios de fallo

- {% include step_label.html %} Crea el archivo `setup-failures.yaml`, que contendrá los ocho escenarios intencionalmente defectuosos.

  ```bash
  touch setup-failures.yaml
  ```

- {% include step_label.html %} Agrega el contenido siguiente.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-a1-imagepull
    namespace: troubleshooting-lab
    labels:
      scenario: a1
  spec:
    containers:
      - name: app
        image: nginx:this-tag-does-not-exist-99999
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-a2-crashloop
    namespace: troubleshooting-lab
    labels:
      scenario: a2
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        command: ["/bin/sh", "-c", "comando-inexistente --flag"]
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-a3-pending
    namespace: troubleshooting-lab
    labels:
      scenario: a3
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          requests:
            cpu: "999"
            memory: "999Gi"
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-b1-backend
    namespace: troubleshooting-lab
    labels:
      app: backend-real
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        ports:
          - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: svc-b1-wrong-selector
    namespace: troubleshooting-lab
  spec:
    selector:
      app: backend-typo
    ports:
      - port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-b2-webserver
    namespace: troubleshooting-lab
    labels:
      app: webserver-b2
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        ports:
          - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: svc-b2-wrong-port
    namespace: troubleshooting-lab
  spec:
    selector:
      app: webserver-b2
    ports:
      - port: 80
        targetPort: 9999
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: deploy-b3-liveness
    namespace: troubleshooting-lab
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: app-b3
    template:
      metadata:
        labels:
          app: app-b3
      spec:
        containers:
          - name: app
            image: nginx:1.27-alpine
            ports:
              - containerPort: 80
            livenessProbe:
              httpGet:
                path: /healthz-inexistente
                port: 80
              initialDelaySeconds: 5
              periodSeconds: 5
              failureThreshold: 2
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: svc-b3-liveness
    namespace: troubleshooting-lab
  spec:
    selector:
      app: app-b3
    ports:
      - port: 80
        targetPort: 80
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-c1-dns-policy
    namespace: troubleshooting-lab
    labels:
      scenario: c1
  spec:
    dnsPolicy: None
    dnsConfig:
      nameservers:
        - 1.2.3.4
    containers:
      - name: debug
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
  ---
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-c2-dns-debug
    namespace: troubleshooting-lab
    labels:
      scenario: c2
  spec:
    containers:
      - name: debug
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
  ```

- {% include step_label.html %} Aplica todos los escenarios y espera aproximadamente 30 segundos para que los síntomas iniciales sean visibles.

  ```bash
  kubectl apply -f setup-failures.yaml
  sleep 30
  ```

- {% include step_label.html %} Obtén una vista inicial de Pods, Deployments, Services y eventos recientes.

  ```bash
  kubectl get pods -n troubleshooting-lab
  kubectl get deployments -n troubleshooting-lab
  kubectl get services -n troubleshooting-lab
  kubectl get events -n troubleshooting-lab \
    --sort-by='.lastTimestamp' | tail -30
  ```

> **IMPORTANTE:** `ImagePullBackOff`, `CrashLoopBackOff` y `Pending` son resultados esperados en este punto. No intentes corregirlos todavía.
{: .lab-note .important .compact}

---

## 🔎 Tarea 1. Aplicar la metodología de troubleshooting

Antes de resolver escenarios individuales, utilizarás siempre el mismo flujo:

```text
1. OBSERVAR   → kubectl get
2. DESCRIBIR  → kubectl describe
3. ANALIZAR   → kubectl logs / kubectl get events
4. CORREGIR   → kubectl patch / apply / delete + recreate
5. VALIDAR    → estado + prueba funcional
```

### Tarea 1.1. Construir una línea base

- {% include step_label.html %} Ejecuta una vista amplia de los recursos y registra qué escenarios muestran síntomas evidentes y cuáles requieren pruebas funcionales.

  ```bash
  kubectl get pods \
    -n troubleshooting-lab \
    -o wide

  kubectl get services \
    -n troubleshooting-lab

  kubectl get events \
    -n troubleshooting-lab \
    --sort-by='.lastTimestamp'
  ```

### Tarea 1.2. Priorizar evidencia

- {% include step_label.html %} Selecciona un Pod fallido y confirma que la sección `Events` de `kubectl describe` aporta más contexto que el campo STATUS aislado.

  ```bash
  kubectl describe pod pod-a1-imagepull \
    -n troubleshooting-lab
  ```

> **Concepto clave:** El estado visible describe el síntoma; Events, logs y configuración efectiva permiten acercarse a la causa raíz.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## 🚨 Tarea 2. Resolver fallos de Pods

En esta tarea corregirás tres fallos clásicos: imagen inexistente, proceso que termina inmediatamente y scheduling imposible.

### Tarea 2.1. ImagePullBackOff

- {% include step_label.html %} Observa y describe `pod-a1-imagepull`, prestando atención a los eventos `Failed`, `ErrImagePull` y `BackOff`.

  ```bash
  kubectl get pod pod-a1-imagepull \
    -n troubleshooting-lab

  kubectl describe pod pod-a1-imagepull \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Confirma qué imagen está configurada actualmente.

  ```bash
  kubectl get pod pod-a1-imagepull \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.containers[0].image}{"\n"}'
  ```

- {% include step_label.html %} Corrige el escenario recreando el Pod con una imagen existente.

  ```bash
  kubectl delete pod pod-a1-imagepull \
    -n troubleshooting-lab

  kubectl run pod-a1-imagepull \
    --image=nginx:1.27-alpine \
    --labels=scenario=a1 \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Espera a que el Pod quede disponible.

  ```bash
  kubectl wait \
    --for=condition=Ready \
    pod/pod-a1-imagepull \
    -n troubleshooting-lab \
    --timeout=90s
  ```

### Tarea 2.2. CrashLoopBackOff

- {% include step_label.html %} Revisa `describe` y los logs de la ejecución anterior para identificar el comando inexistente.

  ```bash
  kubectl describe pod pod-a2-crashloop \
    -n troubleshooting-lab

  kubectl logs pod-a2-crashloop \
    -n troubleshooting-lab \
    --previous
  ```

- {% include step_label.html %} Consulta el comando configurado en el Pod y relaciónalo con el error de shell.

  ```bash
  kubectl get pod pod-a2-crashloop \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.containers[0].command}{"\n"}'
  ```

- {% include step_label.html %} Recrea el Pod permitiendo que NGINX utilice su comando predeterminado.

  ```bash
  kubectl delete pod pod-a2-crashloop \
    -n troubleshooting-lab

  kubectl run pod-a2-crashloop \
    --image=nginx:1.27-alpine \
    --labels=scenario=a2 \
    -n troubleshooting-lab
  ```

### Tarea 2.3. Pending por recursos imposibles

- {% include step_label.html %} Describe `pod-a3-pending` y localiza el evento `FailedScheduling`.

  ```bash
  kubectl describe pod pod-a3-pending \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Consulta los requests definidos y confirma que ningún nodo del laboratorio puede satisfacerlos.

  ```bash
  kubectl get pod pod-a3-pending \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.containers[0].resources.requests}{"\n"}'
  ```

- {% include step_label.html %} Recrea el Pod con requests razonables para el entorno Minikube.

  ```bash
  kubectl delete pod pod-a3-pending \
    -n troubleshooting-lab

  cat > pod-a3-fixed.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-a3-pending
    namespace: troubleshooting-lab
    labels:
      scenario: a3
  spec:
    containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 200m
            memory: 128Mi
  EOF

  kubectl apply -f pod-a3-fixed.yaml
  ```

- {% include step_label.html %} Verifica que los tres escenarios A1, A2 y A3 queden finalmente en `Running`.

  ```bash
  kubectl get pods \
    -n troubleshooting-lab \
    -l 'scenario in (a1,a2,a3)'
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🔗 Tarea 3. Resolver fallos de Services y probes

Ahora diagnosticarás tres escenarios donde los Pods pueden estar presentes, pero la conectividad o disponibilidad sigue fallando.

### Tarea 3.1. Selector incorrecto

- {% include step_label.html %} Comprueba el Service y sus endpoints antes de modificar cualquier selector.

  ```bash
  kubectl get service svc-b1-wrong-selector \
    -n troubleshooting-lab

  kubectl get endpoints svc-b1-wrong-selector \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Compara el selector del Service con los labels del Pod destino.

  ```bash
  kubectl describe service svc-b1-wrong-selector \
    -n troubleshooting-lab

  kubectl get pod pod-b1-backend \
    -n troubleshooting-lab \
    --show-labels
  ```

- {% include step_label.html %} Corrige únicamente el selector incorrecto.

  ```bash
  kubectl patch service svc-b1-wrong-selector \
    -n troubleshooting-lab \
    --type=merge \
    -p '{"spec":{"selector":{"app":"backend-real"}}}'
  ```

- {% include step_label.html %} Comprueba que los endpoints aparecen automáticamente.

  ```bash
  kubectl get endpoints svc-b1-wrong-selector \
    -n troubleshooting-lab
  ```

### Tarea 3.2. targetPort incorrecto

- {% include step_label.html %} Comprueba que `svc-b2-wrong-port` sí tiene endpoint, pero observa el puerto asociado.

  ```bash
  kubectl get endpoints svc-b2-wrong-port \
    -n troubleshooting-lab

  kubectl describe service svc-b2-wrong-port \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Confirma que NGINX escucha en el puerto 80 según la configuración del Pod.

  ```bash
  kubectl get pod pod-b2-webserver \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.containers[0].ports[0].containerPort}{"\n"}'
  ```

- {% include step_label.html %} Corrige `targetPort` para dirigir tráfico al puerto correcto.

  ```bash
  kubectl patch service svc-b2-wrong-port \
    -n troubleshooting-lab \
    --type=merge \
    -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
  ```

### Tarea 3.3. Liveness probe incorrecta

- {% include step_label.html %} Obtén uno de los Pods del Deployment y revisa Events para localizar mensajes `Unhealthy`.

  ```bash
  POD_B3=$(kubectl get pod \
    -n troubleshooting-lab \
    -l app=app-b3 \
    -o jsonpath='{.items[0].metadata.name}')

  kubectl describe pod "$POD_B3" \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Consulta la ruta configurada en la liveness probe.

  ```bash
  kubectl get deployment deploy-b3-liveness \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{"\n"}'
  ```

- {% include step_label.html %} Corrige la ruta a `/`, provocando un nuevo rollout del Deployment.

  ```bash
  kubectl patch deployment deploy-b3-liveness \
    -n troubleshooting-lab \
    --type='json' \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path","value":"/"}]'
  ```

- {% include step_label.html %} Espera a que el Deployment alcance nuevamente disponibilidad completa.

  ```bash
  kubectl rollout status \
    deployment/deploy-b3-liveness \
    -n troubleshooting-lab \
    --timeout=120s
  ```

- {% include step_label.html %} Confirma que los tres Services tienen destinos disponibles.

  ```bash
  kubectl get endpoints \
    -n troubleshooting-lab \
    svc-b1-wrong-selector \
    svc-b2-wrong-port \
    svc-b3-liveness
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

## 🌐 Tarea 4. Diagnosticar fallos de DNS

En esta tarea resolverás una configuración DNS incorrecta y luego verificarás la salud normal de CoreDNS desde un Pod de diagnóstico.

### Tarea 4.1. dnsPolicy incorrecta

- {% include step_label.html %} Comprueba que `pod-c1-dns-policy` está `Running` aunque no pueda resolver nombres internos.

  ```bash
  kubectl get pod pod-c1-dns-policy \
    -n troubleshooting-lab
  ```

- {% include step_label.html %} Ejecuta una consulta DNS y después revisa `/etc/resolv.conf`.

  ```bash
  kubectl exec pod-c1-dns-policy \
    -n troubleshooting-lab -- \
    nslookup kubernetes.default.svc.cluster.local || true

  kubectl exec pod-c1-dns-policy \
    -n troubleshooting-lab -- \
    cat /etc/resolv.conf
  ```

- {% include step_label.html %} Confirma la política DNS configurada actualmente.

  ```bash
  kubectl get pod pod-c1-dns-policy \
    -n troubleshooting-lab \
    -o jsonpath='{.spec.dnsPolicy}{"\n"}'
  ```

- {% include step_label.html %} Recrea el Pod con `dnsPolicy: ClusterFirst`.

  ```bash
  kubectl delete pod pod-c1-dns-policy \
    -n troubleshooting-lab

  cat > pod-c1-fixed.yaml <<'EOF'
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-c1-dns-policy
    namespace: troubleshooting-lab
    labels:
      scenario: c1
  spec:
    dnsPolicy: ClusterFirst
    containers:
      - name: debug
        image: busybox:1.36
        command: ["sh", "-c", "sleep 3600"]
  EOF

  kubectl apply -f pod-c1-fixed.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/pod-c1-dns-policy \
    -n troubleshooting-lab \
    --timeout=60s
  ```

- {% include step_label.html %} Repite la consulta y confirma que el nombre interno ahora resuelve.

  ```bash
  kubectl exec pod-c1-dns-policy \
    -n troubleshooting-lab -- \
    nslookup kubernetes.default.svc.cluster.local
  ```

### Tarea 4.2. Diagnóstico de CoreDNS

- {% include step_label.html %} Revisa los Pods y el Service de CoreDNS.

  ```bash
  kubectl get pods \
    -n kube-system \
    -l k8s-app=kube-dns

  kubectl get service kube-dns \
    -n kube-system
  ```

- {% include step_label.html %} Comprueba que el Service `kube-dns` dispone de endpoints activos.

  ```bash
  kubectl get endpoints kube-dns \
    -n kube-system
  ```

- {% include step_label.html %} Utiliza `pod-c2-dns-debug` para resolver un Service del namespace y el Service `kubernetes.default`.

  ```bash
  kubectl exec pod-c2-dns-debug \
    -n troubleshooting-lab -- \
    nslookup svc-b1-wrong-selector

  kubectl exec pod-c2-dns-debug \
    -n troubleshooting-lab -- \
    nslookup kubernetes.default.svc.cluster.local
  ```

- {% include step_label.html %} Revisa `/etc/resolv.conf` y relaciona `nameserver` y `search` con el comportamiento observado.

  ```bash
  kubectl exec pod-c2-dns-debug \
    -n troubleshooting-lab -- \
    cat /etc/resolv.conf
  ```

> **NOTA:** No es necesario modificar CoreDNS para completar este escenario. El objetivo es demostrar que el servicio DNS del clúster está sano después de corregir la política DNS del Pod C1.
{: .lab-note .info .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r4 %}{{ results[3] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r4 %}

{% include support-prompt.html task="tarea4" %}

---

## ✅ Tarea 5. Ejecutar validación integral

La última tarea verifica que los ocho escenarios se encuentran corregidos y que las pruebas funcionales básicas responden.

### Tarea 5.1. Validar Pods y Deployment

- {% include step_label.html %} Ejecuta las comprobaciones siguientes.

  ```bash
  kubectl get pods \
    -n troubleshooting-lab

  kubectl get deployment deploy-b3-liveness \
    -n troubleshooting-lab
  ```

### Tarea 5.2. Validar Services

- {% include step_label.html %} Crea un Pod temporal para probar los tres Services corregidos.

  ```bash
  kubectl run final-test \
    --rm -i \
    --restart=Never \
    --image=busybox:1.36 \
    -n troubleshooting-lab \
    -- sh -c '
      echo "=== B1 ==="
      wget -qO- http://svc-b1-wrong-selector | head -2

      echo "=== B2 ==="
      wget -qO- http://svc-b2-wrong-port | head -2

      echo "=== B3 ==="
      wget -qO- http://svc-b3-liveness | head -2
    '
  ```

### Tarea 5.3. Ejecutar el resumen automático

- {% include step_label.html %} Ejecuta el bloque siguiente para obtener una validación final compacta.

  ```bash
  echo "=== Validacion final de la Practica 8 ==="

  for POD in \
    pod-a1-imagepull \
    pod-a2-crashloop \
    pod-a3-pending \
    pod-c1-dns-policy \
    pod-c2-dns-debug
  do
    STATUS=$(kubectl get pod "$POD" \
      -n troubleshooting-lab \
      -o jsonpath='{.status.phase}')

    echo "$POD: $STATUS"
  done

  READY=$(kubectl get deployment deploy-b3-liveness \
    -n troubleshooting-lab \
    -o jsonpath='{.status.readyReplicas}')

  echo "deploy-b3-liveness ready: $READY/2"

  echo ""
  echo "Endpoints:"

  kubectl get endpoints \
    -n troubleshooting-lab \
    svc-b1-wrong-selector \
    svc-b2-wrong-port \
    svc-b3-liveness

  echo ""
  echo "DNS:"

  kubectl exec pod-c1-dns-policy \
    -n troubleshooting-lab -- \
    nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 \
    && echo "C1 DNS: OK" \
    || echo "C1 DNS: FAIL"

  kubectl exec pod-c2-dns-debug \
    -n troubleshooting-lab -- \
    nslookup svc-b1-wrong-selector >/dev/null 2>&1 \
    && echo "C2 DNS: OK" \
    || echo "C2 DNS: FAIL"

  echo "=== Fin de validacion ==="
  ```

**Salida esperada aproximada:**

```text
pod-a1-imagepull: Running
pod-a2-crashloop: Running
pod-a3-pending: Running
pod-c1-dns-policy: Running
pod-c2-dns-debug: Running
deploy-b3-liveness ready: 2/2
...
C1 DNS: OK
C2 DNS: OK
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r5 %}{{ results[4] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r5 %}

{% include support-prompt.html task="tarea5" %}

---

## 🛠️ Resolución de problemas

### Problema 1. ImagePullBackOff continúa después de corregir la imagen

**Síntoma:** El Pod sigue sin iniciar aunque la imagen parece válida.

**Causa probable:** Existe un problema de conectividad, rate limiting del registro o la imagen no está disponible para la arquitectura utilizada.

**Solución:**

```bash
kubectl describe pod pod-a1-imagepull \
  -n troubleshooting-lab
```

Lee el mensaje exacto de Events antes de cambiar nuevamente el manifiesto.

---

### Problema 2. logs --previous no devuelve información

**Síntoma:** `kubectl logs --previous` indica que no existe una instancia anterior del contenedor.

**Causa probable:** El contenedor todavía no ha reiniciado o el Pod fue recreado recientemente.

**Solución:**

```bash
kubectl get pod pod-a2-crashloop \
  -n troubleshooting-lab

kubectl describe pod pod-a2-crashloop \
  -n troubleshooting-lab
```

Utiliza logs normales si existe una instancia activa o espera a que ocurra al menos un reinicio.

---

### Problema 3. El Pod A3 continúa Pending

**Síntoma:** El Pod sigue sin ser programado después de reducir requests.

**Causa probable:** Existe otro motivo de scheduling distinto a CPU o memoria.

**Solución:**

```bash
kubectl describe pod pod-a3-pending \
  -n troubleshooting-lab
```

Lee el evento `FailedScheduling` completo. Puede señalar taints, affinity o restricciones de nodos.

---

### Problema 4. Un Service tiene endpoints pero wget falla

**Síntoma:** El Service muestra destinos activos, pero la conexión HTTP no funciona.

**Causa probable:** El puerto destino es incorrecto o la aplicación no escucha donde espera el Service.

**Solución:**

```bash
kubectl describe service svc-b2-wrong-port \
  -n troubleshooting-lab

kubectl get pod pod-b2-webserver \
  -n troubleshooting-lab \
  -o yaml
```

Compara `targetPort` con el puerto real de la aplicación.

---

### Problema 5. DNS interno sigue sin resolver

**Síntoma:** El Pod usa `ClusterFirst`, pero `nslookup` continúa fallando.

**Causa probable:** CoreDNS no está disponible o el Service `kube-dns` no tiene endpoints.

**Solución:**

```bash
kubectl get pods \
  -n kube-system \
  -l k8s-app=kube-dns

kubectl get endpoints kube-dns \
  -n kube-system

kubectl exec pod-c1-dns-policy \
  -n troubleshooting-lab -- \
  cat /etc/resolv.conf
```

No modifiques CoreDNS hasta comprobar primero estos tres elementos.
