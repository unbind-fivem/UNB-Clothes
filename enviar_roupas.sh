#!/bin/bash
echo "🚀 Iniciando envio inteligente em pedaços de no máximo 700MB..."

# Script em Python embarcado para calcular o tamanho exato dos arquivos e agrupar
python3 -c '
import os
import subprocess

MAX_SIZE = 700 * 1024 * 1024  # 700 MB

print("🔍 Escaneando apenas os arquivos com alterações no git...")
# Executa git status --porcelain -uall -z para listar arquivos modificados, deletados, adicionados ou não rastreados
git_cmd = ["git", "status", "--porcelain", "-uall", "-z"]
result = subprocess.run(git_cmd, capture_output=True, text=True, errors="replace")

items = result.stdout.split("\0")
files_to_add = []
i = 0
while i < len(items):
    item = items[i]
    if not item:
        i += 1
        continue
    
    # Cada entrada tem o formato "XY path"
    # XY são 2 caracteres, seguido por 1 espaço, então o caminho começa no índice 3
    status = item[:2]
    path = item[3:]
    
    # Ignora o próprio script, .gitattributes, envia_roupas.py ou arquivos dentro de .git se aparecerem
    if path in ("enviar_roupas.sh", "envia_roupas.py", ".gitattributes") or "/.git/" in path:
        i += 1
        continue
        
    # Se for renomeado ou copiado, o git status -z retorna o caminho antigo e o novo
    if status[0] in ("R", "C") and i + 1 < len(items):
        dest_path = items[i+1]
        if dest_path and dest_path not in ("enviar_roupas.sh", "envia_roupas.py", ".gitattributes"):
            files_to_add.append(path)
            files_to_add.append(dest_path)
        i += 2
    else:
        if path:
            files_to_add.append(path)
        i += 1

if not files_to_add:
    print("✅ Nenhum arquivo modificado ou novo encontrado no git!")
    exit(0)

print(f"📦 {len(files_to_add)} arquivos encontrados. Calculando os lotes...")

current_batch = []
current_size = 0
batch_number = 1

def send_batch(batch, num, size_mb):
    print("==================================================")
    print(f"📤 Preparando LOTE {num} ({len(batch)} arquivos | ~{size_mb:.1f} MB)...")
    print("==================================================")
    
    # Adiciona de 500 em 500 para evitar o erro de "argument list too long" do sistema operacional
    chunk_size = 500
    for i in range(0, len(batch), chunk_size):
        subprocess.run(["git", "add"] + batch[i:i+chunk_size])
    
    # Tenta fazer o commit
    commit_res = subprocess.run(["git", "commit", "-m", f"feat: upload pacote {num}"])
    
    if commit_res.returncode == 0:
        # Se houve alterações, envia para o GitHub
        print("⏳ Enviando para o GitHub...")
        push = subprocess.run(["git", "push", "origin", "main"])
        if push.returncode != 0:
            print(f"❌ Ocorreu um erro no PUSH do Lote {num}.")
            print("Tente rodar o script novamente para continuar de onde parou.")
            exit(1)
        print(f"✅ Lote {num} enviado com sucesso!\n")
    else:
        # Se não houve alterações (retornou erro de commit vazio), ignora o push
        print(f"⏩ Lote {num} já estava enviado ou sem alterações. Pulando push...\n")

for filepath in files_to_add:
    try:
        size = os.path.getsize(filepath)
    except:
        size = 0
        
    # Se adicionar esse arquivo passar de 700MB, envia o lote atual antes
    if current_size + size > MAX_SIZE and current_batch:
        send_batch(current_batch, batch_number, current_size / (1024*1024))
        current_batch = []
        current_size = 0
        batch_number += 1
        
    current_batch.append(filepath)
    current_size += size

# Envia o último lote (que sobrou)
if current_batch:
    send_batch(current_batch, batch_number, current_size / (1024*1024))

print("🎉🎉🎉 SUCESSO! Todos os lotes foram processados!")
'
