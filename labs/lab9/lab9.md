---
layout: lab
title: "Práctica complementaria 5.1: Validación de permisos con ServiceAccount"
permalink: /lab9/lab9/
images_base: /labs/lab9/img
duration: "20 minutos"
objective:
  - Auditar los permisos efectivos de una ServiceAccount mediante kubectl auth can-i.
  - Comparar operaciones permitidas y denegadas dentro y fuera del namespace autorizado.
  - Diagnosticar una necesidad de acceso adicional sin ampliar innecesariamente los privilegios.
  - Ajustar un Role aplicando mínimo privilegio y verificar el nuevo comportamiento.
prerequisites:
  - Haber completado la Práctica 5.
  - Conservar el namespace lab8.
  - Conservar la ServiceAccount app-reader.
  - Conservar el Role pod-configmap-reader y el RoleBinding app-reader-binding.
  - Tener kubectl configurado contra el clúster Minikube.
introduction:
  - Esta práctica complementaria se desarrolla como un reto de autorización. Partirás del modelo RBAC creado en el Lab 8 y deberás demostrar qué puede y qué no puede hacer la ServiceAccount app-reader. Después recibirás un nuevo requerimiento funcional: la aplicación necesita consultar Services del namespace lab8. Deberás identificar por qué el acceso está denegado, modificar únicamente el permiso necesario y comprobar que Secrets, operaciones de escritura y otros namespaces continúan protegidos.
slug: lab9
lab_number: 9
final_result: >
  Al finalizar el reto habrás auditado los permisos efectivos de una ServiceAccount, identificado una autorización faltante y ampliado un Role con el mínimo privilegio necesario, verificando que los accesos no relacionados permanecen denegados.
notes:
  - Esta práctica reutiliza los recursos RBAC creados en el Lab 8.
  - No crees ClusterRoles ni ClusterRoleBindings para resolver el reto.
  - No agregues permisos sobre Secrets ni verbos de escritura.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: RBAC Authorization
    url: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
  - text: kubectl auth can-i
    url: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/
  - text: Service Accounts
    url: https://kubernetes.io/docs/concepts/security/service-accounts/
prev: /lab8/lab8/
next: /lab10/lab10/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

## 🧩 Preparación del reto

Esta práctica utiliza directamente la configuración RBAC creada en el Lab 8. Antes de resolver los retos debes comprobar que la identidad y sus vinculaciones continúan disponibles.

### 🗂️ Confirmar los recursos existentes

- {% include step_label.html %} Abre **Docker Desktop** y confirma que Minikube continúa operativo antes de realizar las verificaciones de autorización.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y ubícate en el directorio del Lab 8.

  ```bash
  cd /c/LABS/kubernetes/lab8
  ```

- {% include step_label.html %} Confirma que el namespace `lab8` continúa activo y que la ServiceAccount utilizada durante la práctica principal todavía existe.

  ```bash
  kubectl get namespace lab8
  kubectl get serviceaccount app-reader -n lab8
  ```

- {% include step_label.html %} Comprueba que el Role y el RoleBinding asociados con `app-reader` permanecen disponibles.

  ```bash
  kubectl get role pod-configmap-reader -n lab8
  kubectl get rolebinding app-reader-binding -n lab8
  ```

**Resultado esperado:**

Los cuatro recursos deben existir antes de comenzar el reto.

> **IMPORTANTE:** Si alguno de estos recursos no existe, vuelve a aplicar los manifiestos correspondientes del Lab 8 antes de continuar.
{: .lab-note .important .compact}

---

## 🔎 Reto 1. Auditar los permisos efectivos de app-reader

**Tiempo sugerido: 6 minutos**

Tu primera misión consiste en construir una matriz de permisos reales de la ServiceAccount `app-reader` sin modificar todavía ningún recurso RBAC.

### Reto 1.1. Comprobar permisos dentro de lab8

Determina si `app-reader` puede realizar cada una de las operaciones siguientes:

```text
1. get pods
2. list pods
3. get configmaps
4. get secrets
5. create pods
6. delete pods
7. get services
```

- {% include step_label.html %} Utiliza impersonación para consultar individualmente cada permiso y registra si Kubernetes responde `yes` o `no`.

### Reto 1.2. Comprobar el alcance del Role

- {% include step_label.html %} Comprueba si la misma identidad puede ejecutar `get pods` dentro del namespace `kube-system`.

- {% include step_label.html %} Obtén una vista completa de permisos efectivos de `app-reader` dentro de `lab8` y localiza las reglas provenientes de `pod-configmap-reader`.

### Evidencia requerida

Completa una tabla similar a la siguiente:

```text
OPERACIÓN             RESULTADO
get pods              ?
list pods             ?
get configmaps        ?
get secrets           ?
create pods           ?
delete pods           ?
get services          ?
get pods kube-system  ?
```

### Pistas permitidas

Puedes utilizar:

```text
kubectl auth can-i
--as
--namespace
--list
system:serviceaccount:<namespace>:<serviceaccount>
```

**Resultado esperado:**

Debes demostrar que `app-reader` puede leer Pods y ConfigMaps dentro de `lab8`, pero no dispone de permisos sobre Secrets, escritura, Services ni Pods de otros namespaces.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

## 🛡️ Reto 2. Corregir una autorización faltante con mínimo privilegio

**Tiempo sugerido: 8 minutos**

El equipo de desarrollo reporta el siguiente requerimiento:

> La aplicación que utiliza `app-reader` necesita consultar los Services disponibles dentro de `lab8` para descubrir endpoints internos. No necesita crear, modificar ni eliminar Services.

Actualmente la consulta está denegada.

### Reto 2.1. Reproducir el problema

- {% include step_label.html %} Comprueba mediante `kubectl auth can-i` que `app-reader` actualmente no puede obtener ni listar Services dentro de `lab8`.

### Reto 2.2. Identificar la causa

- {% include step_label.html %} Inspecciona el Role `pod-configmap-reader` y determina qué regla falta para satisfacer el nuevo requerimiento.

- {% include step_label.html %} Decide qué `apiGroup`, `resource` y `verbs` deben agregarse sin modificar los permisos existentes sobre Pods y ConfigMaps.

### Reto 2.3. Aplicar la corrección

- {% include step_label.html %} Modifica el manifiesto `role-reader.yaml` del Lab 8 para permitir únicamente operaciones de lectura sobre Services.

Tu corrección debe cumplir simultáneamente estas condiciones:

```text
[ ] Puede get services.
[ ] Puede list services.
[ ] Puede watch services.
[ ] NO puede create services.
[ ] NO puede update services.
[ ] NO puede delete services.
[ ] NO obtiene acceso a Secrets.
```

- {% include step_label.html %} Aplica nuevamente el manifiesto del Role después de realizar el cambio.

### Pistas permitidas

Puedes apoyarte en:

```text
kubectl get role ... -o yaml
kubectl describe role
kubectl apply -f role-reader.yaml
apiGroups: [""]
resources:
verbs:
```

> **IMPORTANTE:** No resuelvas el problema agregando `resources: ["*"]`, `verbs: ["*"]`, `cluster-admin`, ClusterRole o ClusterRoleBinding. El objetivo es aplicar mínimo privilegio.
{: .lab-note .important .compact}

**Resultado esperado:**

El Role debe conservar sus permisos originales y añadir solamente lectura de Services dentro del namespace `lab8`.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

## ✅ Reto 3. Validar que el ajuste no amplió privilegios innecesarios

**Tiempo sugerido: 6 minutos**

En el último reto debes demostrar que el cambio solucionó el requerimiento sin debilitar el modelo de seguridad.

### Reto 3.1. Verificar los nuevos permisos

- {% include step_label.html %} Comprueba que `app-reader` ahora puede ejecutar `get`, `list` y `watch` sobre Services dentro de `lab8`.

- {% include step_label.html %} Comprueba que la identidad continúa sin permisos para crear o eliminar Services.

### Reto 3.2. Verificar permisos sensibles

- {% include step_label.html %} Confirma que `app-reader` continúa sin poder consultar Secrets.

- {% include step_label.html %} Confirma que continúa sin poder crear Pods.

- {% include step_label.html %} Confirma que el acceso a Pods de `kube-system` continúa denegado.

### Reto 3.3. Validar desde el Pod del Lab 8

- {% include step_label.html %} Comprueba si `rbac-demo-pod` continúa disponible y verifica qué ServiceAccount tiene asignada.

- {% include step_label.html %} Desde el Pod, ejecuta una consulta de Services dentro de `lab8` y confirma que la API ya permite esa operación.

- {% include step_label.html %} Desde el mismo Pod, intenta consultar Secrets para demostrar que Kubernetes continúa respondiendo con `Forbidden`.

### Condiciones para superar el reto

```text
[ ] app-reader puede leer Pods.
[ ] app-reader puede leer ConfigMaps.
[ ] app-reader puede leer Services.
[ ] app-reader no puede crear Services.
[ ] app-reader no puede eliminar Services.
[ ] app-reader no puede leer Secrets.
[ ] app-reader no puede crear Pods.
[ ] app-reader no puede leer Pods de kube-system.
[ ] rbac-demo-pod utiliza app-reader.
```

**Resultado esperado:**

El nuevo requerimiento debe quedar resuelto sin otorgar permisos de escritura, acceso a Secrets ni alcance fuera de `lab8`.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final del reto

- {% include step_label.html %} Ejecuta el bloque siguiente para comprobar las condiciones esenciales después de modificar el Role.

  ```bash
  echo "=== Validacion complementaria 5.1 ==="

  for verb in get list watch; do
    RESULT=$(kubectl auth can-i "$verb" services \
      --as=system:serviceaccount:lab8:app-reader \
      --namespace=lab8)

    echo "app-reader puede $verb services: $RESULT"
  done

  for verb in create delete; do
    RESULT=$(kubectl auth can-i "$verb" services \
      --as=system:serviceaccount:lab8:app-reader \
      --namespace=lab8)

    echo "app-reader puede $verb services: $RESULT"
  done

  echo ""
  echo "Permisos sensibles:"

  kubectl auth can-i get secrets \
    --as=system:serviceaccount:lab8:app-reader \
    --namespace=lab8

  kubectl auth can-i create pods \
    --as=system:serviceaccount:lab8:app-reader \
    --namespace=lab8

  kubectl auth can-i get pods \
    --as=system:serviceaccount:lab8:app-reader \
    --namespace=kube-system

  echo "=== Fin de validacion ==="
  ```

**Resultado esperado:**

```text
app-reader puede get services: yes
app-reader puede list services: yes
app-reader puede watch services: yes
app-reader puede create services: no
app-reader puede delete services: no

Permisos sensibles:
no
no
no
```

> **IMPORTANTE:** Conserva el Role actualizado, el RoleBinding, la ServiceAccount y el namespace `lab8`. No es necesario eliminar estos recursos al finalizar el reto.
{: .lab-note .important .compact}

---

## 🛠️ Resolución de problemas

### Problema 1. get services continúa devolviendo no

**Síntoma:** Después de modificar el Role, `kubectl auth can-i get services` todavía devuelve `no`.

**Causa probable:** El archivo fue editado pero no aplicado, la regla utiliza un resource incorrecto o se modificó un Role diferente.

**Solución:**

Comprueba la configuración efectiva almacenada en Kubernetes.

```bash
kubectl get role pod-configmap-reader -n lab8 -o yaml
kubectl describe role pod-configmap-reader -n lab8
```

Verifica que exista una regla sobre `services` y vuelve a aplicar `role-reader.yaml` si fuera necesario.

---

### Problema 2. app-reader puede crear Services

**Síntoma:** `kubectl auth can-i create services` devuelve `yes` después del ajuste.

**Causa probable:** La regla agregada contiene verbos excesivos, por ejemplo `*`, `create` o un conjunto de permisos más amplio de lo requerido.

**Solución:**

Revisa la regla y conserva solamente permisos de lectura.

```text
get
list
watch
```

Aplica nuevamente el Role y repite las verificaciones.

---

### Problema 3. app-reader puede leer Secrets

**Síntoma:** La comprobación sobre Secrets devuelve `yes`, aunque la práctica principal había definido su acceso como denegado.

**Causa probable:** Existe otro RoleBinding o ClusterRoleBinding que concede permisos adicionales a la ServiceAccount.

**Solución:**

Consulta las vinculaciones del namespace y los permisos efectivos.

```bash
kubectl get rolebindings -n lab8
kubectl auth can-i --list \
  --as=system:serviceaccount:lab8:app-reader \
  --namespace=lab8
```

No elimines recursos hasta identificar exactamente qué binding proporciona el permiso adicional.

---

### Problema 4. rbac-demo-pod ya no existe

**Síntoma:** No puedes realizar la validación desde el Pod porque Kubernetes devuelve `NotFound`.

**Causa probable:** El Pod del Lab 8 fue eliminado después de completar la práctica principal.

**Solución:**

Comprueba que `pod-rbac.yaml` continúe disponible en el directorio del Lab 8 y vuelve a aplicarlo.

```bash
cd /c/LABS/kubernetes/lab8
kubectl apply -f pod-rbac.yaml
kubectl wait --for=condition=Ready pod/rbac-demo-pod \
  -n lab8 \
  --timeout=90s
```

Después repite la validación de permisos desde el contenedor.
