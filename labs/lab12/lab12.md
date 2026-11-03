---
course_id: kubeadmin
lab_id: l012
tracking: true
position: 12
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


{% assign tracking_task_id = "t001" %}

- {% include step_label.html id="s001" %} Comprueba que `backend-svc` existe y conserva destinos antes de iniciar un diagnóstico DNS.

  **Salida esperada aproximada:**

  ```text
  NAME          TYPE        CLUSTER-IP   PORT(S)
  backend-svc   ClusterIP   10.x.x.x     80/TCP

  NAME          ENDPOINTS
  backend-svc   10.244.x.x:80,10.244.x.x:80
  ```

- {% include step_label.html id="s002" %} Confirma que CoreDNS está `Running`, estableciendo una línea base antes de crear el cliente defectuoso.

  **Salida esperada aproximada:**

  ```text
  NAME                       READY   STATUS
  coredns-<hash>-<id>        1/1     Running
  ```

### Aplicar el estado inicial del reto

- {% include step_label.html id="s003" %} Descarga `dns-internal-scenario6-2.yaml`.

  ```bash
  curl -L \
    -o dns-internal-scenario6-2.yaml \
    https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab9/dns-internal-scenario6-2.yaml
  ```

- {% include step_label.html id="s004" %} Aplica `dns-internal-scenario6-2.yaml` sin inspeccionarlo previamente para crear el Pod que reproduce el incidente.


  **Salida esperada:**

  ```text
  pod/dns-client created
  ```

- {% include step_label.html id="s005" %} Espera hasta que el Pod esté listo antes de interpretar las pruebas de resolución.

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

- {% include step_label.html id="s006" %} Intenta resolver el nombre corto `backend-svc` desde `dns-client` y registra el resultado.

  **Salida esperada durante el incidente:**

  La consulta debe fallar o terminar por timeout porque el Pod no utiliza correctamente el DNS del clúster.

### Reto 1.2. Comprobar otro cliente saludable

- {% include step_label.html id="s007" %} Utiliza un Pod frontend existente para comprobar que el mismo nombre puede resolverse desde otro cliente del namespace.

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

- {% include step_label.html id="s008" %} Revisa `/etc/resolv.conf` dentro de `dns-client` utilizando `sh -c` para impedir que Git Bash transforme la ruta Linux en una ruta de Windows.


### Evidencia esperada durante el incidente

La configuración no debe mostrar el servidor DNS y search domains normales de Kubernetes; observarás una configuración distinta a la utilizada por los Pods saludables.

### Reto 2.2. Revisar dnsPolicy

- {% include step_label.html id="s009" %} Consulta la política DNS efectiva del Pod para determinar si Kubernetes está aplicando la configuración estándar del clúster.

- {% include step_label.html id="s010" %} Consulta también una posible configuración DNS explícita para identificar si el Pod sobrescribe el resolver proporcionado por Kubernetes.

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

- {% include step_label.html id="s011" %} Abre `dns-internal-scenario6-2.yaml` después de completar el diagnóstico y elimina la configuración DNS personalizada que impide usar el resolver del clúster.

La configuración final debe utilizar:

  ```text
  dnsPolicy: ClusterFirst
  ```

### Reto 3.2. Recrear el Pod

- {% include step_label.html id="s012" %} Elimina únicamente `dns-client` y vuelve a aplicar el manifiesto corregido porque la política DNS forma parte de la especificación del Pod.

  **Salida esperada:**

    ```text
    pod "dns-client" deleted
    pod/dns-client created
    pod/dns-client condition met
    ```

### Reto 3.3. Validar nombre corto y FQDN

- {% include step_label.html id="s013" %} Comprueba que el nombre corto ahora resuelve mediante el search domain del namespace `lab6`.

- {% include step_label.html id="s014" %} Valida también el FQDN completo para confirmar la identidad DNS absoluta del Service.

  **Salida esperada aproximada:**

  ```text
  Name:    backend-svc.lab6.svc.cluster.local
  Address: 10.x.x.x
  ```

- {% include step_label.html id="s015" %} Confirma conectividad HTTP para demostrar que la resolución obtenida corresponde con un Service funcional.

  **Salida esperada aproximada:**

  ```text
  <html><body><h1>BACKEND API</h1><p>Pod: backend-...</p></body></html>
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final

- {% include step_label.html id="s016" %} Ejecuta el siguiente script para validar la configuracion.

  ```bash
  curl -sSL https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab12/scripts/validacion.sh -o validacion.sh
  chmod +x validacion.sh
  ./validacion.sh
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

{% assign tracking_task_id = "t002" %}

- {% include step_label.html id="s017" %} Elimina únicamente el Pod temporal después de conservar las evidencias.

  > **IMPORTANTE:** Conserva `lab6`, sus Deployments, Services y el addon de Ingress. Solo debe eliminarse el Pod temporal `dns-client`.
  {: .lab-note .important .compact}