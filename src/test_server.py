#!/usr/bin/env python3
import socket
import time
import sys
import os
import signal


def signal_handler(signum, frame):
    print(f'Servidor de prueba terminado por señal {signum}')
    sys.exit(0)


# Registrar manejadores de señales
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# Obtener puerto de argumento o usar 8888 por defecto
puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 8888

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    print(f'- Intentando enlazar servidor de prueba en puerto {puerto}...')
    s.bind(('127.0.0.1', puerto))
    s.listen(1)

    print(
        f'- Servidor de prueba iniciado exitosamente en puerto {puerto}, PID: {os.getpid()}')

    # Mantener el servidor corriendo
    time.sleep(30)

except OSError as e:
    if "Address already in use" in str(e):
        print(
            f'ERROR: Puerto {puerto} ya está en uso - esto debería ser detectado por el auditor')
        sys.exit(1)
    elif "Permission denied" in str(e):
        print(
            f'ERROR: Permisos insuficientes para puerto {puerto} - esto debería ser detectado por el auditor')
        sys.exit(1)
    else:
        print(f'ERROR: {e}')
        sys.exit(1)
except Exception as e:
    print(f'Error inesperado en servidor de prueba: {e}')
    sys.exit(1)
finally:
    if 's' in locals():
        s.close()
