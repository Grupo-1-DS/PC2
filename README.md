# Auditor de sockets y procesos: causas raíz con ss, señales y journalctl 

## Tabla de variables

| Variable       | Efecto                                     |
|----------------|-------------------------------------------------|
| RELEASE       | Almacena el número de release del proyecto               |
| OUT_DIR        | Permite generar los artefactos             |
| SRC_DIR     | Permite la ejecución de los scripts de auditoría   |
| DIST_DIR     | Permite distribuir el código del proyecto          |
| TEST_DIR       | Permite ejecutar los tests de validación        |
| TOOLS   | Permite instalar las dependencias del proyecto   |


## Targets disponibles

| Target       | Descripción                                     |
|----------------|-------------------------------------------------|
| ```help```       | Muestra los targets disponibles y su descripción  |
| ```tools```        |Verifica que todas las herramientas necesarias estén instaladas   |
| ```build```     | Prepara el entorno: crea el directorio de salida y da permisos de ejecución a los scripts. |
| ```run```     | Ejecuta el auditor principal ```auditor.sh``` después de construir el entorno.  |
| ```test```       | Permite ejecutar los tests de validación        |
| ```pack```   | Empaqueta el proyecto en un archivo ```.tar.gz``` para distribución.  |
| ```clean```   | Elimina los archivos generados en el directorio de salida  |