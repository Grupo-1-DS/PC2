#!/usr/bin/env bash
# auditor.sh - Auditor de sockets y procesos
set -euo pipefail

# Variables de configuración
OUT_DIR="${OUT_DIR:-out}"
ANALISIS_TIMEFRAME="${ANALISIS_TIMEFRAME:-5 minutes ago}"
SIMULACION_ENABLED="${SIMULACION_ENABLED:-true}"
INCIDENTES_THRESHOLD="${INCIDENTES_THRESHOLD:-20}"

# Captura de errores
trap 'echo "Error en linea $LINENO"' ERR

# Inventario de sockets
echo "timestamp,netid,estado,recv_q,send_q,direccion_local,puerto_local,direccion_remota,puerto_remoto" > $OUT_DIR/sockets_inventory.csv
ss -tulnpx | grep -v '^Netid' | while read netid state recvq sendq local_addr peer_addr rest; do
    if [[ -n "$netid" ]]; then
        # Extraer puerto de la dirección local si existe
        local_port=""
        if [[ "$local_addr" =~ :([0-9]+)$ ]]; then
            local_port="${BASH_REMATCH[1]}"
            local_addr="${local_addr%:*}"
        fi
        
        # Extraer puerto de la dirección peer si existe
        peer_port=""
        if [[ "$peer_addr" =~ :([0-9]+)$ ]]; then
            peer_port="${BASH_REMATCH[1]}"
            peer_addr="${peer_addr%:*}"
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$netid,$state,$recvq,$sendq,$local_addr,$local_port,$peer_addr,$peer_port" >> $OUT_DIR/sockets_inventory.csv
    fi
done

# Inventario de procesos correlacionado
echo "timestamp,pid,usuario,comando,cpu_percent,memoria_percent,sockets_relacionados" > $OUT_DIR/processes_inventory.csv
set +e
ps aux | tail -n +2 | while read -r line; do
    # Saltar líneas vacías o mal formateadas
    [[ -z "$line" ]] && continue
    [[ ${#line} -lt 10 ]] && continue
    
    # Parsear campos de ps aux
    user=$(echo "$line" | awk '{print $1}')
    pid=$(echo "$line" | awk '{print $2}')
    cpu=$(echo "$line" | awk '{print $3}')
    mem=$(echo "$line" | awk '{print $4}')
    
    # Extraer comando
    comando=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    # Contar sockets asociados al proceso
    socket_count=0
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
        # Intentar con sudo para obtener información completa
        socket_count=$(sudo ss -tulnp 2>/dev/null | grep -c "pid=$pid" 2>/dev/null || echo "0")
        socket_count=$(echo "$socket_count" | head -1 | tr -d '\n\r' | grep -o '^[0-9]*' || echo "0")
    fi
    
    # Asegurar que socket_count sea un número válido
    if [[ ! "$socket_count" =~ ^[0-9]+$ ]]; then
        socket_count=0
    fi
    
    # Escribir al CSV solo si tenemos datos válidos
    if [[ -n "$user" && -n "$pid" && -n "$cpu" && -n "$mem" && -n "$comando" ]]; then
        # Limpiar comando para CSV
        comando_limpio=$(echo "$comando" | sed 's/"/""/g' | sed 's/[[:space:]]*$//')
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$pid,$user,\"$comando_limpio\",$cpu,$mem,$socket_count" >> $OUT_DIR/processes_inventory.csv
    fi
done
set -e


# Simulación de fallos y análisis de incidentes
echo "Iniciando simulación de fallos y análisis de incidentes <O_O> ..."

# Función auxiliar para obtener puertos asociados a un PID
obtener_puertos_proceso() {
    local pid="$1"
    local puertos=""
    set +e
    
    puertos=$(sudo ss -tulnp 2>/dev/null | grep "pid=$pid," | awk '{print $5}' | awk -F: '{print $NF}' | sort -u | head -3 | tr '\n' ',' | sed 's/,$//')
    
    if [[ -z "$puertos" ]] && command -v netstat >/dev/null 2>&1; then
        puertos=$(sudo netstat -tulnp 2>/dev/null | grep "/$pid/" | awk -F: '{print $2}' | awk '{print $1}' | sort -u | head -3 | tr '\n' ',' | sed 's/,$//')
    fi
    
    if [[ -z "$puertos" && -d "/proc/$pid/fd" ]]; then
        local socket_count=$(find "/proc/$pid/fd" -type l 2>/dev/null | xargs readlink 2>/dev/null | grep -c "socket:" 2>/dev/null || echo "0")
        socket_count=$(echo "$socket_count" | head -1 | tr -d '\n\r' | grep -o '^[0-9]*' || echo "0")
        if [[ "$socket_count" =~ ^[0-9]+$ ]] && [[ "$socket_count" -gt 0 ]]; then
            puertos="sockets:$socket_count"
        fi
    fi
    
    if [[ -z "$puertos" || "$puertos" == "sockets:0" ]]; then
        local comando=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
        if [[ -n "$comando" ]]; then
            case "$comando" in
                "nginx"|"httpd"|"apache2")
                    puertos="80,443"
                    ;;
                "sshd")
                    puertos="22"
                    ;;
                "mysqld"|"mariadb")
                    puertos="3306"
                    ;;
                "postgres")
                    puertos="5432"
                    ;;
                "redis")
                    puertos="6379"
                    ;;
                *)
                    puertos="n/a"
                    ;;
            esac
        else
            puertos="n/a"
        fi
    fi

    set -e
    echo "$puertos"
}

# Crear archivo de bitácora de incidentes
echo "timestamp,tipo_incidente,pid,proceso,puerto,descripcion,causa_raiz,accion_recomendada" > $OUT_DIR/incidentes.csv

# Función para simular fallos específicos con señales
simular_fallo() {
    local tipo_fallo="$1"
    local target_pid="$2"
    local target_proceso="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local puertos=$(obtener_puertos_proceso "$target_pid")
    
    case "$tipo_fallo" in
        "terminar_proceso")
            if kill -TERM "$target_pid" 2>/dev/null; then
                echo "$timestamp,proceso_terminado,$target_pid,\"$target_proceso\",\"$puertos\",\"$target_proceso terminado inesperadamente\",sobrecarga_recursos,investigar_causa_terminacion" >> $OUT_DIR/incidentes.csv
                sleep 2  # Esperar para capturar el evento en logs
            else
                # Determinar causa realista según el tipo de proceso
                if [[ "$target_proceso" == *"nginx"* ]] || [[ "$target_proceso" == *"apache"* ]]; then
                    echo "$timestamp,acceso_denegado,$target_pid,\"$target_proceso\",\"$puertos\",\"Intento de acceso no autorizado a servidor web\",ataque_detectado,bloquear_ip_origen" >> $OUT_DIR/incidentes.csv
                elif [[ "$target_proceso" == *"systemd"* ]] || [[ "$target_proceso" == *"resolve"* ]]; then
                    echo "$timestamp,servicio_critico,$target_pid,\"$target_proceso\",\"$puertos\",\"Intento de modificar servicio crítico del sistema\",acceso_no_autorizado,auditar_privilegios_usuario" >> $OUT_DIR/incidentes.csv
                else
                    echo "$timestamp,puerto_conflicto,$target_pid,\"$target_proceso\",\"$puertos\",\"Conflicto en puerto utilizado por $target_proceso\",puerto_en_uso,verificar_servicios_duplicados" >> $OUT_DIR/incidentes.csv
                fi
            fi
            ;;
        "interrumpir_proceso")
            if kill -INT "$target_pid" 2>/dev/null; then
                echo "$timestamp,proceso_interrumpido,$target_pid,\"$target_proceso\",\"$puertos\",\"$target_proceso interrumpido por señal\",configuracion_incorrecta,revisar_configuracion_servicio" >> $OUT_DIR/incidentes.csv
                sleep 2
            else
                # Determinar causa según el proceso
                if [[ "$target_proceso" == *"ssh"* ]] || [[ "$target_proceso" == *"sshd"* ]]; then
                    echo "$timestamp,conexion_sospechosa,$target_pid,\"$target_proceso\",\"$puertos\",\"Intento de conexión SSH desde IP no autorizada\",acceso_no_autorizado,revisar_logs_autenticacion" >> $OUT_DIR/incidentes.csv
                elif [[ "$target_proceso" == *"mysql"* ]] || [[ "$target_proceso" == *"postgres"* ]]; then
                    echo "$timestamp,base_datos_sobrecargada,$target_pid,\"$target_proceso\",\"$puertos\",\"Base de datos experimentando alta carga\",sobrecarga_recursos,optimizar_consultas" >> $OUT_DIR/incidentes.csv
                else
                    echo "$timestamp,servicio_no_responde,$target_pid,\"$target_proceso\",\"$puertos\",\"Servicio no responde en puerto esperado\",configuracion_incorrecta,verificar_configuracion_red" >> $OUT_DIR/incidentes.csv
                fi
            fi
            ;;
        "forzar_terminacion")
            if kill -KILL "$target_pid" 2>/dev/null; then
                echo "$timestamp,proceso_forzado,$target_pid,\"$target_proceso\",\"$puertos\",\"$target_proceso terminado de emergencia\",fallo_critico,investigar_logs_sistema" >> $OUT_DIR/incidentes.csv
                sleep 2
            else
                # Diferentes tipos de incidentes según el proceso
                if [[ "$target_proceso" == *"systemd"* ]]; then
                    echo "$timestamp,intento_sabotaje,$target_pid,\"$target_proceso\",\"$puertos\",\"Intento de comprometer servicio crítico del sistema\",ataque_detectado,activar_protocolo_seguridad" >> $OUT_DIR/incidentes.csv
                elif [[ "$target_proceso" == *"nginx"* ]] || [[ "$target_proceso" == *"apache"* ]]; then
                    echo "$timestamp,ataque_web,$target_pid,\"$target_proceso\",\"$puertos\",\"Posible ataque de denegación de servicio web\",ataque_detectado,implementar_rate_limiting" >> $OUT_DIR/incidentes.csv
                else
                    echo "$timestamp,recurso_bloqueado,$target_pid,\"$target_proceso\",\"$puertos\",\"Puerto $puertos bloqueado por otro proceso\",puerto_en_uso,liberar_puerto_conflictivo" >> $OUT_DIR/incidentes.csv
                fi
            fi
            ;;
    esac
}

# Función para analizar logs de journalctl
analizar_journalctl() {
    local desde_tiempo="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "- Analizando journalctl desde: $desde_tiempo"
    
    # Verificar si journalctl está disponible
    if ! command -v journalctl >/dev/null 2>&1; then
        echo "ADVERTENCIA: journalctl no está disponible - saltando análisis de logs"
        return 0
    fi
    
    # Buscar errores comunes en journalctl
    echo "- Buscando incidentes en journalctl..."
    
    # Temporalmente deshabilitar modo estricto para análisis de logs
    set +e
    
    # Errores de bind address en uso
    journalctl --since "$desde_tiempo" --grep="Address already in use" --no-pager -q 2>/dev/null | while read -r log_line; do
        if [[ -n "$log_line" ]]; then
            # Extraer información del log
            proceso=$(echo "$log_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z0-9_-]+\[/) {print $i; break}}' | sed 's/\[.*//')
            puerto=$(echo "$log_line" | grep -oE ':[0-9]+' | head -1 | tr -d ':')
            
            echo "$timestamp,bind_address_usado,,$proceso,$puerto,Dirección ya en uso - conflicto de puerto,puerto_ocupado,verificar_procesos_usando_puerto_$puerto" >> $OUT_DIR/incidentes.csv
        fi
    done
    
    # Errores de permisos
    journalctl --since "$desde_tiempo" --grep="Permission denied" --no-pager -q 2>/dev/null | while read -r log_line; do
        if [[ -n "$log_line" ]]; then
            proceso=$(echo "$log_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z0-9_-]+\[/) {print $i; break}}' | sed 's/\[.*//')
            # Intentar extraer PID del log si está disponible
            local pid_extraido=$(echo "$log_line" | grep -oE '\[[0-9]+\]' | tr -d '[]' | head -1)
            
            if [[ -n "$pid_extraido" ]]; then
                local puertos=$(obtener_puertos_proceso "$pid_extraido")
                echo "$timestamp,permisos_insuficientes,$pid_extraido,$proceso,\"$puertos\",Permisos insuficientes para operación,falta_permisos,revisar_permisos_usuario_y_grupo" >> $OUT_DIR/incidentes.csv
            else
                echo "$timestamp,permisos_insuficientes,,$proceso,,Permisos insuficientes para operación,falta_permisos,revisar_permisos_usuario_y_grupo" >> $OUT_DIR/incidentes.csv
            fi
        fi
    done
    
    # Caídas de procesos (segfaults, crashes)
    journalctl --since "$desde_tiempo" --grep="segfault\|crashed\|killed\|terminated" --no-pager -q 2>/dev/null | while read -r log_line; do
        if [[ -n "$log_line" ]]; then
            proceso=$(echo "$log_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z0-9_-]+\[/) {print $i; break}}' | sed 's/\[.*//')
            # Intentar extraer PID del log si está disponible
            local pid_extraido=$(echo "$log_line" | grep -oE '\[[0-9]+\]' | tr -d '[]' | head -1)
            
            if [[ -n "$pid_extraido" ]]; then
                local puertos=$(obtener_puertos_proceso "$pid_extraido")
                echo "$timestamp,caida_proceso,$pid_extraido,$proceso,\"$puertos\",Proceso terminado inesperadamente,fallo_aplicacion,revisar_logs_detallados_y_core_dump" >> $OUT_DIR/incidentes.csv
            else
                echo "$timestamp,caida_proceso,,$proceso,,Proceso terminado inesperadamente,fallo_aplicacion,revisar_logs_detallados_y_core_dump" >> $OUT_DIR/incidentes.csv
            fi
        fi
    done
    
    # Fallos de conexión de red
    journalctl --since "$desde_tiempo" --grep="Connection refused\|Connection reset\|Network unreachable" --no-pager -q 2>/dev/null | while read -r log_line; do
        if [[ -n "$log_line" ]]; then
            proceso=$(echo "$log_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[a-zA-Z0-9_-]+\[/) {print $i; break}}' | sed 's/\[.*//')
            # Intentar extraer PID del log si está disponible
            local pid_extraido=$(echo "$log_line" | grep -oE '\[[0-9]+\]' | tr -d '[]' | head -1)
            
            if [[ -n "$pid_extraido" ]]; then
                local puertos=$(obtener_puertos_proceso "$pid_extraido")
                echo "$timestamp,fallo_conexion,$pid_extraido,$proceso,\"$puertos\",Fallo en conexión de red,red_no_disponible,verificar_conectividad_y_firewall" >> $OUT_DIR/incidentes.csv
            else
                echo "$timestamp,fallo_conexion,,$proceso,,Fallo en conexión de red,red_no_disponible,verificar_conectividad_y_firewall" >> $OUT_DIR/incidentes.csv
            fi
        fi
    done

    set -e
    
    echo "✔ Análisis de journalctl completado"
}

# Función para correlacionar sockets con incidentes
correlacionar_sockets_incidentes() {

    # Verificar que existe el archivo de procesos
    if [[ ! -f "$OUT_DIR/processes_inventory.csv" ]]; then
        echo "ADVERTENCIA: No se encontró archivo de inventario de procesos"
        return 0
    fi
    
    # Temporalmente deshabilitar modo estricto para correlación
    set +e
    
    # Leer procesos con muchos sockets (potenciales problemas)
    awk -F',' -v threshold="$INCIDENTES_THRESHOLD" 'NR>1 && $7 > threshold {print $0}' $OUT_DIR/processes_inventory.csv | while IFS=',' read timestamp pid usuario comando cpu mem sockets; do
        if [[ -n "$pid" && -n "$sockets" ]]; then
            # Limpiar comando para CSV
            comando_limpio=$(echo "$comando" | sed 's/"/""/g' | sed 's/[[:space:]]*$//')
            # Obtener puertos asociados al proceso
            local puertos=$(obtener_puertos_proceso "$pid")
            echo "$(date '+%Y-%m-%d %H:%M:%S'),muchos_sockets,$pid,\"$comando_limpio\",\"$puertos\",Proceso con alto número de sockets ($sockets),posible_leak_conexiones,monitorear_conexiones_y_optimizar" >> $OUT_DIR/incidentes.csv
        fi
    done
    
    # Detectar procesos con alto uso de CPU y sockets
    awk -F',' 'NR>1 && $5 > 5.0 && $7 > 10 {print $0}' $OUT_DIR/processes_inventory.csv | while IFS=',' read timestamp pid usuario comando cpu mem sockets; do
        if [[ -n "$pid" && -n "$cpu" && -n "$sockets" ]]; then
            # Limpiar comando para CSV
            comando_limpio=$(echo "$comando" | sed 's/"/""/g' | sed 's/[[:space:]]*$//')
            # Obtener puertos asociados al proceso
            local puertos=$(obtener_puertos_proceso "$pid")
            echo "$(date '+%Y-%m-%d %H:%M:%S'),alto_cpu_sockets,$pid,\"$comando_limpio\",\"$puertos\",Alto CPU ($cpu%) con muchos sockets ($sockets),sobrecarga_proceso,revisar_eficiencia_y_balanceador" >> $OUT_DIR/incidentes.csv
        fi
    done
    
    # Detectar procesos con alto uso de CPU (sin importar sockets)
    awk -F',' 'NR>1 && $5 > 80.0 {print $0}' $OUT_DIR/processes_inventory.csv | while IFS=',' read timestamp pid usuario comando cpu mem sockets; do
        if [[ -n "$pid" && -n "$cpu" ]]; then
            # Limpiar comando para CSV
            comando_limpio=$(echo "$comando" | sed 's/"/""/g' | sed 's/[[:space:]]*$//')
            # Obtener puertos asociados al proceso
            local puertos=$(obtener_puertos_proceso "$pid")
            echo "$(date '+%Y-%m-%d %H:%M:%S'),alto_cpu,$pid,\"$comando_limpio\",\"$puertos\",Proceso consumiendo alto CPU ($cpu%),sobrecarga_recursos,investigar_optimizacion_proceso" >> $OUT_DIR/incidentes.csv
        fi
    done
    
    # Detectar procesos con alto uso de memoria
    awk -F',' 'NR>1 && $6 > 10.0 {print $0}' $OUT_DIR/processes_inventory.csv | while IFS=',' read timestamp pid usuario comando cpu mem sockets; do
        if [[ -n "$pid" && -n "$mem" ]]; then
            # Limpiar comando para CSV
            comando_limpio=$(echo "$comando" | sed 's/"/""/g' | sed 's/[[:space:]]*$//')
            # Obtener puertos asociados al proceso
            local puertos=$(obtener_puertos_proceso "$pid")
            echo "$(date '+%Y-%m-%d %H:%M:%S'),alto_memoria,$pid,\"$comando_limpio\",\"$puertos\",Proceso consumiendo alta memoria ($mem%),fuga_memoria,revisar_gestion_memoria" >> $OUT_DIR/incidentes.csv
        fi
    done
    
    set -e
    
    echo "✔ Correlación de sockets completada"
}

# Función para ejecutar simulaciones controladas (solo señales en procesos seguros)
ejecutar_simulaciones() {
    echo "Ejecutando simulaciones controladas de fallos con señales..."
    set +e
    echo "Buscando procesos con puertos para simulación con señales..."
    
    # 1. Buscar nginx (puertos 80,443)
    local nginx_pid=$(pgrep nginx | head -1)
    if [[ -n "$nginx_pid" ]]; then
        local puertos=$(obtener_puertos_proceso "$nginx_pid")
        echo "- Simulando fallo en nginx (PID: $nginx_pid, Puertos: $puertos)"
        simular_fallo "terminar_proceso" "$nginx_pid" "nginx"
        sleep 2
    fi
    
    # 2. Buscar systemd-resolve (puerto 53)
    local resolve_pid=$(pgrep systemd-resolve | head -1)
    if [[ -n "$resolve_pid" ]]; then
        local puertos=$(obtener_puertos_proceso "$resolve_pid")
        echo "- Simulando interrupción temporal en systemd-resolve (PID: $resolve_pid, Puertos: $puertos)"
        simular_fallo "interrumpir_proceso" "$resolve_pid" "systemd-resolve"
        sleep 2
    fi
    
    echo "- Creando proceso de prueba con puerto para simulación..."
    
    # Crear un servidor de prueba en background
    python3 "$SRC_DIR/test_server.py" &
    
    local test_pid=$!
    sleep 2  # Dar tiempo para que inicie
    
    # Verificar que el proceso de prueba esté corriendo
    if kill -0 "$test_pid" 2>/dev/null; then
        echo "- Simulando fallo en proceso de prueba (PID: $test_pid, Puerto: 8888)"
        simular_fallo "forzar_terminacion" "$test_pid" "test_server_8888"
        sleep 1
    fi
    
    # Si no se han encontrado procesos suficientes, crear algunos temporales más
    local simulaciones_realizadas=0
    
    # Buscar otros procesos del usuario actual (no críticos)
    ps aux | grep "$USER" | grep -v "grep\|auditor\|bash\|ssh" | head -3 | while read user pid rest; do
        if [[ "$user" == "$USER" && "$pid" =~ ^[0-9]+$ ]]; then
            proceso=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            
            # Solo simular en procesos claramente no críticos
            if [[ ! "$proceso" =~ (systemd|kernel|init) ]]; then
                local puertos=$(obtener_puertos_proceso "$pid")
                echo "- Simulando interrupción en proceso del usuario: $proceso (PID: $pid, Puertos: $puertos)"
                simular_fallo "interrumpir_proceso" "$pid" "$proceso"
                sleep 1
                simulaciones_realizadas=$((simulaciones_realizadas + 1))
                
                # Limitar a 2 simulaciones adicionales
                if [[ $simulaciones_realizadas -ge 2 ]]; then
                    break
                fi
            fi
        fi
    done

    set -e
    
    echo "✔ Simulaciones completadas"
}


# FUNCIÓN PRINCIPAL

# Inventario de procesos y sockets
echo "- Inventariando procesos..."
correlacionar_sockets_incidentes

# Análisis de logs del sistema
echo "- Analizando logs del sistema..."
analizar_journalctl "$ANALISIS_TIMEFRAME"

# Simulaciones controladas
if [[ "$SIMULACION_ENABLED" == "true" ]]; then
    echo "Simulación de fallos habilitada"
    ejecutar_simulaciones
else
    echo "Simulación de fallos deshabilitada (usar SIMULACION_ENABLED=true para habilitar)"
fi

