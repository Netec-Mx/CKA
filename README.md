<img src="images/neteclogo (2).png" alt="logo" width="300"/>

# Certified Kubernetes Administration

Este curso proporciona una formación práctica en Kubernetes enfocada en la operación real de clústeres y la resolución de problemas en entornos contenerizados. A lo largo de los capítulos, el participante aprenderá a desplegar y gestionar aplicaciones mediante recursos como Pods, Deployments, Services y volúmenes persistentes, así como a configurar acceso seguro con RBAC y exponer aplicaciones mediante Ingress.

El curso está diseñado con un enfoque hands-on, donde cada bloque teórico se refuerza con prácticas guiadas que simulan escenarios reales de operación. Se abordan además técnicas de diagnóstico y troubleshooting utilizando herramientas como kubectl, preparando al participante para enfrentar situaciones comunes en entornos productivos.

Al finalizar, el alumno será capaz de administrar recursos en Kubernetes, identificar y resolver fallos, y ejecutar tareas similares a las evaluadas en la certificación CKA (Certified Kubernetes Administrator).

## Estructura

- `CapituloXX/README.md`: guía de laboratorio por capítulo.

## Lista de laboratorios

### Capítulo 1

- [Despliegue de una aplicación Node.js en Kubernetes](Capitulo01/README.md#despliegue-de-una-aplicación-nodejs-en-kubernetes)
  - Descripción: Despliegue guiado de una aplicación Node.js en Kubernetes mediante recursos y manifiestos YAML, utilizando kubectl para crear y verificar los recursos.
  - Duración estimada: 67 min
- [Práctica complementaria 1.1: Validación básica con kubectl y manifiestos YAML](Capitulo01/README.md#práctica-complementaria-11-validación-básica-con-kubectl-y-manifiestos-yaml)
  - Descripción: Validación de recursos y manifiestos YAML mediante comandos básicos de kubectl.
  - Duración estimada: 22 min

### Capítulo 2

- [Gestión de Deployments con escalamiento, rolling updates y rollback](Capitulo02/README.md#gestión-de-deployments-con-escalamiento-rolling-updates-y-rollback)
  - Descripción: Gestión de Deployments mediante escalamiento, actualizaciones progresivas y reversión de versiones.
  - Duración estimada: 67 min
- [Práctica complementaria 2.1: Labels, selectors y ReplicaSets](Capitulo02/README.md#práctica-complementaria-21-labels-selectors-y-replicasets)
  - Descripción: Aplicación de labels y selectors para relacionar recursos y validar el comportamiento de ReplicaSets.
  - Duración estimada: 22 min

### Capítulo 3

- [Mantenimiento de nodos y reprogramación de workloads en Kubernetes](Capitulo03/README.md#mantenimiento-de-nodos-y-reprogramación-de-workloads-en-kubernetes)
  - Descripción: Ejecución de tareas de mantenimiento sobre nodos mediante cordon, drain y uncordon, verificando la reprogramación de workloads.
  - Duración estimada: 67 min

### Capítulo 4

- [Gestión de namespaces y despliegue de recursos](Capitulo04/README.md#gestión-de-namespaces-y-despliegue-de-recursos)
  - Descripción: Creación y gestión de namespaces, seguida del despliegue y validación de recursos en espacios de nombres distintos.
  - Duración estimada: 56 min
- [Práctica complementaria 4.1: Separación lógica por ambiente](Capitulo04/README.md#práctica-complementaria-41-separación-lógica-por-ambiente)
  - Descripción: Organización de recursos mediante namespaces para representar una separación lógica por ambiente.
  - Duración estimada: 22 min

### Capítulo 5

- [Configuración de aplicaciones con ConfigMaps, Secrets y RBAC](Capitulo05/README.md#configuración-de-aplicaciones-con-configmaps-secrets-y-rbac)
  - Descripción: Configuración de una aplicación mediante ConfigMaps y Secrets, junto con la definición de acceso mediante ServiceAccounts y RBAC.
  - Duración estimada: 84 min
- [Práctica complementaria 5.1: Validación de permisos con ServiceAccount](Capitulo05/README.md#práctica-complementaria-51-validación-de-permisos-con-serviceaccount)
  - Descripción: Validación de permisos asociados a una ServiceAccount mediante recursos y reglas RBAC.
  - Duración estimada: 22 min

### Capítulo 6

- [Exposición de aplicaciones con Services (ClusterIP, NodePort) e Ingress](Capitulo06/README.md#exposición-de-aplicaciones-con-services-clusterip-nodeport-e-ingress)
  - Descripción: Exposición de aplicaciones mediante Services de tipo ClusterIP y NodePort, además de la configuración de reglas de Ingress.
  - Duración estimada: 78 min
- [Práctica complementaria 6.1: Diagnóstico de Service y endpoints](Capitulo06/README.md#práctica-complementaria-61-diagnóstico-de-service-y-endpoints)
  - Descripción: Diagnóstico de la relación entre Services y endpoints mediante comandos de inspección y validación.
  - Duración estimada: 17 min
- [Práctica complementaria 6.2: Validación de DNS interno](Capitulo06/README.md#práctica-complementaria-62-validación-de-dns-interno)
  - Descripción: Validación de la resolución de nombres y conectividad mediante el DNS interno de Kubernetes.
  - Duración estimada: 17 min

### Capítulo 7

- [Despliegue con almacenamiento persistente usando PVC](Capitulo07/README.md#despliegue-con-almacenamiento-persistente-usando-pvc)
  - Descripción: Despliegue de una aplicación con almacenamiento persistente mediante la definición y asociación de un PersistentVolumeClaim.
  - Duración estimada: 56 min

### Capítulo 8

- [Diagnóstico y resolución de fallos en Pods, Services y DNS](Capitulo08/README.md#diagnóstico-y-resolución-de-fallos-en-pods-services-y-dns)
  - Descripción: Diagnóstico y resolución de fallos en Pods, Services y DNS mediante describe, logs, eventos y comandos de conectividad.
  - Duración estimada: 90 min

### Capítulo 9

- [Resolución de escenarios integrales tipo CKA](Capitulo09/README.md#resolución-de-escenarios-integrales-tipo-cka)
  - Descripción: Resolución de escenarios integrales en tiempo limitado, utilizando kubectl para desplegar, diagnosticar y validar recursos bajo condiciones similares a un examen CKA.
  - Duración estimada: 134 min

---

## 📬 **Contacto y más información**

Si tienes alguna pregunta o necesitas más detalles, no dudes en [contactarnos](mailto:soporte@netec.com). También puedes encontrar más recursos en nuestra [página](https://netec.com).

---

¡Gracias por visitar nuestra plataforma! No olvides revisar todos los laboratorios y comenzar tu viaje de aprendizaje hoy mismo.
