# Sprint 3 - Optimización, Testing Avanzado y Documentación

### Testing exhaustivo y validación

Expandimos significativamente la suite de tests:

#### Tests de conflictos de red

- **Conflictos de puerto**: Validamos detección de "Address already in use"
- **Permisos de puerto**: Verificamos manejo de puertos privilegiados en WSL
- **Timeouts inteligentes**: Usamos `timeout` para evitar procesos colgados
- **Limpieza automática**: Los tests limpian procesos creados automáticamente

#### Tests de robustez

- **Manejo de procesos inexistentes**: Verificamos que el script maneja PIDs inválidos
- **Disponibilidad de journalctl**: Validamos funcionamiento cuando `journalctl` no está disponible
- **Formato de archivos**: Verificamos que todos los CSV tienen headers correctos
- **Integridad de datos**: Validamos que no hay corrupción en los archivos generados

### Simplificación del Makefile

Limpiamos y optimizamos los targets:

#### Estructura simplificada

- **Dependencias claras**: `build` depende de `tools`, `run` depende de `build`
- **Variables exportadas**: Todas las configuraciones disponibles para scripts
- **Targets específicos**: Comandos especializados para diferentes escenarios

#### Nuevos targets operativos

- **`make pack`**: Preparación para distribución del auditor completo

### Optimización del servidor de testing

Mejoramos `test_server.py` para testing más robusto:

#### Manejo de errores específicos

- **Detección de conflictos**: Mensajes claros para "Address already in use"
- **Permisos**: Manejo específico de "Permission denied"
- **Configuración flexible**: Soporte para puertos variables via argumentos
- **Logging mejorado**: Mensajes informativos para debugging

#### Integración con tests

- **Procesos controlados**: Creación y limpieza automática de servidores de prueba
- **Timeouts**: Prevención de procesos zombie en los tests
- **Validación de estado**: Verificación de que los servidores iniciaron correctamente

## Consideraciones operativas

### Rendimiento

- El script procesa sistemas con cientos de procesos eficientemente
- Uso mínimo de recursos del sistema durante la ejecución
- Timeouts configurables para evitar bloqueos

### Seguridad

- Operación segura sin permisos elevados (excepto para `sudo ss`)
- Validación de entrada para prevenir inyección de comandos
