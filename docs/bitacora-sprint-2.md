# Sprint 2 - Simulación de fallos y análisis de incidentes

## Funcionalidades implementadas

En este sprint extendimos el auditor para incluir capacidades avanzadas de análisis de incidentes y simulación controlada de fallos.

### Simulación de fallos con señales

Implementamos un sistema de simulación controlada que puede enviar diferentes tipos de señales a procesos:

- **SIGTERM**: Terminación elegante de procesos
- **SIGINT**: Interrupción (equivalente a Ctrl+C)
- **SIGKILL**: Terminación forzada (no puede ser ignorada)

### Análisis de journalctl

El sistema ahora consulta los logs del sistema usando `journalctl` para detectar patrones de incidentes comunes:

#### Tipos de incidentes detectados

1. **Bind address en uso**: Detección de conflictos de puerto
   - Busca: "Address already in use"
   - Extrae: proceso y puerto involucrado
   - Acción: verificar procesos usando el puerto

2. **Permisos insuficientes**: Problemas de autorización
   - Busca: "Permission denied"
   - Extrae: proceso afectado
   - Acción: revisar permisos de usuario y grupo

3. **Caídas de procesos**: Fallos inesperados
   - Busca: "segfault", "crashed", "killed", "terminated"
   - Extrae: proceso que falló
   - Acción: revisar logs detallados y core dumps

4. **Fallos de conexión**: Problemas de red
   - Busca: "Connection refused", "Connection reset", "Network unreachable"
   - Extrae: proceso con problemas de conectividad
   - Acción: verificar conectividad y firewall

### Correlación de sockets y procesos

El sistema correlaciona la información de inventarios con patrones problemáticos:

- **Procesos con muchos sockets**: Detecta posibles memory leaks de conexiones (>20 sockets)
- **Alto CPU + muchos sockets**: Identifica procesos sobrecargados que pueden necesitar optimización
- **Patrones temporales**: Correlaciona eventos en el tiempo para identificar causas raíz

### Clasificación de incidentes

Cada incidente detectado se clasifica con:

- **Timestamp**: Momento exacto de detección
- **Tipo de incidente**: Categorización del problema
- **PID y proceso**: Identificación del proceso involucrado
- **Puerto**: Si aplica, puerto asociado al problema
- **Descripción**: Explicación del incidente
- **Causa raíz**: Diagnóstico de la causa fundamental
- **Acción recomendada**: Pasos específicos para resolver el problema

### Archivos de salida Sprint 2

#### `incidentes.csv`

Bitácora completa de todos los incidentes detectados con estructura:

```csv
timestamp,tipo_incidente,pid,proceso,puerto,descripcion,causa_raiz,accion_recomendada
```

### Variables de configuración

El sistema ahora admite configuración por variables de entorno:

- `ANALISIS_TIMEFRAME`: Ventana de tiempo para análisis (default: "5 minutes ago")
- `SIMULACION_ENABLED`: Habilitar simulaciones (default: false)
- `JOURNALCTL_PRIORITY`: Nivel de prioridad de logs (default: warning)
- `INCIDENTES_THRESHOLD`: Umbral de sockets para alertas (default: 20)

### Consideraciones de seguridad

- Las simulaciones están deshabilitadas por defecto
- Solo se simulan fallos en procesos del usuario actual
- Verificación explícita de procesos de prueba antes de simular
- Manejo de errores robusto para evitar fallos del sistema

### Testing

El Sprint 2 incluye:

- Tests específicos para todas las nuevas funcionalidades
- Tests negativos para verificar manejo de errores
- Verificación de seguridad en simulaciones
- Tests de integridad de archivos de salida
