#!/usr/bin/env bash
# auditor.sh - Script para auditar sockets y procesos
set -euo pipefail

# trap para capturar errores
trap 'echo "Error en linea $LINENO"' ERR

# inventario de sockets con ss 
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

# inventario de procesos correlacionado
echo "timestamp,pid,usuario,comando,cpu_percent,memoria_percent,sockets_relacionados" > $OUT_DIR/processes_inventory.csv

# Temporalmente deshabilitar modo estricto para parsing
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
    cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}' | sed 's/,/ /g')
    
    # Validar que tenemos datos válidos
    
    [[ ! "$pid" =~ ^[0-9]+$ ]] && continue
    
    # buscar sockets del proceso - sudo para acceso completo
    if [[ "$user" == "$USER" ]]; then
        # Proceso propio, no necesita sudo
        sockets_proc=$(ls -la "/proc/$pid/fd" 2>/dev/null | grep -c "socket:" 2>/dev/null)
        [[ -z "$sockets_proc" ]] && sockets_proc="0"
    else
        # Proceso de otro usuario, necesita sudo  
        sockets_proc=$(sudo ls -la "/proc/$pid/fd" 2>/dev/null | grep -c "socket:" 2>/dev/null)
        [[ -z "$sockets_proc" ]] && sockets_proc="0"
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$pid,$user,\"$cmd\",$cpu,$mem,$sockets_proc" >> $OUT_DIR/processes_inventory.csv
done

# Reactivar modo estricto después del parsing
set -e
