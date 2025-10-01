# Sprint 1 - Auditor de Sockets y Procesos

## Lo que se tiene hasta ahora

En este primer sprint desarrollamos un script que permite la generación del informe de los sockets y procesos del sistema. La herramienta extrae información detallada y la organiza en archivos CSV.

### Script principal

Creamos el `auditor.sh` que es script principal del  proyecto. Le agregamos:

- Manejo robusto de errores con `set -euo pipefail` para que se pare si algo sale mal
- Un `trap` que captura errores y nos dice en qué línea falló.
- Generación de inventarios en formato CSV.

### Inventario de sockets

Integramos el comando `ss` en el script y ahora:

- Extrae toda la info de sockets TCP y UDP que están activos
- Guarda timestamp, protocolo, estado, direcciones local/remota, puertos
- También trata de relacionar cada socket con el proceso que lo tiene abierto

### Inventario de procesos correlacionado  

Acá usamos `ps aux` para sacar la lista de procesos y después hacemos una correlación con los sockets:

- Por cada proceso sacamos PID, usuario, comando, uso de CPU y memoria
- Además de eso contamos cuántos sockets tiene relacionados cada proceso
- Esto sirve para que después se pueda detectar procesos sospechosos o con muchas conexiones

### Sistema de testing

Implementamos tests con BATS que verifican:

- Que el script existe y tiene el manejo robusto de errores
- Que ejecuta sin problemas
- Que genera los archivos CSV con los headers correctos
- Que el inventario de procesos incluye la correlación con sockets
- Que usa `trap` para manejo de errores

## Makefile y comandos

**`make run`**: ejecuta el auditor principal y genera todos los inventarios en el directorio `out/`

**`make test`**: corre los tests para verificar que todo funciona

**`make clean`**: limpia los archivos generados

**`make help`**: muestra todos los comandos disponibles con sus descripciones

**`make tools`**: verifica que tengamos instaladas todas las herramientas necesarias (`ss`, `journalctl`)

## Archivos que se generan

Cuando ejecutás el auditor se crean estos archivos en `out/`:

### `sockets_inventory.csv`

Listado completo de todos los sockets activos con:

- Timestamp de cuándo se capturó
- Protocolo (TCP/UDP)  
- Estado (LISTEN, ESTABLISHED)
- Direcciones y puertos local/remoto
- Proceso asociado si se puede determinar

### `processes_inventory.csv`

Inventario de procesos con correlación:

- Info básica del proceso (PID, usuario, comando)
- Uso de CPU y memoria
- Cantidad de sockets relacionados
