#!/usr/bin/env python3
"""
setup.py — Corre durante o build Docker do Stratechna HR.
Aplica todas as configurações de branding e localização.
"""
import os, re, subprocess, shutil

APP_DIR = "/app"
HORILLA_DIR = f"{APP_DIR}/horilla"
SETTINGS = f"{HORILLA_DIR}/settings.py"
HORILLA_APPS = f"{HORILLA_DIR}/horilla_apps.py"
PT_BR = f"{APP_DIR}/horilla/locale/pt_BR/LC_MESSAGES/django.po"
PT_PT_DIR = f"{APP_DIR}/horilla/locale/pt_PT/LC_MESSAGES"
PT_PT = f"{PT_PT_DIR}/django.po"

# ── 1. WHITE_LABELLING ────────────────────────────────────────────────────────
print("[1/4] A activar WHITE_LABELLING...")
with open(HORILLA_APPS) as f:
    content = f.read()

content = re.sub(r'WHITE_LABELLING\s*=\s*False', 'WHITE_LABELLING = True', content)
if 'WHITE_LABELLING' not in content:
    content += '\n\nWHITE_LABELLING = True\n'

with open(HORILLA_APPS, 'w') as f:
    f.write(content)
print("  WHITE_LABELLING = True ✓")

# ── 2. LANGUAGE_CODE e LANGUAGES ─────────────────────────────────────────────
print("[2/4] A configurar idioma pt-PT...")
with open(SETTINGS) as f:
    settings = f.read()

# LANGUAGE_CODE
settings = re.sub(
    r"LANGUAGE_CODE\s*=\s*['\"][^'\"]*['\"]",
    "LANGUAGE_CODE = 'pt-pt'",
    settings
)

# Adicionar pt-pt e pt-br ao topo da lista LANGUAGES se não existir
if "'pt-pt'" not in settings and '"pt-pt"' not in settings:
    settings = settings.replace(
        "LANGUAGES = (\n",
        "LANGUAGES = (\n    ('pt-pt', 'Português (Portugal)'),\n    ('pt-br', 'Português (Brasil)'),\n"
    )
    print("  pt-pt adicionado às LANGUAGES ✓")
else:
    print("  pt-pt já nas LANGUAGES ✓")

with open(SETTINGS, 'w') as f:
    f.write(settings)
print("  LANGUAGE_CODE = 'pt-pt' ✓")

# ── 3. Criar locale pt_PT ─────────────────────────────────────────────────────
print("[3/4] A criar locale pt_PT...")
os.makedirs(PT_PT_DIR, exist_ok=True)

with open(PT_BR) as f:
    po = f.read()

# Header
po = po.replace('"Language-Team: Portuguese, Brazilian\n"', '"Language-Team: Portuguese, European\n"')
po = po.replace('"Language: pt_BR\n"', '"Language: pt_PT\n"')
po = po.replace('"X-Crowdin-Language: pt-BR\n"', '"X-Crowdin-Language: pt-PT\n"')

# Substituições apenas em linhas msgstr
def replace_in_msgstr(content, old, new):
    lines = content.split('\n')
    result = []
    in_msgstr = False
    for line in lines:
        if line.startswith('msgstr ') or line.startswith('msgstr['):
            in_msgstr = True
            line = line.replace(old, new)
        elif line.startswith('msgid ') or line.startswith('#'):
            in_msgstr = False
        elif in_msgstr and line.startswith('"'):
            line = line.replace(old, new)
        result.append(line)
    return '\n'.join(result)

SUBSTITUICOES = [
    # Pronomes
    ("Você não tem", "Não tem"), ("Você não ", "Não "), ("Você tem ", "Tem "),
    ("Você pode ", "Pode "), ("Você está ", "Está "), ("Você foi ", "Foi "),
    ("Você precisa ", "Precisa "), ("você não tem", "não tem"),
    ("você não ", "não "), ("você tem ", "tem "), ("você pode ", "pode "),
    ("você está ", "está "), ("você foi ", "foi "), ("você precisa ", "precisa "),
    # Terminologia
    ("Usuário", "Utilizador"), ("usuário", "utilizador"),
    ("Usuária", "Utilizadora"), ("usuária", "utilizadora"),
    ("Usuários", "Utilizadores"), ("usuários", "utilizadores"),
    ("Senha", "Password"), ("senha", "password"),
    ("Senhas", "Passwords"), ("senhas", "passwords"),
    ("Celular", "Telemóvel"), ("celular", "telemóvel"),
    ("Smartphone", "Telemóvel"), ("smartphone", "telemóvel"),
    ("E-mail", "Email"),
    ("CEP", "Código Postal"),
    ("Arquivo", "Ficheiro"), ("arquivo", "ficheiro"),
    ("Arquivos", "Ficheiros"), ("arquivos", "ficheiros"),
    ("Excluir", "Eliminar"), ("excluir", "eliminar"),
    ("Deletar", "Eliminar"), ("deletar", "eliminar"),
    ("Salvar", "Guardar"), ("salvar", "guardar"),
    ("Buscar", "Pesquisar"), ("buscar", "pesquisar"),
    ("Recurso", "Funcionalidade"), ("recurso", "funcionalidade"),
    ("Visualização padrão", "Vista predefinida"),
    ("visualização padrão", "vista predefinida"),
    ("Visualização detalhada", "Vista detalhada"),
    ("Posição do trabalho", "Cargo"), ("posição do trabalho", "cargo"),
    ("Holerite", "Recibo de Vencimento"), ("holerite", "recibo de vencimento"),
    ("Contracheque", "Recibo de Vencimento"), ("contracheque", "recibo de vencimento"),
    ("INSS", "Segurança Social"),
    ("Terceirizado", "Subcontratado"), ("terceirizado", "subcontratado"),
]

count = 0
for old, new in SUBSTITUICOES:
    if old != new:
        before = po.count(old)
        po = replace_in_msgstr(po, old, new)
        after = po.count(old)
        n = before - after
        if n > 0:
            count += n

with open(PT_PT, 'w') as f:
    f.write(po)

print(f"  {count} substituições aplicadas ✓")
print(f"  Ficheiro criado: {PT_PT}")

# Compilar .po → .mo
r = subprocess.run(
    ["msgfmt", "-o", f"{PT_PT_DIR}/django.mo", PT_PT],
    capture_output=True, text=True
)
if r.returncode == 0:
    print("  Compilado com msgfmt ✓")
else:
    # Tentar com compilemessages do Django
    r2 = subprocess.run(
        ["python3", "manage.py", "compilemessages", "--locale", "pt_PT"],
        capture_output=True, text=True, cwd=APP_DIR,
        env={**os.environ, "DJANGO_SETTINGS_MODULE": "horilla.settings",
             "SECRET_KEY": "build-key", "DB_ENGINE": "django.db.backends.sqlite3",
             "DB_NAME": "/tmp/build.db"}
    )
    if r2.returncode == 0:
        print("  Compilado com compilemessages ✓")
    else:
        print(f"  AVISO: compilação falhou — {r.stderr[:100]}")

# ── 4. Instalar gettext se necessário (para msgfmt) ───────────────────────────
print("[4/4] A verificar gettext...")
r = subprocess.run(["which", "msgfmt"], capture_output=True, text=True)
if r.returncode == 0:
    print("  gettext disponível ✓")
else:
    print("  gettext não encontrado — adicionar ao Dockerfile")

print("\n=== SETUP CONCLUÍDO ===")
