#!/usr/bin/env bash
# auditor.sh - Script para auditar sockets y procesos
set -euo pipefail

# trap para capturar errores
trap 'echo "Error en linea $LINENO"' ERR

# inventario de sockets con ss
echo "timestamp,protocolo,estado,direccion_local,puerto_local,direccion_remota,puerto_remoto,proceso" > $OUT_DIR/sockets_inventory.csv
ss -tuln -p | grep -v '^Netid' | while read line; do
    if [[ -n "$line" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$line" >> $OUT_DIR/sockets_inventory.csv
    fi
done

# inventario de procesos correlacionado
echo "timestamp,pid,usuario,comando,cpu_percent,memoria_percent,sockets_relacionados" > $OUT_DIR/processes_inventory.csv
ps aux | tail -n +2 | while read user pid cpu mem vsz rss tty stat start time cmd; do
    # buscar sockets del proceso
    sockets_proc=$(ss -tuln -p | grep "pid=$pid" | wc -l || echo "0")
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$pid,$user,$cmd,$cpu,$mem,$sockets_proc" >> $OUT_DIR/processes_inventory.csv
done
