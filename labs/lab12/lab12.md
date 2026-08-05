---
layout: lab
title: "Práctica complementaria 6.2: Diagnóstico de DNS interno"
permalink: /lab12/lab12/
images_base: /labs/lab12/img
duration: "15 minutos"
objective:
  - Diagnosticar una falla de resolución DNS desde un Pod sin modificar CoreDNS.
  - Diferenciar un problema del cliente de un problema del servicio DNS del clúster.
  - Interpretar dnsPolicy y /etc/resolv.conf dentro de un Pod.
  - Restaurar la resolución mediante ClusterFirst y validar nombres corto y FQDN.
prerequisites:
  - Haber completado la Práctica 6 y la Práctica complementaria 6.1.
  - Conservar el namespace lab6 y los Services backend-svc y frontend-svc.
  - Tener CoreDNS operativo en Minikube.
  - Tener Docker Desktop y kubectl disponibles.
  - Disponer del archivo dns-internal-scenario6-2.yaml proporcionado con esta práctica.
introduction:
  - En este reto un Pod de diagnóstico dentro de lab6 no puede resolver backend-svc, aunque el Service existe y otros componentes del clúster permanecen saludables. No conocerás inicialmente la causa. Deberás diferenciar una falla del cliente de una falla de CoreDNS, inspeccionar la configuración DNS efectiva y aplicar la corrección mínima sin modificar los componentes del sistema.
slug: lab12
lab_number: 12
final_result: >
  Al finalizar el reto habrás diagnosticado una política DNS incorrecta dentro de un Pod, restaurado la configuración ClusterFirst y validado la resolución de backend-svc mediante nombre corto y FQDN.
notes:
  - Esta práctica dura 15 minutos y reutiliza los Services creados en el Lab 10.
  - No modifiques Deployments, Services, CoreDNS ni el ConfigMap de CoreDNS.
  - En Git Bash, las rutas Linux dentro del contenedor se consultan mediante sh -c para evitar conversión automática de rutas.
  - El Pod dns-client es temporal y debe eliminarse al finalizar.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
  - text: Debugging DNS Resolution
    url: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
  - text: Pod DNS Config
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
prev: /lab11/lab11/
next: /lab13/lab13/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

# 🧩 Escenario del reto

El Service `backend-svc` funciona después de completar la complementaria 6.1. Sin embargo, un nuevo Pod de diagnóstico dentro de `lab6` no puede resolver su nombre DNS.

Debes determinar:

```text
1. ¿backend-svc existe y conserva su ClusterIP?
2. ¿CoreDNS está operativo?
3. ¿La falla ocurre en todo el clúster o solamente en dns-client?
4. ¿Qué configuración DNS utiliza el Pod?
5. ¿Cuál es la corrección mínima sin modificar CoreDNS?
```

### ⏱️ Distribución sugerida

```text
Preparación         2 min
Reto 1              4 min
Reto 2              5 min
Reto 3              4 min
Total               15 min
```

---

## ⚙️ Preparación del escenario

- {% include step_label.html %} Comprueba que `backend-svc` existe y conserva destinos antes de iniciar un diagnóstico DNS.

  ```bash
  kubectl get service backend-svc \
    -n lab6

  kubectl get endpoints backend-svc \
    -n lab6
  ```

**Salida esperada aproximada:**

```text
NAME          TYPE        CLUSTER-IP   PORT(S)
backend-svc   ClusterIP   10.x.x.x     80/TCP

NAME          ENDPOINTS
backend-svc   10.244.x.x:80,10.244.x.x:80
```

- {% include step_label.html %} Confirma que CoreDNS está `Running`, estableciendo una línea base antes de crear el cliente defectuoso.

  ```bash
  kubectl get pods \
    -n kube-system \
    -l k8s-app=kube-dns
  ```

**Salida esperada aproximada:**

```text
NAME                       READY   STATUS
coredns-<hash>-<id>        1/1     Running
```

### Aplicar el estado inicial del reto

- {% include step_label.html %} Descarga `dns-internal-scenario6-2.yaml`.

  ```bash
  curl -L \
    -o dns-internal-scenario6-2.yaml \
    https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab9/dns-internal-scenario6-2.yaml
  ```

- {% include step_label.html %} Aplica `dns-internal-scenario6-2.yaml` sin inspeccionarlo previamente para crear el Pod que reproduce el incidente.

  ```bash
  kubectl apply -f dns-internal-scenario6-2.yaml
  ```

**Salida esperada:**

```text
pod/dns-client created
```

- {% include step_label.html %} Espera hasta que el Pod esté listo antes de interpretar las pruebas de resolución.

  ```bash
  kubectl wait \
    --for=condition=Ready \
    pod/dns-client \
    -n lab6 \
    --timeout=60s
  ```

**Salida esperada:**

```text
pod/dns-client condition met
```

> **IMPORTANTE:** No abras el manifiesto del escenario antes de completar los Retos 1 y 2. No modifiques CoreDNS durante esta práctica.
{: .lab-note .important .compact}

---

# 🔎 Reto 1. Determinar si el fallo es global o del cliente

**Tiempo sugerido: 4 minutos**

### Reto 1.1. Reproducir la falla

- {% include step_label.html %} Intenta resolver el nombre corto `backend-svc` desde `dns-client` y registra el resultado.

  ```bash
  kubectl exec \
    -n lab6 \
    dns-client -- \
    nslookup backend-svc
  ```

**Salida esperada durante el incidente:**

La consulta debe fallar o terminar por timeout porque el Pod no utiliza correctamente el DNS del clúster.

### Reto 1.2. Comprobar otro cliente saludable

- {% include step_label.html %} Utiliza un Pod frontend existente para comprobar que el mismo nombre puede resolverse desde otro cliente del namespace.

  ```bash
  FRONTEND_POD=$(kubectl get pod \
    -n lab6 \
    -l app=frontend \
    -o jsonpath='{.items[0].metadata.name}')

  kubectl exec \
    -n lab6 \
    "$FRONTEND_POD" -- \
    sh -c 'getent hosts backend-svc 2>/dev/null || nslookup backend-svc'
  ```

**Salida esperada aproximada:**

```text
10.x.x.x   backend-svc.lab6.svc.cluster.local
```

La salida exacta depende de las herramientas disponibles, pero debe resolver la ClusterIP de `backend-svc`.

### Evidencia requerida

```text
[ ] backend-svc existe.
[ ] backend-svc tiene endpoints.
[ ] CoreDNS está Running.
[ ] Otro Pod puede resolver backend-svc.
[ ] dns-client es el único cliente con falla.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

# 🧭 Reto 2. Inspeccionar la configuración DNS del Pod

**Tiempo sugerido: 5 minutos**

### Reto 2.1. Consultar resolv.conf

- {% include step_label.html %} Revisa `/etc/resolv.conf` dentro de `dns-client` utilizando `sh -c` para impedir que Git Bash transforme la ruta Linux en una ruta de Windows.

  ```bash
  kubectl exec \
    -n lab6 \
    dns-client -- \
    sh -c 'cat /etc/resolv.conf'
  ```

### Evidencia esperada durante el incidente

La configuración no debe mostrar el servidor DNS y search domains normales de Kubernetes; observarás una configuración distinta a la utilizada por los Pods saludables.

### Reto 2.2. Revisar dnsPolicy

- {% include step_label.html %} Consulta la política DNS efectiva del Pod para determinar si Kubernetes está aplicando la configuración estándar del clúster.

  ```bash
  kubectl get pod dns-client \
    -n lab6 \
    -o jsonpath='{.spec.dnsPolicy}{"\n"}'
  ```

- {% include step_label.html %} Consulta también una posible configuración DNS explícita para identificar si el Pod sobrescribe el resolver proporcionado por Kubernetes.

  ```bash
  kubectl get pod dns-client \
    -n lab6 \
    -o jsonpath='{.spec.dnsConfig}{"\n"}'
  ```

### Reto 2.3. Formular la causa

Debes poder explicar:

```text
CoreDNS está ____________________.

Otros Pods ____________________ backend-svc.

dns-client utiliza dnsPolicy ____________________.

Su configuración DNS apunta a ____________________.

Por tanto, la falla está en ____________________ y no en CoreDNS.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

# ✅ Reto 3. Restaurar DNS con la política correcta

**Tiempo sugerido: 4 minutos**

### Restricciones

```text
[ ] No modifiques CoreDNS.
[ ] No modifiques kube-dns.
[ ] No modifiques backend-svc.
[ ] No cambies los Pods frontend/backend.
[ ] Corrige únicamente dns-client.
```

### Reto 3.1. Corregir el manifiesto

- {% include step_label.html %} Abre `dns-internal-scenario6-2.yaml` después de completar el diagnóstico y elimina la configuración DNS personalizada que impide usar el resolver del clúster.

La configuración final debe utilizar:

```text
dnsPolicy: ClusterFirst
```

### Reto 3.2. Recrear el Pod

- {% include step_label.html %} Elimina únicamente `dns-client` y vuelve a aplicar el manifiesto corregido porque la política DNS forma parte de la especificación del Pod.

  ```bash
  kubectl delete pod dns-client \
    -n lab6

  kubectl apply -f dns-internal-scenario6-2.yaml

  kubectl wait \
    --for=condition=Ready \
    pod/dns-client \
    -n lab6 \
    --timeout=60s
  ```

**Salida esperada:**

```text
pod "dns-client" deleted
pod/dns-client created
pod/dns-client condition met
```

### Reto 3.3. Validar nombre corto y FQDN

- {% include step_label.html %} Comprueba que el nombre corto ahora resuelve mediante el search domain del namespace `lab6`.

  ```bash
  kubectl exec \
    -n lab6 \
    dns-client -- \
    nslookup backend-svc
  ```

- {% include step_label.html %} Valida también el FQDN completo para confirmar la identidad DNS absoluta del Service.

  ```bash
  kubectl exec \
    -n lab6 \
    dns-client -- \
    nslookup backend-svc.lab6.svc.cluster.local
  ```

**Salida esperada aproximada:**

```text
Name:    backend-svc.lab6.svc.cluster.local
Address: 10.x.x.x
```

- {% include step_label.html %} Confirma conectividad HTTP para demostrar que la resolución obtenida corresponde con un Service funcional.

  ```bash
  kubectl exec \
    -n lab6 \
    dns-client -- \
    sh -c 'wget -qO- http://backend-svc | grep "BACKEND API"'
  ```

**Salida esperada aproximada:**

```text
<html><body><h1>BACKEND API</h1><p>Pod: backend-...</p></body></html>
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final

```bash
echo "=== Validacion complementaria 6.2 ==="

echo "dnsPolicy:"
kubectl get pod dns-client \
  -n lab6 \
  -o jsonpath='{.spec.dnsPolicy}{"\n"}'

echo ""
echo "Resolucion FQDN:"
kubectl exec \
  -n lab6 \
  dns-client -- \
  nslookup backend-svc.lab6.svc.cluster.local

echo ""
echo "HTTP:"
kubectl exec \
  -n lab6 \
  dns-client -- \
  sh -c 'wget -qO- http://backend-svc | grep "BACKEND API"'

echo "=== Fin de validacion ==="
```

**Salida esperada aproximada:**

```text
=== Validacion complementaria 6.2 ===
dnsPolicy:
ClusterFirst

Resolucion FQDN:
Name: backend-svc.lab6.svc.cluster.local
Address: 10.x.x.x

HTTP:
<html><body><h1>BACKEND API</h1>...
=== Fin de validacion ===
```

- {% include step_label.html %} Elimina únicamente el Pod temporal después de conservar las evidencias.

  ```bash
  kubectl delete pod dns-client \
    -n lab6
  ```

> **IMPORTANTE:** Conserva `lab6`, sus Deployments, Services y el addon de Ingress. Solo debe eliminarse el Pod temporal `dns-client`.
{: .lab-note .important .compact}

---

## 🛠️ Resolución de problemas

### Problema 1. dns-client no inicia

```bash
kubectl get pod dns-client -n lab6
kubectl describe pod dns-client -n lab6
```

Revisa scheduling e imagen antes de investigar DNS.

### Problema 2. También falla DNS desde frontend

Comprueba CoreDNS y el Service DNS:

```bash
kubectl get pods \
  -n kube-system \
  -l k8s-app=kube-dns

kubectl get service kube-dns \
  -n kube-system
```

Si otros Pods tampoco resuelven, el problema ya no corresponde al escenario previsto.

### Problema 3. Git Bash transforma /etc/resolv.conf

Utiliza siempre:

```bash
kubectl exec -n lab6 dns-client -- \
  sh -c 'cat /etc/resolv.conf'
```

No ejecutes la ruta Linux directamente después de `--` en Git Bash.

### Problema 4. DNS resuelve pero HTTP falla

```bash
kubectl get endpoints backend-svc -n lab6
kubectl get pods -n lab6 -l app=backend
```

Si DNS devuelve la ClusterIP correcta, investiga Service, endpoints o Pods y no CoreDNS.
