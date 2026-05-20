#!/bin/bash

# Envia o arquivo de configuração do LFS primeiro
echo "⚙️ Configurando .gitattributes..."
git add .gitattributes 2>/dev/null
if git status --porcelain .gitattributes | grep -q "^"; then
    git commit -m "chore: setup git lfs"
    git push origin main
fi

# Função para enviar a pasta
send_dir() {
    local dir="$1"
    # Remove a barra final
    dir="${dir%/}"
    
    # Verifica se há arquivos modificados ou novos nessa pasta
    if git status --porcelain "$dir" | grep -q "^"; then
        echo "=========================================="
        echo "📤 Enviando lote: $dir"
        echo "=========================================="
        git add "$dir"
        git commit -m "feat: adiciona pacote de roupas $dir"
        
        # Tenta enviar. Se der erro de conexão, você pode rodar o script de novo e ele continuará de onde parou.
        git push origin main
        
        echo "✅ Lote '$dir' enviado com sucesso!"
        echo ""
    else
        echo "⏩ Pulando '$dir' (já enviado ou sem alterações)"
    fi
}

# Itera sobre todas as pastas na raiz
for folder in */; do
    # Verifica se a pasta existe (evita falha se estiver vazia)
    [ -d "$folder" ] || continue

    # Se o nome da pasta começar com '[' (ex: [eup], [zpack_pack])
    # Entra nela e envia as subpastas uma por uma para dividir bem o tamanho
    if [[ "$folder" == [* ]]; then
        for subfolder in "$folder"*/; do
            [ -d "$subfolder" ] || continue
            send_dir "$subfolder"
        done
    else
        # Se for uma pasta normal (ex: eyes_pack), envia ela inteira
        send_dir "$folder"
    fi
done

# Envia o que sobrar (arquivos soltos na raiz se houver)
echo "🔍 Verificando arquivos restantes..."
git add .
if git status --porcelain | grep -q "^"; then
    git commit -m "chore: atualiza arquivos finais restantes"
    git push origin main
fi

echo "🚀🚀🚀 Tudo finalizado! Todas as pastas foram enviadas para o GitHub!"
