#!/usr/bin/env bash
# ------------------------------------------------------------
# Script: create_labs.sh
# Descripción:
#   - Crea la estructura base de prácticas Jekyll en labs/labN/.
#   - Crea automáticamente la carpeta img de cada práctica.
#   - Genera el archivo labN.md con la plantilla actualizada.
#   - Configura prev/next de forma automática.
#   - No sobrescribe prácticas existentes.
#   - Mantiene compatibilidad con el modo legacy.
#   - Permite generar labs preparados para tracking con LabControl.
#
# Uso:
#   1) Dar permisos de ejecución (solo la primera vez):
#        chmod +x scripts/create_labs.sh
#
#   2) Crear prácticas en modo legacy:
#        ./scripts/create_labs.sh 5
#
#   3) Crear prácticas con tracking:
#        ./scripts/create_labs.sh 5 terraform-aws-essentials
#
# El segundo argumento es el course_id estable utilizado por LabControl.
#
# Para pruebas puede sobrescribirse ROOT_DIR:
#   ROOT_DIR=labs-test ./scripts/create_labs.sh 2 terraform-aws-essentials
# ------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_GENERATOR="${SCRIPT_DIR}/generate_lab_manifest.mjs"
ID_REGISTRY="${SCRIPT_DIR}/lab_id_registry.mjs"
NORMALIZER="${SCRIPT_DIR}/normalize_course_labs.mjs"
CATALOG_GENERATOR="${SCRIPT_DIR}/generate_course_catalog.mjs"
COURSE_SYNC="${SCRIPT_DIR}/sync_course_catalog.mjs"

ROOT_DIR="${ROOT_DIR:-labs}"
TOTAL_LABS="${1:-}"
COURSE_ID="${2:-}"
SYNC_MODE="${3:-}"
TRACKING_ENABLED="false"
DRY_RUN="false"

if [[ "${SYNC_MODE}" == "--dry-run" ]]; then
  DRY_RUN="true"
elif [[ -n "${SYNC_MODE}" ]]; then
  echo "Error: argumento no reconocido: ${SYNC_MODE}"
  echo "Uso:"
  echo "  $0 <numero_de_labs>"
  echo "  $0 <numero_de_labs> <course_id> [--dry-run]"
  exit 1
fi

if [[ -z "${TOTAL_LABS}" ]]; then
  echo "Uso:"
  echo "  $0 <numero_de_labs>"
  echo "  $0 <numero_de_labs> <course_id> [--dry-run]"
  echo
  echo "Ejemplos:"
  echo "  $0 5"
  echo "  $0 5 terraform-aws-essentials"
  echo "  $0 5 terraform-aws-essentials --dry-run"
  exit 1
fi

if ! [[ "${TOTAL_LABS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: <numero_de_labs> debe ser un entero mayor que 0."
  exit 1
fi

if [[ -n "${COURSE_ID}" ]]; then
  if ! [[ "${COURSE_ID}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "Error: <course_id> debe usar kebab-case."
    echo "Ejemplo válido: terraform-aws-essentials"
    exit 1
  fi

  TRACKING_ENABLED="true"

  if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js es requerido para generar manifiestos de LabControl."
    exit 1
  fi

  if [[ ! -f "${MANIFEST_GENERATOR}" ]]; then
    echo "Error: no se encontró el generador de manifiestos:"
    echo "  ${MANIFEST_GENERATOR}"
    exit 1
  fi

  if [[ ! -f "${ID_REGISTRY}" ]]; then
    echo "Error: no se encontró el registro de identidades:"
    echo "  ${ID_REGISTRY}"
    exit 1
  fi

  if [[ ! -f "${NORMALIZER}" ]]; then
    echo "Error: no se encontró el normalizador:"
    echo "  ${NORMALIZER}"
    exit 1
  fi

  if [[ ! -f "${CATALOG_GENERATOR}" ]]; then
    echo "Error: no se encontró el generador de catálogo:"
    echo "  ${CATALOG_GENERATOR}"
    exit 1
  fi

  if [[ ! -f "${COURSE_SYNC}" ]]; then
    echo "Error: no se encontró el cliente de sincronización:"
    echo "  ${COURSE_SYNC}"
    exit 1
  fi
fi

mkdir -p "${ROOT_DIR}"

echo
echo "Configuración:"
echo "  Directorio: ${ROOT_DIR}"
echo "  Labs: ${TOTAL_LABS}"

if [[ "${TRACKING_ENABLED}" == "true" ]]; then
  echo "  Tracking: habilitado"
  echo "  Course ID: ${COURSE_ID}"
else
  echo "  Tracking: legacy"
fi

echo

if [[ "${TRACKING_ENABLED}" == "true" ]]; then
  echo "Registrando identidades existentes del curso..."

  shopt -s nullglob

  for existing_file in "${ROOT_DIR}"/lab*/lab*.md; do
    existing_course_id="$(
      sed -n 's/^course_id:[[:space:]]*//p' "${existing_file}" |
        head -n 1 |
        tr -d '\r'
    )"

    existing_lab_id="$(
      sed -n 's/^lab_id:[[:space:]]*//p' "${existing_file}" |
        head -n 1 |
        tr -d '\r'
    )"

    if [[
      "${existing_course_id}" == "${COURSE_ID}" &&
      "${existing_lab_id}" =~ ^l[0-9]{3}$
    ]]; then
      node "${ID_REGISTRY}"         register         "${COURSE_ID}"         "${existing_lab_id}"         >/dev/null
    fi
  done

  shopt -u nullglob
fi

for i in $(seq 1 "${TOTAL_LABS}"); do
  LAB_DIR="${ROOT_DIR}/lab${i}"
  IMG_DIR="${LAB_DIR}/img"
  MD_FILE="${LAB_DIR}/lab${i}.md"

  echo "Creando estructura para ${LAB_DIR}..."
  mkdir -p "${IMG_DIR}"

  if [[ -f "${MD_FILE}" ]]; then
    echo "  -> ${MD_FILE} ya existe, se deja sin cambios."
    continue
  fi

  if [[ "${i}" -eq 1 ]]; then
    PREV_PATH="/"
  else
    PREV_NUM=$((i - 1))
    PREV_PATH="/lab${PREV_NUM}/lab${PREV_NUM}/"
  fi

  if [[ "${i}" -eq "${TOTAL_LABS}" ]]; then
    NEXT_PATH="/"
  else
    NEXT_NUM=$((i + 1))
    NEXT_PATH="/lab${NEXT_NUM}/lab${NEXT_NUM}/"
  fi

  if [[ "${TRACKING_ENABLED}" == "true" ]]; then
    LAB_TRACKING_ID="$(
      node "${ID_REGISTRY}" next "${COURSE_ID}"
    )"

    printf -v TRACKING_FRONT_MATTER \
      'course_id: %s\nlab_id: %s\ntracking: true\n\n' \
      "${COURSE_ID}" \
      "${LAB_TRACKING_ID}"

    TASK1_TRACKING='{% assign tracking_task_id = "t001" %}'
    TASK2_TRACKING='{% assign tracking_task_id = "t002" %}'
    TASK3_TRACKING='{% assign tracking_task_id = "t003" %}'

    TASK1_STEP1='{% include step_label.html id="s001" %}'
    TASK1_STEP2='{% include step_label.html id="s002" %}'
    TASK1_STEP3='{% include step_label.html id="s003" %}'

    TASK2_STEP1='{% include step_label.html id="s004" %}'
    TASK2_STEP2='{% include step_label.html id="s005" %}'
    TASK2_STEP3='{% include step_label.html id="s006" %}'

    TASK3_STEP1='{% include step_label.html id="s007" %}'
    TASK3_STEP2='{% include step_label.html id="s008" %}'
    TASK3_STEP3='{% include step_label.html id="s009" %}'
  else
    TRACKING_FRONT_MATTER=""

    TASK1_TRACKING=""
    TASK2_TRACKING=""
    TASK3_TRACKING=""

    TASK1_STEP1='{% include step_label.html %}'
    TASK1_STEP2='{% include step_label.html %}'
    TASK1_STEP3='{% include step_label.html %}'

    TASK2_STEP1='{% include step_label.html %}'
    TASK2_STEP2='{% include step_label.html %}'
    TASK2_STEP3='{% include step_label.html %}'

    TASK3_STEP1='{% include step_label.html %}'
    TASK3_STEP2='{% include step_label.html %}'
    TASK3_STEP3='{% include step_label.html %}'
  fi

  cat > "${MD_FILE}" <<EOF
---
layout: lab
${TRACKING_FRONT_MATTER}title: "Práctica ${i}: CAMBIAR_AQUI_NOMBRE_DE_LA_PRACTICA"
permalink: /lab${i}/lab${i}/
images_base: /labs/lab${i}/img
duration: "## minutos"
objective:
  - OBJETIVO_DE_LA_PRACTICA
prerequisites:
  - PREREQUISITO_1
  - PREREQUISITO_2
  - PREREQUISITO_3
  - PREREQUISITO_4
  - PREREQUISITO_X
introduction:
  - INTRODUCCION_DE_LA_PRACTICA_BREVE_RESUMEN_EN_UN_SOLO_PARRAFO_RECOMENDADO
slug: lab${i}
lab_number: ${i}
position: ${i}
final_result: >
  RESULTADO_FINAL_ESPERADO_DE_LA_PRACTICA_EN_UN_SOLO_PARRAFO_RECOMENDADO
notes:
  - NOTAS_CONSIDERACIONES_ADICIONALES
  - NOTAS_CONSIDERACIONES_ADICIONALES
references:
  - text: DESCRIPCION_DEL_LINK_DE_REFERENCIA
    url: https://developer.hashicorp.com/terraform
  - text: DESCRIPCION_DEL_LINK_DE_REFERENCIA
    url: https://learn.microsoft.com/es-es/cli/azure/
prev: ${PREV_PATH}
next: ${NEXT_PATH}
---

---

<!-- Aquí comienzan las instrucciones paso a paso de la práctica -->

## 🔎 Tarea 1. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

${TASK1_TRACKING}

### Tarea 1.1. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK1_STEP1} DESCRIPCION_DEL_PASO_1. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  {% include step_image.html %}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- ${TASK1_STEP2} DESCRIPCION_DEL_PASO_2. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 1.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK1_STEP3} DESCRIPCION_DEL_PASO_3. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% assign results = site.data.task-results[page.slug].results %}
{% capture r1 %}{{ results[0] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r1 %}

{% include support-prompt.html task="tarea1" %}

---

## ☁️ Tarea 2. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

${TASK2_TRACKING}

### Tarea 2.1. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK2_STEP1} DESCRIPCION_DEL_PASO_1. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- ${TASK2_STEP2} DESCRIPCION_DEL_PASO_2. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 2.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK2_STEP3} DESCRIPCION_DEL_PASO_3. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% capture r2 %}{{ results[1] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r2 %}

{% include support-prompt.html task="tarea2" %}

---

## 🚀 Tarea 3. NOMBRE DE LA TAREA — ## min

<!-- DESCRIPCION DE LA TAREA: RECOMENDADO 200-250 CARACTERES -->
DESCRIPCION_DE_LA_TAREA.

${TASK3_TRACKING}

### Tarea 3.1. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK3_STEP1} DESCRIPCION_DEL_PASO_1. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Nota:** NOTA_GENERAL_DEL_PASO.
  {: .lab-note .info .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_1
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_1.
  {: .lab-note .output .compact}

- ${TASK3_STEP2} DESCRIPCION_DEL_PASO_2. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Importante:** CONSIDERACION_IMPORTANTE_DEL_PASO.
  {: .lab-note .important .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_2
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_2.
  {: .lab-note .output .compact}

### Tarea 3.2. NOMBRE_DE_LA_SUBTAREA

<!-- DESCRIPCION DE LA SUBTAREA: RECOMENDADO 120-150 CARACTERES -->
DESCRIPCION_DE_LA_SUBTAREA.

- ${TASK3_STEP3} DESCRIPCION_DEL_PASO_3. <!-- DESCRIPCION DEL PASO: RECOMENDADO 120 CARACTERES -->

  > **Advertencia:** ADVERTENCIA_DEL_PASO.
  {: .lab-note .warning .compact}

  \`\`\`bash
  CODIGO_DEL_PASO_3
  \`\`\`

  > **Salida esperada:** DESCRIPCION_DE_LA_SALIDA_ESPERADA_DEL_PASO_3.
  {: .lab-note .output .compact}

{% capture r3 %}{{ results[2] }}{% endcapture %}
{% include task-result.html title="Tarea finalizada" content=r3 %}

{% include support-prompt.html task="tarea3" %}

---

<!--
======================================================================
GUÍA DE USO DE LA PLANTILLA DEL LABORATORIO
======================================================================

Este archivo es una plantilla base. Las 3 tareas incluidas sirven únicamente
como referencia de estructura. La práctica final puede tener más o menos
tareas, subtareas y pasos según lo requiera el contenido.

---------------------------------------------------------------------
1. FRONT MATTER
---------------------------------------------------------------------

Completa los campos de la cabecera YAML sin cambiar sus nombres:

- title:
    Nombre completo de la práctica.

- duration:
    Duración total estimada de la práctica en minutos.

- objective:
    Objetivo principal de aprendizaje de la práctica.

- prerequisites:
    Requisitos previos necesarios para realizarla.
    Agrega o elimina elementos según corresponda.

- introduction:
    Introducción breve de la práctica. Se recomienda un solo párrafo.

- final_result:
    Resultado final esperado al terminar toda la práctica.
    Se recomienda describirlo en un solo párrafo.

- notes:
    Consideraciones generales que apliquen a toda la práctica.

- references:
    Documentación oficial o referencias técnicas relevantes.
    Mantén la estructura:

      - text: DESCRIPCION
        url: URL

- permalink, images_base, slug y lab_number:
    Son generados automáticamente. No deben modificarse salvo que cambie
    deliberadamente la estructura del sitio.

- prev y next:
    Son generados automáticamente por este script para navegación entre labs.

Cuando el script se ejecuta con un course_id:

  ./scripts/create_labs.sh 5 terraform-aws-essentials

también se generan:

  course_id: terraform-aws-essentials
  lab_id: l001
  tracking: true

Estos campos forman parte del contrato de tracking con LabControl.

IMPORTANTE:

- course_id debe permanecer estable después de publicarse.
- lab_id debe permanecer estable después de publicarse.
- No cambies estos IDs porque cambie el título visible.
- No cambies estos IDs porque cambie la posición del laboratorio.
- No reutilices un ID eliminado para representar otro elemento.

---------------------------------------------------------------------
2. ESTRUCTURA GENERAL DE UNA TAREA
---------------------------------------------------------------------

Cada tarea debe seguir esta estructura:

  ## ICONO Tarea N. NOMBRE DE LA TAREA — ## min

  DESCRIPCION_DE_LA_TAREA.

  ### Tarea N.1. NOMBRE_DE_LA_SUBTAREA

  DESCRIPCION_DE_LA_SUBTAREA.

  - {% include step_label.html %} DESCRIPCION_DEL_PASO.

Cuando tracking está habilitado, cada tarea debe declarar además un
identificador persistente antes de sus subtareas:

  {% assign tracking_task_id = "t001" %}

y cada paso debe utilizar un ID explícito y único:

  - {% include step_label.html id="s001" %} DESCRIPCION_DEL_PASO.

La descripción de la tarea debe explicar qué se realizará y para qué.
Como referencia, se recomiendan aproximadamente 200-250 caracteres.

La descripción de cada subtarea debe indicar claramente el objetivo de esa
sección. Como referencia, se recomiendan aproximadamente 120-150 caracteres.

---------------------------------------------------------------------
3. TAREAS
---------------------------------------------------------------------

Las tareas principales se numeran de forma consecutiva:

  Tarea 1
  Tarea 2
  Tarea 3
  Tarea 4
  ...

La plantilla incluye solamente 3 tareas como ejemplo.

Si la práctica necesita más tareas:

1) Duplica COMPLETA una sección de tarea existente.
2) Cambia el encabezado de la tarea.
3) Cambia la numeración de todas sus subtareas.
4) Cambia el resultado asociado results[N].
5) Cambia el identificador de support-prompt.html.
6) Si tracking está habilitado, asigna un task_id nuevo y no reutilizado.
7) Si tracking está habilitado, asigna step_id nuevos y únicos.

Ejemplo para una Tarea 4:

  ## 🔧 Tarea 4. NOMBRE DE LA TAREA — ## min

Con tracking habilitado:

  {% assign tracking_task_id = "t004" %}

Un paso de esa tarea puede utilizar:

  {% include step_label.html id="s010" %}

Al finalizar debe contener:

  {% capture r4 %}{{ results[3] }}{% endcapture %}
  {% include task-result.html title="Tarea finalizada" content=r4 %}

  {% include support-prompt.html task="tarea4" %}

IMPORTANTE:
El arreglo results utiliza índice base 0:

  Tarea 1 -> results[0]
  Tarea 2 -> results[1]
  Tarea 3 -> results[2]
  Tarea 4 -> results[3]
  Tarea 5 -> results[4]
  Tarea 6 -> results[5]
  Tarea N -> results[N-1]

El número visual de la tarea y su task_id persistente son conceptos
independientes. Si una tarea cambia de posición después de publicarse,
debe conservar su task_id.

---------------------------------------------------------------------
4. SUBTAREAS
---------------------------------------------------------------------

Cada tarea puede contener tantas subtareas como sea necesario.
La numeración debe conservar la relación con la tarea principal.

Ejemplo para la Tarea 4:

  ### Tarea 4.1. PRIMERA SUBTAREA
  ### Tarea 4.2. SEGUNDA SUBTAREA
  ### Tarea 4.3. TERCERA SUBTAREA
  ### Tarea 4.4. CUARTA SUBTAREA

No existe un límite fijo de subtareas.

Las subtareas no requieren actualmente un identificador de tracking
independiente.

---------------------------------------------------------------------
5. PASOS
---------------------------------------------------------------------

Cada acción que debe realizar el participante debe escribirse como un paso
independiente utilizando:

  - {% include step_label.html %} DESCRIPCION_DEL_PASO.

En modo tracking utiliza un ID explícito y único dentro del laboratorio:

  - {% include step_label.html id="s001" %} DESCRIPCION_DEL_PASO.

Ejemplos de IDs:

  s001
  s002
  s003
  s004
  s005

No combines varias acciones importantes dentro de un único paso cuando puedan
realizarse o validarse por separado.

Cada paso debe contener, cuando corresponda:

- Una descripción clara de la acción.
- Una Nota, Importante o Advertencia.
- Una imagen de referencia.
- Un bloque de código o comando.
- Una salida esperada o criterio de validación.

IMPORTANTE PARA TRACKING:

- No renumeres IDs ya publicados.
- No cambies un step_id solamente porque cambió el texto visible.
- No cambies un step_id solamente porque cambió su posición.
- Los pasos nuevos reciben IDs nuevos.
- No reutilices IDs eliminados para representar pasos diferentes.
- El número visual "Paso N." continúa siendo independiente del step_id.

---------------------------------------------------------------------
6. NOTAS, IMPORTANTES Y ADVERTENCIAS
---------------------------------------------------------------------

Usa los bloques obligatoriamente aportando informacion util en cada paso.
Nota, Advertencia, Importante, Siempre ponerla debajo del texto del paso.
Salida esperada, siempr ponerla al finalizar el paso y antes del siguiente paso.

Nota informativa:

  > **Nota:** TEXTO.
  {: .lab-note .info .compact}

Consideración importante:

  > **Importante:** TEXTO.
  {: .lab-note .important .compact}

Advertencia:

  > **Advertencia:** TEXTO.
  {: .lab-note .warning .compact}

Salida esperada:

  > **Salida esperada:** TEXTO.
  {: .lab-note .output .compact}

No es obligatorio incluir los tres tipos de nota en todos los pasos.
Utiliza solamente el que corresponda al contexto.

---------------------------------------------------------------------
7. BLOQUES DE CÓDIGO
---------------------------------------------------------------------

Cada comando o fragmento que el participante deba ejecutar debe tener su
propio bloque de código.

Ejemplo Bash:

  \`\`\`bash
  COMANDO
  \`\`\`

Cambia el identificador del lenguaje cuando corresponda, por ejemplo:

  \`\`\`yaml
  \`\`\`json
  \`\`\`sql
  \`\`\`powershell
  \`\`\`python

Evita colocar varios pasos independientes dentro de un único bloque de código
si deben ejecutarse y validarse por separado.

---------------------------------------------------------------------
8. SALIDA ESPERADA
---------------------------------------------------------------------

Después de un comando o acción importante debe existir una forma clara de
validar que el paso fue realizado correctamente.

Utiliza:

  > **Salida esperada:** DESCRIPCION_DE_LA_VALIDACION.
  {: .lab-note .output .compact}

La salida esperada no necesita reproducir siempre todo el texto del comando.
Puede describir el estado, recurso, valor o comportamiento que debe observarse.

---------------------------------------------------------------------
9. IMÁGENES
---------------------------------------------------------------------

La carpeta de imágenes de esta práctica se encuentra en:

  labs/labN/img/

Para insertar una imagen mediante el mecanismo de la plantilla utiliza:

  {% include step_image.html %}

Conserva este include solamente en los pasos que realmente tengan una imagen.
Si el paso no requiere imagen, elimínalo.

No es necesario agregar una imagen a cada paso.

---------------------------------------------------------------------
10. RESULTADO DE CADA TAREA
---------------------------------------------------------------------

Cada tarea debe terminar con un resultado esperado asociado a
_data/task-results.yml.

La asignación de results debe realizarse una sola vez antes del primer uso:

  {% assign results = site.data.task-results[page.slug].results %}

En esta plantilla se realiza en la Tarea 1.
No es necesario repetir el assign en las tareas siguientes.

Después utiliza el índice correspondiente:

  {% capture r1 %}{{ results[0] }}{% endcapture %}
  {% include task-result.html title="Tarea finalizada" content=r1 %}

Para la Tarea 2:

  {% capture r2 %}{{ results[1] }}{% endcapture %}

Para la Tarea 3:

  {% capture r3 %}{{ results[2] }}{% endcapture %}

Y así sucesivamente.

---------------------------------------------------------------------
11. PROMPT DE SOPORTE
---------------------------------------------------------------------

Después del resultado de cada tarea debe incluirse el prompt de soporte
correspondiente:

  {% include support-prompt.html task="tarea1" %}

La numeración debe coincidir exactamente con la tarea:

  Tarea 1 -> task="tarea1"
  Tarea 2 -> task="tarea2"
  Tarea 3 -> task="tarea3"
  Tarea 4 -> task="tarea4"
  ...

---------------------------------------------------------------------
12. SEPARACIÓN ENTRE TAREAS
---------------------------------------------------------------------

Separa cada tarea principal utilizando:

  ---

No utilices este separador entre pasos o subtareas de la misma tarea.

---------------------------------------------------------------------
13. ICONOS DE LAS TAREAS
---------------------------------------------------------------------

El icono del encabezado es visual y puede cambiarse de acuerdo con el tema de
la tarea. Ejemplos utilizados en esta plantilla:

  🔎  ☁️  🚀

La numeración y el texto "Tarea N." son más importantes que el icono.

El icono no forma parte del contrato de tracking.

---------------------------------------------------------------------
14. QUÉ SE PUEDE ELIMINAR
---------------------------------------------------------------------

Si un elemento no aplica a la práctica puede eliminarse, por ejemplo:

- Prerequisitos adicionales.
- Notas generales.
- Referencias adicionales.
- Una Nota/Importante/Advertencia de un paso.
- {% include step_image.html %} cuando no existe imagen.
- Subtareas que no sean necesarias.
- Tareas de ejemplo que no formen parte de la práctica real.

No elimines los elementos estructurales necesarios para el funcionamiento del
layout, resultados o navegación sin revisar primero su dependencia.

Si tracking está habilitado, tampoco elimines o cambies sin revisar:

- course_id
- lab_id
- tracking
- tracking_task_id
- step_id explícitos ya publicados

---------------------------------------------------------------------
15. VALIDACIÓN FINAL DEL ARCHIVO
---------------------------------------------------------------------

Antes de considerar terminado el laboratorio verifica:

- El título y duración son correctos.
- El objetivo describe claramente el aprendizaje esperado.
- La introducción está completa.
- Todas las tareas están numeradas consecutivamente.
- Todas las subtareas corresponden al número de su tarea.
- Cada acción del participante está separada como paso cuando corresponde.
- Los comandos tienen bloques de código adecuados.
- Los pasos importantes tienen una salida esperada o criterio de validación.
- Los índices results[N] corresponden a cada número de tarea.
- Cada tarea utiliza support-prompt.html con su número correcto.
- Las imágenes utilizadas existen en la carpeta img de la práctica.
- El resultado final describe lo que el participante habrá conseguido.
- Si tracking está habilitado, existen course_id, lab_id y tracking: true.
- Cada tarea rastreable tiene un tracking_task_id estable.
- Cada paso rastreable tiene un step_id explícito y único.
- No se renumeraron ni reutilizaron IDs ya publicados.
- No permanecen textos de marcador como CAMBIAR_AQUI, DESCRIPCION_, NOMBRE_DE_,
  CODIGO_, PREREQUISITO_, RESULTADO_ o ## min en la versión final.

---------------------------------------------------------------------
16. COMPATIBILIDAD LEGACY Y TRACKING
---------------------------------------------------------------------

El script mantiene dos modos de ejecución.

Modo legacy:

  ./scripts/create_labs.sh 5

Este modo conserva el comportamiento histórico y genera pasos con:

  {% include step_label.html %}

No agrega:

  course_id
  lab_id
  tracking
  tracking_task_id
  step_id explícito

Modo tracking:

  ./scripts/create_labs.sh 5 terraform-aws-essentials

Este modo genera automáticamente:

  course_id: terraform-aws-essentials
  lab_id: l001
  tracking: true

También agrega task_id y step_id explícitos para preparar el laboratorio
para su integración con LabControl.

El modo legacy permite seguir utilizando repositorios anteriores sin
migrarlos inmediatamente.

======================================================================
FIN DE LA GUÍA DE USO DE LA PLANTILLA
======================================================================
-->
EOF

  echo "  -> Creado ${MD_FILE}"

  if [[ "${TRACKING_ENABLED}" == "true" ]]; then
    echo "  -> Generando manifiesto LabControl..."

    node "${MANIFEST_GENERATOR}" "${MD_FILE}"
  fi
done

echo
echo "Listo. Se generaron las prácticas en ${ROOT_DIR}/"

if [[ "${TRACKING_ENABLED}" == "true" ]]; then
  echo
  echo "Normalizando estructura y navegación..."

  ROOT_DIR="${ROOT_DIR}"     node "${NORMALIZER}"     "${COURSE_ID}"

  echo
  echo "Generando catálogo público LabControl..."

  ROOT_DIR="${ROOT_DIR}"     node "${CATALOG_GENERATOR}"

  echo
  echo "Los manifiestos LabControl se generaron en .labcontrol/manifests/."
  echo "Las identidades estables quedaron registradas en _data/labcontrol-identities.yml."
  echo "El catálogo público quedó generado en labcontrol/${COURSE_ID}/course.json."

  echo
  echo "Sincronización con LabControl..."

  if [[ "${DRY_RUN}" == "true" ]]; then
    node "${COURSE_SYNC}"       "${COURSE_ID}"       --dry-run
  elif [[
    -n "${LABCONTROL_API_URL:-}" &&
    -n "${LABCONTROL_AUTHORING_SYNC_TOKEN:-}"
  ]]; then
    node "${COURSE_SYNC}"       "${COURSE_ID}"
  elif [[
    -n "${LABCONTROL_API_URL:-}" ||
    -n "${LABCONTROL_AUTHORING_SYNC_TOKEN:-}"
  ]]; then
    echo "Error: configuración incompleta de LabControl."
    echo "Debes definir ambas variables:"
    echo "  LABCONTROL_API_URL"
    echo "  LABCONTROL_AUTHORING_SYNC_TOKEN"
    exit 1
  else
    echo "  -> Omitida: LabControl no está configurado."
    echo "     Define LABCONTROL_API_URL y LABCONTROL_AUTHORING_SYNC_TOKEN"
    echo "     para habilitar la sincronización automática."
  fi
fi
