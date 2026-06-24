#!/usr/bin/env python3
"""
Activar WHITE_LABELLING no horilla_apps.py.
Corre durante o build Docker.
"""
import os, re, subprocess

# Encontrar horilla_apps.py
result = subprocess.run(
    ["find", "/app", "-name", "horilla_apps.py", "-maxdepth", "5"],
    capture_output=True, text=True
)
paths = [p for p in result.stdout.strip().split("\n") if p]

if not paths:
    print("AVISO: horilla_apps.py nao encontrado")
    exit(0)

path = paths[0]
print(f"Encontrado: {path}")

with open(path) as f:
    content = f.read()

# Activar WHITE_LABELLING (nome correcto no Horilla)
if "WHITE_LABELLING" in content:
    content = re.sub(r'WHITE_LABELLING\s*=\s*False', 'WHITE_LABELLING = True', content)
    print("WHITE_LABELLING = True activado ✓")
elif "WHITE_LABEL" in content:
    content = re.sub(r'WHITE_LABEL\s*=\s*False', 'WHITE_LABEL = True', content)
    print("WHITE_LABEL = True activado ✓")
else:
    content += "\n\nWHITE_LABELLING = True\n"
    print("WHITE_LABELLING adicionado ✓")

with open(path, "w") as f:
    f.write(content)

print("patch.py concluido")
