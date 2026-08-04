---
layout: lab
title: "Práctica complementaria 4.1: Separación lógica por ambiente"
permalink: /lab7/lab7/
images_base: /labs/lab7/img
duration: "20 minutos"
objective:
  - Comprobar el aislamiento lógico entre namespaces mediante recursos con nombres equivalentes.
  - Identificar cómo Kubernetes resuelve nombres de Services dentro del namespace actual y entre namespaces.
  - Utilizar nombres DNS completos para acceder a Services ubicados en otros ambientes.
  - Generar una vista global de recursos para auditar la separación lógica del clúster.
prerequisites:
  - Haber completado la Práctica 4 y conservar los namespaces development y production.
  - Tener Docker Desktop y Minikube en ejecución.
  - Tener kubectl configurado contra el clúster correcto.
  - Utilizar Visual Studio Code con Git Bash como terminal integrada.
  - Conservar los Deployments y Services webapp y webapp-svc creados en el Lab 6.
introduction:
  - Esta práctica complementaria se desarrolla como un reto. Utilizarás los ambientes development y production creados anteriormente para demostrar cómo Kubernetes mantiene separados recursos con nombres equivalentes y cómo funciona la resolución DNS entre namespaces. No recibirás una secuencia completa de solución; deberás investigar mediante kubectl, comprobar la comunicación entre ambientes y registrar las evidencias solicitadas.
slug: lab7
lab_number: 7
final_result: >
  Al finalizar el reto habrás demostrado que los namespaces permiten separar lógicamente ambientes que comparten el mismo clúster, que los nombres cortos de Services se resuelven dentro del namespace actual y que el acceso entre namespaces requiere identificar correctamente el nombre DNS del recurso destino.
notes:
  - Esta práctica está diseñada para completarse en 20 minutos y reutiliza los recursos creados en el Lab 6.
  - No elimines los namespaces development ni production antes de comenzar.
  - Puedes utilizar kubectl --help, kubectl explain y comandos de consulta para investigar los recursos.
  - Esta práctica complementaria no incluye prompts de apoyo con IA.
references:
  - text: Namespaces
    url: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
  - text: DNS for Services and Pods
    url: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
  - text: Services
    url: https://kubernetes.io/docs/concepts/services-networking/service/
prev: /lab6/lab6/
next: /lab8/lab8/
---

---
<!-- Aquí comienzan las instrucciones del reto -->

## 🧩 Preparación del reto

En esta práctica reutilizarás los namespaces `development` y `production`, junto con los Deployments y Services creados en el Lab 6.

### 🗂️ Confirmar el entorno de trabajo

- {% include step_label.html %} Abre **Docker Desktop** y confirma que el motor se encuentra activo antes de iniciar las validaciones del reto.

- {% include step_label.html %} Abre **Visual Studio Code**, selecciona **Git Bash** como terminal integrada y ubícate en el directorio utilizado en la práctica anterior.

  ```bash
  cd /c/LABS/kubernetes/lab6
  ```

- {% include step_label.html %} Comprueba que Minikube continúa activo y que los nodos del clúster permanecen disponibles.

  ```bash
  minikube status
  kubectl get nodes
  ```

- {% include step_label.html %} Verifica que los namespaces `development` y `production` continúan en estado `Active`.

  ```bash
  kubectl get namespaces development production
  ```

- {% include step_label.html %} Confirma que en ambos namespaces siguen existiendo el Deployment `webapp` y el Service `webapp-svc`.

  ```bash
  kubectl get deployment,service -n development
  kubectl get deployment,service -n production
  ```

**Resultado esperado:**

Los dos namespaces deben existir y contener recursos independientes con los mismos nombres.

> **IMPORTANTE:** Si alguno de los recursos fue eliminado, vuelve a aplicar únicamente los manifiestos correspondientes del Lab 6 antes de continuar.
{: .lab-note .important .compact}

---

## 🗂️ Reto 1. Demostrar el aislamiento lógico entre ambientes

**Tiempo sugerido: 6 minutos**

En este reto deberás comprobar que `development` y `production` pueden contener recursos con los mismos nombres sin generar conflictos.

### Reto 1.1. Comparar recursos equivalentes

- {% include step_label.html %} Localiza el Deployment `webapp` dentro de ambos namespaces y compara el número de réplicas configurado en cada ambiente.

- {% include step_label.html %} Localiza el Service `webapp-svc` en ambos namespaces y compara las direcciones `ClusterIP` asignadas.

- {% include step_label.html %} Comprueba que los Pods de ambos ambientes pertenecen a namespaces diferentes aunque compartan el label `app=webapp`.

### Evidencias que debes obtener

```text
1. ¿Cuántas réplicas tiene webapp en development?
2. ¿Cuántas réplicas tiene webapp en production?
3. ¿Los dos Services se llaman webapp-svc?
4. ¿Tienen la misma ClusterIP o IPs diferentes?
5. ¿Por qué Kubernetes permite utilizar el mismo nombre en ambos ambientes?
```

### Pistas permitidas

Puedes apoyarte en:

```text
kubectl get deployment
kubectl get services
kubectl get pods
kubectl get ... --all-namespaces
kubectl get ... -o wide
```

**Resultado esperado:**

Debes demostrar que `webapp` y `webapp-svc` existen simultáneamente en `development` y `production` como recursos independientes, con configuraciones y direcciones propias.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r1 %}

---

## 🌐 Reto 2. Comprobar resolución DNS dentro y entre namespaces

**Tiempo sugerido: 8 minutos**

En este reto comprobarás cómo Kubernetes resuelve el nombre corto de un Service dentro del namespace actual y cómo identificar un Service ubicado en otro ambiente.

### Reto 2.1. Crear un Pod temporal de diagnóstico

- {% include step_label.html %} Crea un Pod temporal llamado `dns-test` dentro del namespace `development` utilizando una imagen ligera que permita ejecutar `nslookup`.

### Reto 2.2. Resolver el Service local

- {% include step_label.html %} Desde el Pod `dns-test`, intenta resolver únicamente el nombre corto `webapp-svc`.

- {% include step_label.html %} Identifica a qué namespace pertenece el Service que Kubernetes devuelve al utilizar el nombre corto.

### Reto 2.3. Resolver el Service de production

- {% include step_label.html %} Determina el nombre DNS que permita consultar `webapp-svc` dentro del namespace `production` desde el Pod ubicado en `development`.

- {% include step_label.html %} Comprueba mediante `nslookup` que el nombre utilizado resuelve hacia una dirección diferente de la obtenida para el Service local.

- {% include step_label.html %} Si la herramienta disponible en el Pod lo permite, realiza una solicitud HTTP al Service de `production` para confirmar conectividad interna.

### Preguntas del reto

```text
1. ¿A qué Service apunta el nombre corto webapp-svc desde development?
2. ¿Qué nombre permite identificar webapp-svc dentro de production?
3. ¿Qué diferencia observas entre las direcciones ClusterIP?
4. ¿El namespace crea aislamiento de red por sí mismo?
5. ¿Qué función cumple el DNS interno de Kubernetes en este escenario?
```

### Pistas permitidas

Puedes investigar mediante:

```text
kubectl run
kubectl exec
nslookup
wget
<service>.<namespace>
<service>.<namespace>.svc.cluster.local
```

> **NOTA:** Los namespaces separan lógicamente nombres y políticas, pero no bloquean automáticamente el tráfico de red entre ambientes. El aislamiento de red requiere mecanismos adicionales como NetworkPolicy.
{: .lab-note .info .compact}

**Resultado esperado:**

El nombre corto `webapp-svc` debe resolver al Service de `development`, mientras el Service de `production` debe poder identificarse mediante un nombre que incluya explícitamente su namespace.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r2 %}

---

## 🔎 Reto 3. Auditar la separación lógica del clúster

**Tiempo sugerido: 6 minutos**

En el reto final generarás una vista global para comprobar que los recursos de ambos ambientes permanecen claramente diferenciados dentro del mismo clúster.

### Reto 3.1. Crear una vista global

- {% include step_label.html %} Genera una consulta que muestre los recursos principales de todos los namespaces y localiza únicamente los pertenecientes a `development` y `production`.

- {% include step_label.html %} Comprueba que los nombres repetidos siempre aparecen acompañados por el namespace al utilizar una vista global.

- {% include step_label.html %} Consulta los Services de todos los namespaces y confirma que cada `webapp-svc` conserva su propia dirección interna.

### Reto 3.2. Limpiar el recurso temporal

- {% include step_label.html %} Elimina únicamente el Pod `dns-test` utilizado para diagnóstico, conservando los Deployments, Services y namespaces para futuras prácticas.

### Condiciones para superar el reto

```text
[ ] development y production permanecen Active.
[ ] webapp existe en ambos namespaces.
[ ] webapp-svc existe en ambos namespaces.
[ ] Cada Service posee una ClusterIP diferente.
[ ] El nombre corto resuelve dentro del namespace local.
[ ] El Service remoto se resolvió utilizando su namespace.
[ ] El Pod temporal dns-test fue eliminado.
```

### Pistas permitidas

Puedes apoyarte en:

```text
kubectl get all --all-namespaces
kubectl get services --all-namespaces
kubectl get namespaces --show-labels
kubectl delete pod
```

**Resultado esperado:**

Debes obtener una vista global donde `development` y `production` mantengan recursos claramente separados, incluso cuando Deployments y Services utilicen nombres idénticos.

{% assign results = site.data.task-results[page.slug].results %}
{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Reto finalizado" content=r3 %}

---

## ✅ Validación final del reto

La práctica se considera completada cuando puedes demostrar que los namespaces separan lógicamente los recursos por ambiente y que puedes identificar correctamente Services locales y remotos mediante DNS interno.

### Criterios de éxito

| Criterio | Resultado esperado |
|---|---|
| Namespace development | `Active` |
| Namespace production | `Active` |
| Deployment webapp | Existe en ambos namespaces |
| Service webapp-svc | Existe en ambos namespaces |
| ClusterIP | Diferente para cada Service |
| Nombre corto | Resuelve al Service local |
| Nombre con namespace | Resuelve al Service remoto |
| Pod dns-test | Eliminado al finalizar |

- {% include step_label.html %} Ejecuta las consultas siguientes para conservar evidencia final de los recursos desplegados en ambos ambientes.

  ```bash
  kubectl get deployment,service -n development
  kubectl get deployment,service -n production
  ```

- {% include step_label.html %} Obtén una vista global de los Services para confirmar que las dos instancias `webapp-svc` están diferenciadas por namespace.

  ```bash
  kubectl get services --all-namespaces | grep webapp-svc
  ```

> **IMPORTANTE:** Conserva `development`, `production` y sus aplicaciones. No elimines el clúster Minikube al finalizar esta práctica.
{: .lab-note .important .compact}

---

## 🛠️ Resolución de problemas

### Problema 1. El Pod dns-test no inicia

**Síntoma:** El Pod permanece en `Pending`, `ContainerCreating` o `ImagePullBackOff`.

**Causa probable:** La imagen utilizada para diagnóstico no puede descargarse o el clúster no dispone temporalmente de recursos suficientes.

**Solución:**

Consulta el estado y los eventos del Pod antes de modificar cualquier recurso.

```bash
kubectl get pod dns-test -n development
kubectl describe pod dns-test -n development
```

Si el problema corresponde a descarga de imagen, verifica la conectividad del entorno o utiliza una imagen ya disponible en Minikube.

---

### Problema 2. webapp-svc no resuelve mediante nombre corto

**Síntoma:** `nslookup webapp-svc` falla desde el Pod ubicado en `development`.

**Causa probable:** El Service no existe en `development`, CoreDNS no está disponible o el Pod de diagnóstico no está correctamente iniciado.

**Solución:**

Comprueba primero el Service y CoreDNS.

```bash
kubectl get service webapp-svc -n development
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Después repite la consulta desde el Pod cuando ambos recursos estén disponibles.

---

### Problema 3. El nombre del Service de production resuelve al recurso equivocado

**Síntoma:** La consulta devuelve la misma dirección utilizada por el Service de `development`.

**Causa probable:** Se utilizó únicamente el nombre corto `webapp-svc`, por lo que Kubernetes resolvió el Service perteneciente al namespace local.

**Solución:**

Incluye explícitamente el namespace del destino y vuelve a consultar.

```text
webapp-svc.production
```

También puedes utilizar el FQDN completo:

```text
webapp-svc.production.svc.cluster.local
```

---

### Problema 4. No existe webapp en uno de los namespaces

**Síntoma:** `kubectl get deployment webapp -n development` o `-n production` devuelve `NotFound`.

**Causa probable:** Los recursos del Lab 6 fueron eliminados o el manifiesto correspondiente no fue aplicado.

**Solución:**

Desde el directorio del Lab 6, aplica únicamente el archivo del ambiente faltante.

```bash
cd /c/LABS/kubernetes/lab6
kubectl apply -f deploy-development.yaml
kubectl apply -f deploy-production.yaml
```

Después confirma que los Deployments alcanzan estado disponible antes de continuar con el reto.
