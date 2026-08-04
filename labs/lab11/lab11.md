---
layout: lab
title: "Práctica complementaria 6.1: Diagnóstico de Service y endpoints"
permalink: /lab11/lab11/
images_base: /labs/lab11/img
duration: "15 minutos"
objective:
  - Verificar la relación entre un Service, sus selectors y los Pods seleccionados.
  - Identificar endpoints activos asociados con un Service.
  - Diagnosticar una falla provocada por un selector incorrecto.
  - Restaurar la conectividad después de corregir la configuración del Service.
prerequisites:
  - Haber completado la Práctica 6.
  - Conservar el namespace lab10.
  - Conservar los Deployments backend y frontend.
  - Conservar los Services backend-svc y frontend-svc.
  - Tener kubectl configurado contra el clúster Minikube.
introduction:
  - Esta práctica complementaria se desarrolla como un reto de troubleshooting. Partirás de los Services creados en el Lab 10 y analizarás cómo Kubernetes relaciona selectors, Pods y endpoints. Después provocarás una inconsistencia controlada en backend-svc, observarás cómo desaparecen sus endpoints y corregirás la configuración hasta restaurar la comunicación.
slug: lab11
lab_number: 11
final_result: >
  Al finalizar el reto habrás diagnosticado y corregido una falla de conectividad causada por un selector incorrecto, comprobando la relación entre Service, labels, selectors y endpoints.
notes:
  - Esta práctica reutiliza recursos creados en el Lab 10.
  - No elimines los Deployments ni los Pods del laboratorio principal.
  - La falla debe provocarse únicamente modificando el selector de backend-svc.
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

## 🧩 Preparación del reto

Esta práctica reutiliza directamente los recursos creados en el Lab 10.

### 🗂️ Confirmar el entorno

- {% include step_label.html %} Abre **Docker Desktop** y confirma que Minikube continúa operativo antes de iniciar el diagnóstico.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y ubícate en el directorio del Lab 10.

  ```bash
  cd /c/LABS/kubernetes/lab10
  ```

- {% include step_label.html %} Confirma que el namespace `lab10` continúa activo y que los Services necesarios existen.

  ```bash
  kubectl get namespace lab10
  kubectl get services -n lab10
  ```

- {% include step_label.html %} Comprueba que los Pods backend y frontend están disponibles antes de provocar cualquier falla.

  ```bash
  kubectl get pods -n lab10 -o wide
  ```

**Resultado esperado:**

Los Deployments y Services del Lab 10 deben continuar disponibles.

---

## 🔎 Reto 1. Relacionar Service, selector y Pods

**Tiempo sugerido: 5 minutos**

Tu primera misión consiste en demostrar cómo `backend-svc` identifica los Pods backend.

### Reto 1.1. Inspeccionar el selector

- {% include step_label.html %} Consulta el selector configurado en `backend-svc`.

- {% include step_label.html %} Consulta los labels de los Pods backend y confirma que existe una coincidencia con el selector del Service.

### Reto 1.2. Identificar endpoints

- {% include step_label.html %} Obtén los endpoints asociados con `backend-svc` y compara sus IPs con las direcciones IP de los Pods backend.

### Evidencias requeridas

```text
1. ¿Qué selector utiliza backend-svc?
2. ¿Qué label tienen los Pods backend?
3. ¿Cuántos endpoints tiene backend-svc?
4. ¿Las IPs de endpoints coinciden con las IPs de los Pods backend?
```

### Pistas permitidas

Puedes utilizar:

```text
kubectl get service
kubectl describe service
kubectl get pods --show-labels
kubectl get endpoints
kubectl get endpointslices
kubectl get ... -o wide
```

**Resultado esperado:**

Debes demostrar que el Service selecciona correctamente los Pods backend y que sus endpoints corresponden a las IPs de esos Pods.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

## ⚠️ Reto 2. Provocar y diagnosticar una falla de selector

**Tiempo sugerido: 5 minutos**

En este reto modificarás de forma controlada el selector de `backend-svc` para provocar una pérdida total de endpoints.

### Reto 2.1. Crear la inconsistencia

- {% include step_label.html %} Modifica únicamente el selector `app` de `backend-svc` para que deje de coincidir con los Pods backend.

Utiliza como valor incorrecto:

```text
backend-error
```

### Reto 2.2. Detectar el impacto

- {% include step_label.html %} Comprueba que el Service continúa existiendo y conserva su ClusterIP.

- {% include step_label.html %} Consulta nuevamente sus endpoints y confirma que ya no existen destinos activos.

- {% include step_label.html %} Desde un Pod frontend, intenta acceder a `backend-svc` y registra el comportamiento observado.

### Preguntas del reto

```text
1. ¿El Service fue eliminado?
2. ¿La ClusterIP cambió?
3. ¿Qué ocurrió con los endpoints?
4. ¿Los Pods backend continúan Running?
5. ¿Por qué la comunicación falla si los Pods siguen activos?
```

### Pistas permitidas

```text
kubectl patch service
kubectl describe service
kubectl get endpoints
kubectl get pods
kubectl exec
wget
```

> **IMPORTANTE:** No modifiques labels de los Pods ni reinicies Deployments. El objetivo es demostrar que un selector incorrecto puede dejar un Service sin destinos aun cuando los Pods estén saludables.
{: .lab-note .important .compact}

**Resultado esperado:**

`backend-svc` debe continuar existiendo, pero sin endpoints disponibles porque su selector ya no coincide con ningún Pod.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

## ✅ Reto 3. Restaurar la conectividad

**Tiempo sugerido: 5 minutos**

En el reto final deberás corregir únicamente el selector del Service y demostrar que Kubernetes vuelve a asociar automáticamente los Pods.

### Reto 3.1. Corregir backend-svc

- {% include step_label.html %} Restaura el valor correcto del selector `app` de `backend-svc`.

- {% include step_label.html %} Comprueba que los endpoints reaparecen sin recrear los Pods ni el Service.

### Reto 3.2. Validar conectividad

- {% include step_label.html %} Desde uno de los Pods frontend, realiza nuevamente una solicitud hacia `backend-svc`.

- {% include step_label.html %} Confirma que la respuesta vuelve a contener `BACKEND API`.

### Condiciones para superar el reto

```text
[ ] backend-svc conserva su ClusterIP.
[ ] El selector final es app=backend.
[ ] Los Pods backend continúan Running.
[ ] backend-svc vuelve a tener endpoints.
[ ] Las IPs de los endpoints corresponden a Pods backend.
[ ] El acceso desde frontend vuelve a funcionar.
```

**Resultado esperado:**

La conectividad debe restaurarse inmediatamente después de que el selector vuelva a coincidir con los labels de los Pods.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final del reto

- {% include step_label.html %} Ejecuta el bloque siguiente para comprobar que el Service quedó restaurado correctamente.

  ```bash
  echo "=== Validacion complementaria 6.1 ==="

  SELECTOR=$(kubectl get service backend-svc \
    -n lab10 \
    -o jsonpath='{.spec.selector.app}')

  if [ "$SELECTOR" = "backend" ]; then
    echo "✅ Selector correcto: app=backend"
  else
    echo "❌ Selector incorrecto: app=$SELECTOR"
  fi

  ENDPOINTS=$(kubectl get endpoints backend-svc \
    -n lab10 \
    -o jsonpath='{.subsets[0].addresses[*].ip}')

  if [ -n "$ENDPOINTS" ]; then
    echo "✅ Endpoints disponibles: $ENDPOINTS"
  else
    echo "❌ backend-svc no tiene endpoints"
  fi

  FRONTEND_POD=$(kubectl get pod \
    -n lab10 \
    -l app=frontend \
    -o jsonpath='{.items[0].metadata.name}')

  RESPONSE=$(kubectl exec \
    -n lab10 \
    "$FRONTEND_POD" -- \
    wget -qO- http://backend-svc 2>/dev/null)

  if echo "$RESPONSE" | grep -q "BACKEND API"; then
    echo "✅ Conectividad frontend → backend restaurada"
  else
    echo "❌ La conectividad todavía falla"
  fi

  echo "=== Fin de validacion ==="
  ```

**Salida esperada aproximada:**

```text
=== Validacion complementaria 6.1 ===
✅ Selector correcto: app=backend
✅ Endpoints disponibles: 10.x.x.x 10.x.x.x
✅ Conectividad frontend → backend restaurada
=== Fin de validacion ===
```

> **IMPORTANTE:** Conserva todos los recursos del namespace `lab10`. La práctica complementaria 6.2 reutilizará los mismos Services para validar DNS interno.
{: .lab-note .important .compact}

---

## 🛠️ Resolución de problemas

### Problema 1. Los endpoints no desaparecen después del cambio

**Síntoma:** Modificaste el selector, pero `backend-svc` continúa mostrando las mismas direcciones.

**Causa probable:** El selector no fue actualizado realmente o el valor utilizado todavía coincide con algún Pod.

**Solución:**

Comprueba la configuración efectiva del Service y los labels existentes.

```bash
kubectl get service backend-svc \
  -n lab10 \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get pods \
  -n lab10 \
  --show-labels
```

Asegúrate de que el valor temporal no coincida con ningún Pod.

---

### Problema 2. Los endpoints reaparecen pero la comunicación continúa fallando

**Síntoma:** `kubectl get endpoints backend-svc` muestra IPs, pero la petición HTTP desde frontend no responde.

**Causa probable:** Los Pods backend pueden estar Running pero no listos para servir tráfico, o existe un problema con `targetPort`.

**Solución:**

Comprueba estado y puertos antes de modificar el Service.

```bash
kubectl get pods \
  -n lab10 \
  -l app=backend \
  -o wide

kubectl describe service backend-svc -n lab10
```

Confirma que `targetPort` sea `80` y que los Pods estén en estado `Ready`.

---

### Problema 3. El Service perdió su ClusterIP

**Síntoma:** Después del ejercicio observas una ClusterIP diferente.

**Causa probable:** El Service fue eliminado y recreado en lugar de modificar únicamente su selector.

**Solución:**

Para este reto debes conservar el mismo objeto Service. Si fue eliminado accidentalmente, vuelve a aplicar `services-clusterip.yaml`, aunque la ClusterIP asignada podría ser diferente.

```bash
cd /c/LABS/kubernetes/lab10
kubectl apply -f services-clusterip.yaml
kubectl get service backend-svc -n lab10
```
