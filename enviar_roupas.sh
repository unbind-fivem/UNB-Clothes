#!/bin/bash

# Remove LFS para forçar o envio via Git normal
echo "⚙️ Removendo Git LFS e .gitattributes..."
git lfs uninstall 2>/dev/null
rm -f .gitattributes

echo "🚀 Iniciando envio inteligente em pedaços de no máximo 700MB..."

# Script em Python embarcado para calcular o tamanho exato dos arquivos e agrupar
python3 -c '
import os
import subprocess

MAX_SIZE = 700 * 1024 * 1024  # 700 MB

print("🔍 Escaneando todos os arquivos da pasta...")
# Usa o comando "find" do Linux que é super rápido (lê 40k arquivos em 1 segundo) em vez do git status
find_cmd = "find . -type f -not -path \"*/.git/*\" -not -name \"enviar_roupas.sh\" -not -name \".gitattributes\""
result = subprocess.run(find_cmd, shell=True, capture_output=True, text=True)

files_to_add = result.stdout.splitlines()

if not files_to_add:
    print("✅ Nenhum arquivo encontrado!")
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
