---
layout: lab
title: "Práctica complementaria 6.2: Validación de DNS interno"
permalink: /lab12/lab12/
images_base: /labs/lab12/img
duration: "15 minutos"
objective:
  - Validar la resolución DNS de Services dentro del mismo namespace.
  - Comparar nombres cortos, nombres calificados por namespace y FQDN completos.
  - Interpretar la configuración DNS disponible dentro de un Pod.
  - Comprobar cómo cambia la resolución cuando el cliente se encuentra en otro namespace.
prerequisites:
  - Haber completado la Práctica 6 y la Práctica complementaria 6.1.
  - Conservar el namespace lab10.
  - Conservar los Services backend-svc y frontend-svc.
  - Tener CoreDNS operativo en el clúster Minikube.
  - Tener kubectl configurado contra el contexto correcto.
introduction:
  - Esta práctica complementaria se desarrolla como un reto de resolución de nombres. Utilizarás Pods temporales para comprobar cómo Kubernetes registra los Services en DNS, cómo funciona el search domain del namespace y cuándo es necesario incluir el namespace o utilizar el FQDN completo. También compararás el comportamiento desde lab10 y desde un namespace diferente.
slug: lab12
lab_number: 12
final_result: >
  Al finalizar el reto habrás validado la resolución DNS interna de Kubernetes utilizando nombres cortos, nombres con namespace y FQDN, identificando cómo el namespace del Pod modifica el comportamiento de búsqueda.
notes:
  - Esta práctica reutiliza los Services creados en el Lab 10.
  - Los Pods de diagnóstico son temporales y deben eliminarse al finalizar.
  - No modifiques CoreDNS ni sus ConfigMaps durante este reto.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: Debugging DNS Resolution
    url: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
prev: /lab11/lab11/
next: /lab13/lab13/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

## 🧩 Preparación del reto

Esta práctica reutiliza `backend-svc` y `frontend-svc` del namespace `lab10`.

### 🗂️ Confirmar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que Minikube continúa operativo antes de realizar pruebas de resolución DNS.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y ubícate en el directorio del Lab 10.

  ```bash
  cd /c/LABS/kubernetes/lab10
  ```

- {% include step_label.html %} Confirma que los Services utilizados por el reto continúan disponibles dentro del namespace `lab10`.

  ```bash
  kubectl get services \
    -n lab10 \
    backend-svc frontend-svc
  ```

- {% include step_label.html %} Comprueba que CoreDNS permanece en estado `Running` antes de crear Pods de diagnóstico.

  ```bash
  kubectl get pods \
    -n kube-system \
    -l k8s-app=kube-dns
  ```

**Resultado esperado:**

Los Services deben existir y al menos un Pod de CoreDNS debe permanecer disponible.

---

## 🔎 Reto 1. Validar DNS desde el mismo namespace

**Tiempo sugerido: 5 minutos**

Tu primera misión consiste en comprobar las diferentes formas con las que un Pod de `lab10` puede resolver `backend-svc`.

### Reto 1.1. Crear un Pod temporal

- {% include step_label.html %} Crea un Pod temporal llamado `dns-lab10` dentro del namespace `lab10` utilizando una imagen que incluya `nslookup`.

### Reto 1.2. Comparar nombres DNS

Desde el Pod, intenta resolver las tres variantes siguientes:

```text
backend-svc

backend-svc.lab10

backend-svc.lab10.svc.cluster.local
```

- {% include step_label.html %} Registra qué dirección devuelve cada consulta y compara el resultado con la ClusterIP real de `backend-svc`.

### Reto 1.3. Validar frontend-svc

- {% include step_label.html %} Repite la consulta utilizando `frontend-svc` y confirma que Kubernetes devuelve la ClusterIP del Service correspondiente.

### Evidencia requerida

```text
1. ¿Resuelve backend-svc usando únicamente el nombre corto?
2. ¿Resuelve backend-svc.lab10?
3. ¿Resuelve backend-svc.lab10.svc.cluster.local?
4. ¿Las tres variantes apuntan a la misma ClusterIP?
5. ¿frontend-svc obtiene una dirección diferente?
```

### Pistas permitidas

Puedes utilizar:

```text
kubectl run
kubectl exec
nslookup
kubectl get service
-o jsonpath
```

**Resultado esperado:**

Desde un Pod ubicado en `lab10`, las tres variantes deben permitir identificar el mismo Service y resolver hacia su ClusterIP.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

## 🧭 Reto 2. Interpretar la configuración DNS del Pod

**Tiempo sugerido: 5 minutos**

Ahora deberás explicar por qué el nombre corto funciona dentro del namespace `lab10`.

### Reto 2.1. Analizar resolv.conf

- {% include step_label.html %} Consulta `/etc/resolv.conf` dentro de `dns-lab10`.

Debes identificar al menos:

```text
nameserver
search
options
```

### Reto 2.2. Relacionar search domain y nombre corto

- {% include step_label.html %} Localiza el dominio `lab10.svc.cluster.local` dentro de la lista `search`.

- {% include step_label.html %} Explica cómo ese valor permite que una consulta como `backend-svc` sea expandida hasta encontrar el Service del namespace actual.

### Preguntas del reto

```text
1. ¿Qué dirección aparece como nameserver?
2. ¿Qué dominio de búsqueda corresponde al namespace actual?
3. ¿Qué dominios adicionales aparecen?
4. ¿Qué función cumple cluster.local?
5. ¿Por qué no es necesario escribir el FQDN completo dentro de lab10?
```

### Pistas permitidas

```text
kubectl exec
cat /etc/resolv.conf
search
svc.cluster.local
cluster.local
```

> **NOTA:** La dirección exacta del servidor DNS depende de la configuración del clúster. No asumas que siempre será `10.96.0.10`; utiliza el valor real mostrado dentro del Pod.
{: .lab-note .info .compact}

**Resultado esperado:**

Debes relacionar correctamente el search domain del Pod con la capacidad de resolver Services utilizando nombres cortos.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

## 🌐 Reto 3. Validar resolución desde otro namespace

**Tiempo sugerido: 5 minutos**

En el reto final demostrarás qué ocurre cuando el cliente ya no pertenece al mismo namespace que el Service.

### Reto 3.1. Crear un namespace temporal

- {% include step_label.html %} Crea un namespace llamado `dns-test` y un Pod temporal `dns-remote` dentro de ese namespace.

### Reto 3.2. Probar el nombre corto

- {% include step_label.html %} Desde `dns-remote`, intenta resolver únicamente:

```text
backend-svc
```

Registra el resultado.

### Reto 3.3. Utilizar el namespace del Service

- {% include step_label.html %} Intenta ahora resolver:

```text
backend-svc.lab10
```

- {% include step_label.html %} Finalmente utiliza el FQDN:

```text
backend-svc.lab10.svc.cluster.local
```

### Reto 3.4. Comparar configuraciones

- {% include step_label.html %} Consulta `/etc/resolv.conf` dentro de `dns-remote` y compara su primer search domain con el del Pod `dns-lab10`.

### Condiciones para superar el reto

```text
[ ] El nombre corto funciona desde lab10.
[ ] El nombre corto no identifica automáticamente backend-svc desde dns-test.
[ ] backend-svc.lab10 resuelve desde dns-test.
[ ] El FQDN completo resuelve desde dns-test.
[ ] La dirección obtenida coincide con la ClusterIP de backend-svc.
[ ] Se identificó la diferencia entre los search domains.
```

> **IMPORTANTE:** Si el nombre corto `backend-svc` devuelve un error desde `dns-test`, ese comportamiento es esperado: el resolver intenta primero localizar un Service con ese nombre dentro del namespace del Pod.
{: .lab-note .important .compact}

**Resultado esperado:**

Desde un namespace diferente deberás especificar al menos el namespace del Service o utilizar el FQDN para resolver `backend-svc` de `lab10`.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final del reto

- {% include step_label.html %} Ejecuta el bloque siguiente desde la terminal para comparar la ClusterIP real y las resoluciones obtenidas desde ambos namespaces.

  ```bash
  echo "=== Validacion complementaria 6.2 ==="

  SERVICE_IP=$(kubectl get service backend-svc \
    -n lab10 \
    -o jsonpath='{.spec.clusterIP}')

  echo "ClusterIP backend-svc: $SERVICE_IP"

  echo ""
  echo "--- Desde lab10 ---"

  kubectl exec \
    -n lab10 \
    dns-lab10 -- \
    nslookup backend-svc

  echo ""
  echo "--- Desde dns-test usando namespace ---"

  kubectl exec \
    -n dns-test \
    dns-remote -- \
    nslookup backend-svc.lab10

  echo ""
  echo "--- Desde dns-test usando FQDN ---"

  kubectl exec \
    -n dns-test \
    dns-remote -- \
    nslookup backend-svc.lab10.svc.cluster.local

  echo "=== Fin de validacion ==="
  ```

- {% include step_label.html %} Elimina los recursos temporales del reto después de conservar las evidencias necesarias.

  ```bash
  kubectl delete pod dns-lab10 \
    -n lab10 \
    --ignore-not-found=true

  kubectl delete namespace dns-test \
    --ignore-not-found=true
  ```

> **IMPORTANTE:** No elimines `lab10`, `backend-svc`, `frontend-svc`, los Deployments ni el addon de Ingress. Solo deben eliminarse los recursos temporales creados específicamente para este reto.
{: .lab-note .important .compact}

---

## 🛠️ Resolución de problemas

### Problema 1. nslookup no está disponible

**Síntoma:** El contenedor responde `nslookup: not found`.

**Causa probable:** La imagen elegida para el Pod de diagnóstico no incluye esa herramienta.

**Solución:**

Elimina únicamente el Pod de diagnóstico y créalo con una imagen que incluya herramientas DNS. No modifiques los Services para solucionar este problema.

---

### Problema 2. Ningún nombre DNS resuelve

**Síntoma:** Fallan tanto el nombre corto como el FQDN completo.

**Causa probable:** CoreDNS no está disponible o el Pod no puede alcanzar el servicio DNS del clúster.

**Solución:**

Comprueba el estado de CoreDNS y el Service DNS.

```bash
kubectl get pods \
  -n kube-system \
  -l k8s-app=kube-dns

kubectl get service kube-dns \
  -n kube-system
```

Si los Pods no están `Running`, revisa sus eventos antes de cambiar configuraciones.

---

### Problema 3. El FQDN resuelve pero la aplicación no responde

**Síntoma:** `nslookup` devuelve una ClusterIP válida, pero una solicitud HTTP hacia el Service falla.

**Causa probable:** DNS funciona correctamente y el problema se encuentra en otra capa, por ejemplo endpoints, Pods o puertos del Service.

**Solución:**

Separa la validación DNS del diagnóstico de conectividad.

```bash
kubectl get service backend-svc -n lab10
kubectl get endpoints backend-svc -n lab10
kubectl get pods -n lab10 -l app=backend
```

Si el DNS entrega la ClusterIP correcta, no modifiques CoreDNS.

---

### Problema 4. backend-svc resuelve por nombre corto desde dns-test

**Síntoma:** Esperabas un error, pero `backend-svc` devuelve una dirección desde el namespace temporal.

**Causa probable:** Existe otro Service llamado `backend-svc` dentro de `dns-test` o la configuración de búsqueda del Pod fue modificada.

**Solución:**

Comprueba los Services del namespace y el archivo de resolución.

```bash
kubectl get services -n dns-test

kubectl exec \
  -n dns-test \
  dns-remote -- \
  cat /etc/resolv.conf
```

Confirma que no exista un Service local con el mismo nombre antes de interpretar el resultado.
