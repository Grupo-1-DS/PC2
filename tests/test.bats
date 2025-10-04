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
