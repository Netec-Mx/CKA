---
layout: lab
title: "Práctica complementaria 1.1: Validación básica y diagnóstico con kubectl"
permalink: /lab2/lab2/
images_base: /labs/lab2/img
duration: "20 minutos"
objective:
  - Inspeccionar la relación entre Deployment, ReplicaSet, Pod y Service.
  - Diagnosticar un fallo preexistente sin conocer previamente su causa.
  - Utilizar kubectl get, describe, labels, selectors y endpoints como evidencia.
  - Corregir únicamente el recurso responsable y validar la recuperación del servicio.
prerequisites:
  - Haber completado la Práctica 1.
  - Conservar node-web-deployment y node-web-service.
  - Tener Minikube y kubectl operativos.
  - Disponer del archivo lab1-1-scenario.yaml proporcionado con esta práctica.
introduction:
  - En este reto recibirás una aplicación que funcionaba correctamente al finalizar la Práctica 1, pero cuyo acceso mediante Service ha dejado de funcionar. No conocerás de antemano la causa. Tu objetivo será observar el estado de los recursos, recopilar evidencia, identificar la relación rota y aplicar la corrección mínima necesaria sin reiniciar innecesariamente la aplicación.
slug: lab2
lab_number: 2
final_result: >
  Al finalizar el reto habrás diagnosticado un fallo realista de conectividad entre un Service y sus Pods, identificado la causa mediante kubectl y restaurado el acceso sin recrear el Deployment.
notes:
  - El escenario contiene un error intencional que no debe revisarse antes de iniciar el diagnóstico.
  - No elimines ni recrees el Deployment node-web-deployment.
  - No modifiques los labels de los Pods para resolver el incidente.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: Debug Services
    url: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
  - text: Labels and Selectors
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  - text: Service
    url: https://kubernetes.io/docs/concepts/services-networking/service/
prev: /lab1/lab1/
next: /lab3/lab3/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

# 🧩 Escenario

La aplicación Node.js desplegada en la Práctica 1 continúa ejecutándose, pero un cambio reciente ha provocado que el acceso a través de `node-web-service` deje de funcionar.

No se proporciona la causa del problema.

Tu objetivo es responder:

```text
¿Qué recurso está fallando?
¿Qué evidencia demuestra la causa?
¿Cuál es la corrección mínima necesaria?
¿Cómo compruebas que el servicio volvió a funcionar?
```

---

## ⏱️ Distribución sugerida

```text
Preparación         2 min
Reto 1              6 min
Reto 2              7 min
Reto 3              5 min
Total               20 min
```

---

# ⚙️ Preparación del escenario

## Paso 1. Confirmar los recursos de la Práctica 1

- {% include step_label.html %} Verifica que el Deployment y el Service originales continúan disponibles antes de introducir el incidente.

  ```bash
  kubectl get deployment node-web-deployment
  kubectl get service node-web-service
  kubectl get pods -l app=node-web
  ```

**Resultado esperado:**

El Deployment debe estar disponible y al menos un Pod debe encontrarse en estado `Running`.

---

## Paso 2. Aplicar el escenario defectuoso

- {% include step_label.html %} Ejecuta el siguiente comando para descargar el archivo del reto.

  ```bash
  curl -L -o k8s/lab1-1-scenario.yaml https://raw.githubusercontent.com/Netec-Mx/CKA/refs/heads/main/labs/lab2/lab2-scenario.yaml
  ```

- {% include step_label.html %} Desde el directorio donde guardaste `lab2-scenario.yaml`, aplica el archivo sin abrirlo ni inspeccionarlo todavía.

  ```bash
  kubectl apply -f lab1-1-scenario.yaml
  ```

> **IMPORTANTE:** El archivo contiene el cambio que originó el incidente. No utilices `cat`, VS Code ni otro editor para inspeccionarlo antes de completar el diagnóstico.
{: .lab-note .important .compact}

- {% include step_label.html %} Espera unos segundos para que Kubernetes actualice el estado relacionado con el Service.

  ```bash
  sleep 5
  ```

---

# 🔎 Reto 1. Determinar qué sigue funcionando

**Tiempo sugerido: 6 minutos**

Antes de buscar la causa, separa los componentes sanos de los componentes afectados.

## Reto 1.1. Revisar el workload

- {% include step_label.html %} Inspecciona el Deployment y los Pods sin modificar ningún recurso.

  ```bash
  kubectl get deployment node-web-deployment
  kubectl get pods -l app=node-web -o wide
  ```

Debes responder:

```text
¿El Deployment mantiene las réplicas esperadas?
¿Los Pods están Running?
¿Los Pods tienen IP?
¿La aplicación parece haber fallado realmente?
```

---

## Reto 1.2. Probar la aplicación directamente dentro del Pod

- {% include step_label.html %} Comprueba el endpoint `/health` directamente dentro de uno de los Pods.

  ```bash
  kubectl exec deployment/node-web-deployment -- \
    wget -qO- http://localhost:3000/health
  ```

**Resultado esperado aproximado:**

```json
{"status":"ok","pod":"node-web-deployment-<hash>-<id>"}
```

### Pregunta de diagnóstico

Si el Pod responde directamente pero el acceso mediante Service falla:

```text
¿Deberías investigar primero la aplicación o la relación entre el Service y sus backends?
```

---

## Reto 1.3. Revisar el Service

- {% include step_label.html %} Comprueba que el Service todavía existe y conserva una ClusterIP.

  ```bash
  kubectl get service node-web-service
  ```

- {% include step_label.html %} Intenta acceder a la aplicación mediante el nombre del Service desde el propio workload.

  ```bash
  kubectl exec deployment/node-web-deployment -- \
    wget -qO- \
    --timeout=3 \
    http://node-web-service/health
  ```

Registra si la conexión responde o falla.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

# 🧭 Reto 2. Encontrar la causa raíz

**Tiempo sugerido: 7 minutos**

Ahora debes encontrar por qué un Service existente no puede llegar a una aplicación que continúa saludable.

## Reto 2.1. Revisar backends asociados

- {% include step_label.html %} Comprueba si `node-web-service` tiene destinos disponibles.

  ```bash
  kubectl get endpoints node-web-service
  ```

- {% include step_label.html %} Revisa también el recurso moderno EndpointSlice asociado con el Service.

  ```bash
  kubectl get endpointslices \
    -l kubernetes.io/service-name=node-web-service
  ```

### Evidencia requerida

Registra:

```text
¿Existen direcciones de backend?
¿Aparece alguna IP de Pod?
¿El Service tiene un destino real al cual enviar tráfico?
```

---

## Reto 2.2. Inspeccionar configuración efectiva

- {% include step_label.html %} Describe el Service y localiza `Selector` y `Endpoints`.

  ```bash
  kubectl describe service node-web-service
  ```

- {% include step_label.html %} Muestra los labels reales de los Pods administrados por el Deployment.

  ```bash
  kubectl get pods \
    -l app=node-web \
    --show-labels
  ```

- {% include step_label.html %} Consulta también el selector configurado directamente en el Service.

  ```bash
  kubectl get service node-web-service \
    -o jsonpath='{.spec.selector}{"\n"}'
  ```

### Diagnóstico

Compara:

```text
Selector del Service
vs.
Labels de los Pods
```

No avances hasta poder explicar qué relación está rota.

---

## Reto 2.3. Confirmar que el Deployment no debe modificarse

- {% include step_label.html %} Revisa el selector del Deployment para comprobar que sus Pods están correctamente administrados.

  ```bash
  kubectl get deployment node-web-deployment \
    -o jsonpath='{.spec.selector.matchLabels}{"\n"}'
  ```

### Criterio de diagnóstico

Debes poder concluir cuál de estas afirmaciones corresponde al escenario:

```text
A. El Deployment no crea Pods.
B. La aplicación falla dentro del contenedor.
C. El Service existe, pero no selecciona los Pods correctos.
D. Kubernetes DNS no puede resolver node-web-service.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

# 🛠️ Reto 3. Aplicar la corrección mínima

**Tiempo sugerido: 5 minutos**

Ya identificaste la causa raíz. Corrige únicamente el recurso responsable.

## Restricciones

```text
[ ] No elimines node-web-deployment.
[ ] No reinicies los Pods.
[ ] No cambies los labels de los Pods.
[ ] No recrees node-web-service.
[ ] Conserva la ClusterIP actual.
```

---

## Reto 3.1. Registrar la ClusterIP actual

- {% include step_label.html %} Guarda la ClusterIP antes de corregir el incidente.

  ```bash
  SERVICE_IP=$(kubectl get service node-web-service \
    -o jsonpath='{.spec.clusterIP}')

  echo "ClusterIP antes de la corrección: $SERVICE_IP"
  ```

---

## Reto 3.2. Corregir el recurso

- {% include step_label.html %} Utiliza `kubectl patch`, `kubectl edit` o un manifiesto corregido para restaurar la relación adecuada entre el Service y los Pods.

### Pistas permitidas

```text
kubectl patch service
kubectl edit service
kubectl get pods --show-labels
kubectl get service -o yaml
```

No se proporciona el comando exacto porque forma parte del reto.

---

## Reto 3.3. Validar recuperación

- {% include step_label.html %} Comprueba que Kubernetes vuelva a publicar destinos para el Service.

  ```bash
  kubectl get endpoints node-web-service
  ```

- {% include step_label.html %} Verifica EndpointSlice.

  ```bash
  kubectl get endpointslices \
    -l kubernetes.io/service-name=node-web-service
  ```

- {% include step_label.html %} Comprueba nuevamente `/health` utilizando el nombre del Service.

  ```bash
  kubectl exec deployment/node-web-deployment -- \
    wget -qO- http://node-web-service/health
  ```

- {% include step_label.html %} Confirma que la ClusterIP no cambió durante la reparación.

  ```bash
  NEW_SERVICE_IP=$(kubectl get service node-web-service \
    -o jsonpath='{.spec.clusterIP}')

  echo "Antes:   $SERVICE_IP"
  echo "Después: $NEW_SERVICE_IP"
  ```

---

# ✅ Validación final

Ejecuta:

```bash
echo "=== Validacion final Lab 2 ==="

echo ""
echo "--- Deployment ---"
kubectl get deployment node-web-deployment

echo ""
echo "--- Pods ---"
kubectl get pods -l app=node-web -o wide

echo ""
echo "--- Service ---"
kubectl get service node-web-service

echo ""
echo "--- Selector ---"
kubectl get service node-web-service \
  -o jsonpath='{.spec.selector}{"\n"}'

echo ""
echo "--- Endpoints ---"
kubectl get endpoints node-web-service

echo ""
echo "--- Health mediante Service ---"
kubectl exec deployment/node-web-deployment -- \
  wget -qO- http://node-web-service/health

echo ""
echo "=== Fin de validacion ==="
```

El reto queda completado si:

```text
[✓] node-web-deployment continúa disponible.
[✓] Los Pods permanecen Running.
[✓] node-web-service conserva su ClusterIP.
[✓] El Service vuelve a tener endpoints.
[✓] /health responde mediante node-web-service.
[✓] No fue necesario reiniciar ni recrear el Deployment.
```

---

# 🧠 Cierre del reto

La evidencia debe llevarte a reconstruir el flujo:

```text
Deployment
    │
    ▼
ReplicaSet
    │
    ▼
Pods
    ▲
    │ labels/selectors
    │
Service
```

La clave del troubleshooting no consiste en modificar recursos hasta que algo funcione, sino en:

```text
1. comprobar qué componente sigue sano;
2. localizar dónde se rompe la relación;
3. obtener evidencia;
4. corregir únicamente la causa;
5. validar funcionalmente la recuperación.
```

---

# 🛠️ Resolución de problemas

## Problema 1. El archivo de escenario no se encuentra

Comprueba el directorio actual:

```bash
pwd
ls -la
```

`lab2-scenario.yaml` debe encontrarse en el directorio desde el que ejecutas `kubectl apply`.

---

## Problema 2. El Pod tampoco responde directamente

Si esta prueba falla:

```bash
kubectl exec deployment/node-web-deployment -- \
  wget -qO- http://localhost:3000/health
```

el escenario ya no coincide con el reto esperado.

Antes de continuar, revisa:

```bash
kubectl get pods -l app=node-web
kubectl logs deployment/node-web-deployment
```

La aplicación de la Práctica 1 debe estar saludable antes de diagnosticar el Service.

---

## Problema 3. Los endpoints no reaparecen después de corregir el Service

Compara nuevamente:

```bash
kubectl get service node-web-service \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get pods \
  -l app=node-web \
  --show-labels
```

El selector del Service debe coincidir exactamente con los labels requeridos en los Pods.
