---
course_id: kubeadmin
lab_id: l011
tracking: true
position: 11
layout: lab
title: "Práctica complementaria 6.1: Diagnóstico de Service y endpoints"
permalink: /lab11/lab11/
images_base: /labs/lab11/img
duration: "15 minutos"
objective:
  - Diagnosticar una pérdida de conectividad hacia un Service sin conocer inicialmente la causa.
  - Relacionar selectors, labels, EndpointSlices y Pods como parte del flujo de red.
  - Identificar por qué un Service puede existir y conservar su ClusterIP aunque no tenga backends disponibles.
  - Aplicar la corrección mínima y validar la recuperación sin reiniciar los Deployments.
prerequisites:
  - Haber completado la Práctica 6 y conservar el namespace lab6.
  - Conservar los Deployments backend y frontend.
  - Conservar los Services backend-svc y frontend-svc.
  - Tener Docker Desktop, Minikube y kubectl operativos.
  - Disponer del archivo service-endpoints-scenario6-1.yaml proporcionado con esta práctica.
introduction:
  - En este reto el frontend ya no puede comunicarse con backend-svc, aunque los Pods backend continúan ejecutándose. No conocerás inicialmente la causa. Deberás comprobar qué componentes permanecen saludables, inspeccionar la asociación entre Service y backends, identificar la configuración responsable y restaurar la conectividad modificando únicamente el recurso necesario.
slug: lab11
lab_number: 11
final_result: >
  Al finalizar el reto habrás diagnosticado una pérdida de endpoints en backend-svc, identificado la relación incorrecta entre selector y labels y restaurado la conectividad sin recrear Pods, Deployments ni el Service.
notes:
  - Esta práctica dura 15 minutos y reutiliza los recursos creados en el Lab 6.
  - No elimines ni reinicies los Deployments backend o frontend.
  - No modifiques los labels de los Pods para resolver el incidente.
  - Conserva la ClusterIP original de backend-svc.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
  - text: EndpointSlices
    url: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
  - text: Labels and Selectors
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
prev: /lab10/lab10/
next: /lab12/lab12/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

# 🧩 Escenario del reto

La aplicación desplegada en el Lab 6 funcionaba correctamente. Después de un cambio realizado sobre la capa de red, el frontend dejó de obtener respuesta de `backend-svc`.

Los Pods backend aparentemente siguen disponibles y el objeto Service continúa existiendo.

Debes determinar:

```text
1. ¿El problema está en los Pods, el Service o la asociación entre ambos?
2. ¿backend-svc conserva su ClusterIP?
3. ¿El Service todavía dispone de backends?
4. ¿Qué configuración impide que Kubernetes publique destinos?
5. ¿Cuál es la corrección mínima necesaria?
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

- {% include step_label.html id="s001" %} Verifica que `lab6`, los Deployments y los Services de la práctica principal continúan disponibles antes de introducir el incidente.

  **Salida esperada aproximada:**

  ```text
  NAME                       READY   UP-TO-DATE   AVAILABLE
  deployment.apps/backend    2/2     2            2
  deployment.apps/frontend   2/2     2            2

  NAME                        TYPE        CLUSTER-IP
  service/backend-svc         ClusterIP   10.x.x.x
  service/frontend-svc        ClusterIP   10.x.x.x
  service/frontend-nodeport   NodePort    10.x.x.x
  ```

- {% include step_label.html id="s002" %} Registra la ClusterIP actual de `backend-svc`; este valor permitirá comprobar que el mismo Service se conserva durante la reparación.


  **Salida esperada aproximada:**

  ```text
  ClusterIP inicial: 10.x.x.x
  ```

### Aplicar el estado inicial del reto

- {% include step_label.html id="s003" %} Descarga `service-endpoints-scenario6-1.yaml`.

  ```bash
  curl -L \
    -o service-endpoints-scenario6-1.yaml \
    https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab9/service-endpoints-scenario6-1.yaml
  ```

- {% include step_label.html id="s004" %} Aplica `service-endpoints-scenario6-1.yaml` sin inspeccionarlo previamente para reproducir el estado recibido por el equipo de soporte.

  **Salida esperada:**

  ```text
  service/backend-svc configured
  ```

- {% include step_label.html id="s005" %} Espera unos segundos para que Kubernetes actualice EndpointSlices después del cambio aplicado al Service.

  ```bash
  sleep 3
  ```

  > **IMPORTANTE:** No abras el archivo del escenario antes de completar los Retos 1 y 2. El objetivo es encontrar la causa utilizando el estado efectivo del clúster.
  {: .lab-note .important .compact}

---

# 🔎 Reto 1. Determinar qué componente sigue saludable

**Tiempo sugerido: 4 minutos**

### Reto 1.1. Revisar los Pods backend

- {% include step_label.html id="s006" %} Comprueba que las dos réplicas backend continúan `Running` y `Ready`, descartando primero un fallo del workload.

  **Salida esperada aproximada:**

  ```text
  NAME                     READY   STATUS    IP
  backend-<hash>-<id>       1/1     Running   10.244.x.x
  backend-<hash>-<id>       1/1     Running   10.244.x.x
  ```

### Reto 1.2. Probar directamente un Pod backend

- {% include step_label.html id="s007" %} Ejecuta una solicitud dentro de un Pod backend para comprobar que NGINX responde antes de investigar el Service.

  **Salida esperada aproximada:**

  ```html
  <html><body><h1>BACKEND API</h1><p>Pod: backend-...</p></body></html>
  ```

### Reto 1.3. Probar el Service desde frontend

- {% include step_label.html id="s008" %} Utiliza un Pod frontend como cliente y comprueba si la misma aplicación puede alcanzarse mediante `backend-svc`.

  **Salida esperada durante el incidente:**

  ```text
  SERVICE_UNAVAILABLE
  ```

  ### Evidencia requerida

  ```text
  [ ] Los Pods backend están Running.
  [ ] El backend responde directamente dentro del Pod.
  [ ] backend-svc existe.
  [ ] El acceso mediante backend-svc falla.
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

# 🧭 Reto 2. Localizar la relación rota

**Tiempo sugerido: 5 minutos**

### Reto 2.1. Revisar los destinos del Service

- {% include step_label.html id="s009" %} Consulta los endpoints publicados para `backend-svc`; un Service sin destinos no puede reenviar tráfico aunque conserve su ClusterIP.

  **Salida esperada durante el incidente:**

  ```text
  NAME          ENDPOINTS   AGE
  backend-svc   <none>      ...
  ```

- {% include step_label.html id="s010" %} Revisa EndpointSlices para confirmar que Kubernetes tampoco está publicando direcciones de backend para este Service.

  La salida puede mostrar un EndpointSlice existente, pero sin endpoints listos asociados.

### Reto 2.2. Comparar selector y labels

- {% include step_label.html id="s011" %} Extrae el selector efectivo de `backend-svc` para conocer qué conjunto de Pods intenta localizar Kubernetes.

- {% include step_label.html id="s012" %} Muestra los labels reales de los Pods backend y compara el valor de `app` con el selector obtenido.

### Reto 2.3. Formular la causa raíz

  Debes poder completar:

  ```text
  backend-svc existe y conserva ____________________.

  Los Pods backend continúan ____________________.

  El Service no publica endpoints porque su selector ____________________
  con los labels ____________________.

  Por ello el problema está en ____________________ y no en los contenedores.
  ```

  > **IMPORTANTE:** No cambies los labels de los Pods. La corrección debe realizarse sobre el recurso que contiene la configuración incorrecta.
  {: .lab-note .important .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

# ✅ Reto 3. Aplicar la corrección mínima

**Tiempo sugerido: 4 minutos**

### Restricciones

```text
[ ] No elimines backend-svc.
[ ] No reinicies Deployments.
[ ] No modifiques labels de los Pods.
[ ] Conserva la ClusterIP registrada.
```

### Reto 3.1. Corregir el selector

- {% include step_label.html id="s013" %} Ajusta únicamente el selector de `backend-svc` para que vuelva a coincidir con los Pods backend.

### Reto 3.2. Validar recuperación automática

- {% include step_label.html id="s014" %} Comprueba que los endpoints reaparecen sin recrear el Service ni los Pods.


  **Salida esperada aproximada:**

  ```text
  NAME          ENDPOINTS
  backend-svc   10.244.x.x:80,10.244.x.x:80
  ```

- {% include step_label.html id="s015" %} Verifica que la ClusterIP final coincide con la registrada al comenzar el reto.

  Ambas direcciones deben ser iguales.

- {% include step_label.html id="s016" %} Repite la solicitud desde frontend y confirma que el Service vuelve a entregar la respuesta del backend.

  **Salida esperada aproximada:**

  ```html
  <html><body><h1>BACKEND API</h1><p>Pod: backend-...</p></body></html>
  ```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final

- {% include step_label.html id="s017" %} Ejecuta el siguiente script para validar la configuracion.

  ```bash
  curl -sSL https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab11/scripts/validacion.sh -o validacion.sh
  chmod +x validacion.sh
  ./validacion.sh
  ```

  **Salida esperada aproximada:**

  ```text
  === Validacion complementaria 6.1 ===
  Selector: backend
  Endpoints: 10.244.x.x 10.244.x.x
  ClusterIP conservada: 10.x.x.x
  Conectividad: OK
  ```

  > **IMPORTANTE:** Conserva todos los recursos de `lab6`. La práctica complementaria 6.2 reutilizará los Services y Pods para diagnosticar DNS interno.
  {: .lab-note .important .compact}