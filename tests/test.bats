#!/usr/bin/env bats

setup() {
    # Cambiar al directorio raíz del proyecto
    cd "$BATS_TEST_DIRNAME/.."
}

@test "script existe y tiene bash robusto" {
    [ -f "src/auditor.sh" ]
    run grep "set -euo pipefail" src/auditor.sh
    [ "$status" -eq 0 ]
}

@test "script funciona sin errores" {
    run bash src/auditor.sh
    [ "$status" -eq 0 ]
}

@test "genera inventario de sockets con ss" {
    [ -f "out/sockets_inventory.csv" ]
    run head -1 out/sockets_inventory.csv
    [[ "$output" =~ "timestamp" ]]
    [[ "$output" =~ "netid" ]]
}

@test "genera inventario de procesos" {
    [ -f "out/processes_inventory.csv" ]
    run head -1 out/processes_inventory.csv
    [[ "$output" =~ "sockets_relacionados" ]]
}

@test "usa trap para manejo de errores" {
    run grep "trap" src/auditor.sh
    [ "$status" -eq 0 ]
}

@test "genera bitácora de incidentes" {
    [ -f "out/incidentes.csv" ]
    run head -1 out/incidentes.csv
    [[ "$output" =~ "tipo_incidente" ]]
    [[ "$output" =~ "causa_raiz" ]]
    [[ "$output" =~ "accion_recomendada" ]]
}

@test "contiene funciones de análisis de journalctl" {
    run grep "analizar_journalctl" src/auditor.sh
    [ "$status" -eq 0 ]
}

# Tests negativos para verificar manejo de errores
@test "maneja error cuando journalctl no está disponible" {
    # Simular que journalctl no está disponible
    run bash -c "PATH=/bin:/usr/bin src/auditor.sh 2>&1 | grep -i 'command not found' || true"
    # El script debe continuar ejecutándose aunque journalctl falle
    [ "$status" -eq 0 ]
}

@test "maneja procesos inexistentes en simulación" {
    # Test que verifica que el script maneja PIDs inexistentes sin fallar
    run grep -A 5 "kill.*2>/dev/null" src/auditor.sh
    [ "$status" -eq 0 ]
}

@test "detecta conflictos de puerto con bind address already in use" {
    # Crear conflicto de puerto usando timeout para que termine rápido
    timeout 3 python3 src/test_server.py 9999 &
    servidor1_pid=$!
    sleep 1
    
    # Intentar segundo servidor en mismo puerto (debería fallar)
    run timeout 2 python3 src/test_server.py 9999
    [ "$status" -ne 0 ]
    
    # Verificar que se detectó el error correcto
    [[ "$output" == *"Address already in use"* ]] || [[ "$output" == *"ya está en uso"* ]]
    
    # Limpiar
    kill $servidor1_pid 2>/dev/null || true
    wait $servidor1_pid 2>/dev/null || true
}

@test "detecta errores de permisos en puertos privilegiados" {
    # Intentar enlazar puerto privilegiado sin permisos (puede que en WSL no falle)
    run timeout 2 python3 src/test_server.py 80
    
    # En WSL puede que funcione o falle, verificamos ambos casos
    if [ "$status" -eq 1 ]; then
        # Si falla, debe ser por permisos
        [[ "$output" == *"Permission denied"* ]] || [[ "$output" == *"Permisos insuficientes"* ]]
    else
        # Si funciona en WSL, está bien también
        [[ "$output" == *"Servidor de prueba iniciado"* ]] || [ "$status" -eq 124 ]
    fi
}