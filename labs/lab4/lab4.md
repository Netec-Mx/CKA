---
layout: lab
title: "Práctica complementaria 2.1: Diagnóstico con labels, selectors y ReplicaSets"
permalink: /lab4/lab4/
images_base: /labs/lab4/img
duration: "20 minutos"
objective:
  - Identificar labels y selectors utilizados por Deployments, ReplicaSets y Pods.
  - Analizar ReplicaSets activos e históricos generados por rolling updates y rollback.
  - Diagnosticar un estado inesperado provocado por un Pod que dejó de coincidir con el selector del controlador.
  - Corregir únicamente el recurso anómalo y restaurar el estado esperado del workload.
prerequisites:
  - Haber completado la Práctica 2 y conservar el Deployment webapp y sus ReplicaSets.
  - Tener Docker Desktop y Minikube en ejecución.
  - Tener kubectl configurado contra el clúster correcto.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Disponer del archivo lab2-1-scenario.sh proporcionado con esta práctica.
introduction:
  - En esta práctica complementaria recibirás el Deployment webapp en un estado inesperado después de aplicar un cambio externo. La aplicación continúa funcionando, pero el número y clasificación de Pods ya no coincide con lo esperado. Deberás utilizar labels, selectors, ReplicaSets y ownerReferences para reconstruir qué ocurrió, identificar el recurso fuera del conjunto administrado y restaurar el estado correcto sin modificar el Deployment.
slug: lab4
lab_number: 4
final_result: >
  Al finalizar el reto habrás diagnosticado una anomalía de pertenencia entre Pods y ReplicaSets, identificado el efecto de labels y selectors sobre el estado deseado y restaurado el workload eliminando únicamente el recurso que quedó fuera del control del Deployment.
notes:
  - Esta práctica está diseñada para completarse en 20 minutos y reutiliza los recursos creados en el Lab 2.
  - No abras ni inspecciones lab2-1-scenario.sh antes de iniciar el reto.
  - No elimines ni recrees el Deployment webapp.
  - No cambies el selector del Deployment para resolver el incidente.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: Labels and Selectors
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
  - text: ReplicaSet
    url: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
  - text: Deployments
    url: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
prev: /lab3/lab3/
next: /lab5/lab5/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

# 🧩 Escenario

El Deployment `webapp` funcionaba correctamente al finalizar la Práctica 2.

Después de un cambio realizado por otra persona, el workload presenta un comportamiento inesperado:

- el Deployment continúa disponible;
- los Pods principales continúan `Running`;
- existe evidencia de que Kubernetes creó una réplica para conservar el estado deseado;
- hay un Pod que ya no aparece al filtrar por el selector habitual de la aplicación.

Tu objetivo es descubrir:

```text
¿Qué cambió?
¿Por qué Kubernetes reaccionó creando otra réplica?
¿Qué recurso quedó fuera del conjunto administrado?
¿Cuál es la corrección mínima para volver al estado estable?
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

## Paso 1. Confirmar el estado base

- {% include step_label.html %} Ubícate en el directorio utilizado por la Práctica 2 y confirma que `webapp` continúa disponible.

  ```bash
  cd /c/LABS/kubernetes/lab2

  kubectl get deployment webapp
  kubectl get replicasets -l app=webapp
  kubectl get pods -l app=webapp
  ```

**Resultado esperado:**

El Deployment debe tener sus réplicas disponibles y deben existir ReplicaSets asociados con la aplicación.

> **IMPORTANTE:** Si no existen ReplicaSets históricos, revisa que hayas completado previamente el rolling update y rollback del Lab 3.
{: .lab-note .important .compact}

---

## Paso 2. Aplicar el cambio que originó el incidente

- {% include step_label.html %} Descarga el archivo en la siguiente ruta.

  ```bash
  curl -L -o lab2-1-scenario.sh https://githubusercontent.com CAMBIAR ESTA URL
  ```

- {% include step_label.html %} Ejecuta el escenario proporcionado sin abrir el archivo ni revisar previamente su contenido.

  ```bash
  bash lab2-1-scenario.sh
  ```

- {% include step_label.html %} Espera unos segundos para permitir que el controlador reaccione al cambio aplicado.

  ```bash
  sleep 5
  ```

> **IMPORTANTE:** No utilices `cat`, VS Code ni otro editor para inspeccionar `lab2-1-scenario.sh` antes de completar el diagnóstico.
{: .lab-note .important .compact}

---

# 🔎 Reto 1. Reconstruir el estado del workload

**Tiempo sugerido: 6 minutos**

No modifiques recursos todavía. Primero determina qué objetos existen y cómo se relacionan.

## Reto 1.1. Revisar el Deployment

- {% include step_label.html %} Comprueba el estado deseado y disponible de `webapp`.

  ```bash
  kubectl get deployment webapp
  ```

Responde:

```text
¿Cuántas réplicas desea el Deployment?
¿Cuántas aparecen Ready?
¿El Deployment está realmente degradado?
```

---

## Reto 1.2. Analizar los Pods visibles con el selector habitual

- {% include step_label.html %} Consulta únicamente los Pods que todavía coinciden con `app=webapp`.

  ```bash
  kubectl get pods \
    -l app=webapp \
    -o wide
  ```

- {% include step_label.html %} Consulta después todos los Pods del namespace sin selector.

  ```bash
  kubectl get pods \
    --show-labels
  ```

### Preguntas de análisis

```text
1. ¿Aparecen más Pods en la segunda consulta?
2. ¿Existe algún Pod Running que no aparezca con -l app=webapp?
3. ¿Qué label diferencia ese Pod del resto?
4. ¿El nombre del Pod sugiere que pertenecía originalmente a webapp?
```

---

## Reto 1.3. Identificar propietarios

- {% include step_label.html %} Consulta `ownerReferences` para diferenciar Pods administrados de recursos que quedaron fuera del conjunto efectivo.

  ```bash
  kubectl get pods \
    -o custom-columns=NAME:.metadata.name,APP:.metadata.labels.app,OWNER:.metadata.ownerReferences[0].name
  ```

### Evidencia requerida

Debes poder señalar:

```text
Pods actualmente contados por el ReplicaSet.
Pod que continúa existiendo pero ya no coincide con el selector.
ReplicaSet propietario original del Pod anómalo.
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

# 🧭 Reto 2. Explicar por qué apareció una réplica adicional

**Tiempo sugerido: 7 minutos**

Ahora relaciona el comportamiento observado con los selectors y el estado deseado.

## Reto 2.1. Identificar selector y Pod template

- {% include step_label.html %} Obtén el selector estable del Deployment.

  ```bash
  kubectl get deployment webapp \
    -o jsonpath='{.spec.selector.matchLabels}{"\n"}'
  ```

- {% include step_label.html %} Consulta los labels definidos en el Pod template actual.

  ```bash
  kubectl get deployment webapp \
    -o jsonpath='{.spec.template.metadata.labels}{"\n"}'
  ```

---

## Reto 2.2. Analizar ReplicaSets activos e históricos

- {% include step_label.html %} Muestra todos los ReplicaSets de `webapp` y diferencia el activo de las revisiones históricas.

  ```bash
  kubectl get replicasets \
    -l app=webapp \
    --show-labels
  ```

- {% include step_label.html %} Consulta el historial del Deployment.

  ```bash
  kubectl rollout history deployment/webapp
  ```

### Preguntas del reto

```text
1. ¿Cuál ReplicaSet tiene réplicas activas?
2. ¿Cuáles tienen DESIRED=0?
3. ¿Qué pod-template-hash comparten los Pods activos?
4. ¿El Pod anómalo conserva ownerReference hacia un ReplicaSet?
5. ¿Por qué el controlador creó otro Pod si el Pod anómalo seguía Running?
```

---

## Reto 2.3. Formular la causa raíz

No avances hasta poder completar esta explicación:

```text
El ReplicaSet considera como miembros únicamente los Pods que ____________.

Cuando un Pod deja de coincidir con ____________, deja de contar para
el estado deseado aunque continúe ____________.

Por eso el ReplicaSet crea ____________ para volver a alcanzar el número
de réplicas configurado.
```

### Pistas permitidas

```text
kubectl get pods --show-labels
kubectl get replicasets --show-labels
kubectl describe replicaset
kubectl rollout history
kubectl get ... -o jsonpath
```

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

# 🛠️ Reto 3. Restaurar el estado estable

**Tiempo sugerido: 5 minutos**

Debes corregir el incidente sin cambiar la definición del Deployment.

## Restricciones

```text
[ ] No elimines webapp.
[ ] No modifiques spec.selector del Deployment.
[ ] No reduzcas replicas.
[ ] No cambies los labels del Pod template.
[ ] No elimines ReplicaSets históricos.
```

---

## Reto 3.1. Identificar el recurso que debe retirarse

- {% include step_label.html %} Localiza el Pod que permanece fuera del selector `app=webapp`.

### Pistas permitidas

```text
kubectl get pods --show-labels
kubectl get pods -l app=webapp
kubectl get pods -l 'app!=webapp'
```

> **NOTA:** El filtro negativo puede incluir otros Pods del namespace. Utiliza también nombre, ownerReference y labels para identificar el recurso correcto.
{: .lab-note .info .compact}

---

## Reto 3.2. Aplicar la corrección mínima

- {% include step_label.html %} Elimina únicamente el Pod que quedó fuera del conjunto administrado.

No se proporciona el comando exacto: debes construirlo a partir del nombre identificado durante el diagnóstico.

---

## Reto 3.3. Validar recuperación

- {% include step_label.html %} Confirma que únicamente permanecen los Pods administrados con `app=webapp`.

  ```bash
  kubectl get pods \
    -l app=webapp \
    --show-labels
  ```

- {% include step_label.html %} Revisa el ReplicaSet activo.

  ```bash
  kubectl get replicasets \
    -l app=webapp
  ```

- {% include step_label.html %} Confirma que el Deployment se encuentra estable y sin operaciones pendientes.

  ```bash
  kubectl rollout status deployment/webapp
  ```

---

# ✅ Validación final

La práctica queda completada cuando puedes demostrar:

```text
[✓] webapp conserva el número deseado de réplicas.
[✓] Todos los Pods administrados tienen app=webapp.
[✓] No queda ningún Pod aislado del incidente.
[✓] El ReplicaSet activo tiene DESIRED=CURRENT=READY.
[✓] Los ReplicaSets históricos permanecen conservados.
[✓] El Deployment no fue recreado ni alterado para resolver el problema.
```

Ejecuta:

```bash
echo "=== Validacion final Lab 2.1 ==="

echo ""
echo "--- Deployment ---"
kubectl get deployment webapp

echo ""
echo "--- Pods administrados ---"
kubectl get pods \
  -l app=webapp \
  --show-labels

echo ""
echo "--- ReplicaSets ---"
kubectl get replicasets \
  -l app=webapp

echo ""
echo "--- Historial ---"
kubectl rollout history deployment/webapp

echo ""
echo "--- Estado del rollout ---"
kubectl rollout status deployment/webapp

echo ""
echo "=== Fin de validacion ==="
```

---

# 🧠 Cierre del reto

El comportamiento observado demuestra que un controlador no cuenta Pods simplemente porque:

```text
están Running
tienen un nombre parecido
fueron creados originalmente por la aplicación
```

La pertenencia efectiva depende de:

```text
labels del recurso
        +
selector del controlador
```

Cuando la coincidencia desaparece:

```text
Pod sigue Running
        ↓
deja de coincidir con selector
        ↓
ReplicaSet ya no lo cuenta
        ↓
estado actual < estado deseado
        ↓
ReplicaSet crea reemplazo
```

El diagnóstico correcto consiste en entender esa relación antes de modificar recursos.

---

# 🛠️ Resolución de problemas

## Problema 1. El script indica que no encontró Pods

El escenario depende de `webapp`.

Comprueba:

```bash
kubectl get deployment webapp
kubectl get pods -l app=webapp
```

Si no existen, debes recuperar primero el estado final de la Práctica 2.

---

## Problema 2. Solo observas el número normal de Pods

Consulta todos los Pods sin aplicar selector:

```bash
kubectl get pods --show-labels
```

Recuerda que un Pod puede seguir `Running` aunque ya no sea contado por el ReplicaSet.

---

## Problema 3. No aparecen ReplicaSets históricos

Comprueba:

```bash
kubectl rollout history deployment/webapp
kubectl get replicasets -l app=webapp
```

Si el Deployment fue recreado después del Lab 3, las revisiones anteriores ya no estarán disponibles.

---

## Problema 4. Eliminaste accidentalmente un Pod administrado

No crees uno manualmente.

El ReplicaSet debe restaurar automáticamente la cantidad deseada:

```bash
kubectl rollout status deployment/webapp
kubectl get pods -l app=webapp
```

Espera a que el controlador complete la reconciliación.
