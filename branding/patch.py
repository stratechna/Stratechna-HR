#!/usr/bin/env python3
"""
Activar WHITE_LABEL no horilla_apps.py e configurar nome da app.
Corre durante o build Docker.
"""
import os, re

# Possíveis paths do horilla_apps.py
PATHS = [
    "/app/horilla/horilla_apps.py",
    "/app/horilla_apps.py",
    "/usr/src/horilla/horilla/horilla_apps.py",
]

path = None
for p in PATHS:
    if os.path.exists(p):
        path = p
        break

if not path:
    # Tentar encontrar
    import subprocess
    result = subprocess.run(["find", "/", "-name", "horilla_apps.py", "-maxdepth", "8"],
                           capture_output=True, text=True)
    found = result.stdout.strip().split("\n")
    if found and found[0]:
        path = found[0]

if not path:
    print("AVISO: horilla_apps.py não encontrado — WHITE_LABEL terá de ser activado manualmente")
    exit(0)

print(f"Encontrado: {path}")

with open(path) as f:
    content = f.read()

# Activar WHITE_LABEL
if "WHITE_LABEL" in content:
    content = re.sub(r'WHITE_LABEL\s*=\s*False', 'WHITE_LABEL = True', content)
    content = re.sub(r'WHITE_LABEL\s*=\s*True', 'WHITE_LABEL = True', content)
    print("WHITE_LABEL activado ✓")
else:
    # Adicionar no final
    content += "\n\nWHITE_LABEL = True\n"
    print("WHITE_LABEL adicionado ✓")

with open(path, "w") as f:
    f.write(content)

print("patch.py concluído")
