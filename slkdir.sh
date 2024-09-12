#!/bin/bash

# Definindo cores ANSI
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
RESET="\033[0m"

# Caminho para armazenar os diretórios criados recentemente
RECENT_DIRS_FILE="$HOME/.recent_dirs"
MAX_RECENT_DIRS=10  # Número máximo de diretórios armazenados

# Função "privada" para converter a string em slug
_slugify() {
    slug=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    slug=$(echo "$slug" | iconv -t ascii//TRANSLIT)
    slug=$(echo "$slug" | sed 's/[[:space:]]\+/-/g')
    slug=$(echo "$slug" | sed 's/[^a-z0-9-]//g')
    slug=$(echo "$slug" | sed 's/-\+/-/g')
    slug=$(echo "$slug" | sed 's/^-//;s/-$//')
    echo "$slug"
}

# Função "privada" para exibir o help com cores
_show_help() {
    echo -e "${BOLD}${YELLOW}Uso:${RESET} ${GREEN}slkdir${RESET} ${BLUE}<nome>${RESET} [${YELLOW}opções${RESET}]"
    echo ""
    echo -e "${BOLD}${YELLOW}Descrição:${RESET}"
    echo -e "  Este comando cria um diretório com nome no formato ${GREEN}slug${RESET}."
    echo ""
    echo -e "${BOLD}${YELLOW}Opções:${RESET}"
    echo -e "  ${GREEN}-c${RESET}, ${GREEN}--cd${RESET}         Acessa o diretório criado automaticamente."
    echo -e "  ${GREEN}--recent${RESET}            Lista os últimos diretórios criados (verifica se ainda existem)."
    echo -e "  ${GREEN}--rename${RESET} <diretório> Renomeia um diretório existente para o formato slug."
    echo -e "  ${GREEN}-h${RESET}, ${GREEN}--help${RESET}       Mostra esta mensagem de ajuda."
    echo ""
    echo -e "${BOLD}${YELLOW}Alias:${RESET} O comando ${GREEN}sluggit${RESET} também pode ser usado para o mesmo comando."
}

# Função "privada" para verificar se os diretórios armazenados ainda existem
_check_existing_dirs() {
    if [[ -f "$RECENT_DIRS_FILE" ]]; then
        # Cria um arquivo temporário para os diretórios válidos
        : > "$RECENT_DIRS_FILE.tmp"
        while IFS= read -r dir; do
            if [[ -d "$dir" ]]; then
                echo "$dir" >> "$RECENT_DIRS_FILE.tmp"
            fi
        done < "$RECENT_DIRS_FILE"

        # Substitui o arquivo original pela lista filtrada
        mv "$RECENT_DIRS_FILE.tmp" "$RECENT_DIRS_FILE"
    fi
}

# Função "privada" para adicionar um diretório à lista de recentes (com limite e verificação de existência)
_add_to_recent_dirs() {
    dir_path=$(realpath "$1")

    # Remove o diretório da lista se ele já estiver presente (para evitar duplicatas)
    grep -v "^$dir_path$" "$RECENT_DIRS_FILE" > "$RECENT_DIRS_FILE.tmp" || true
    mv "$RECENT_DIRS_FILE.tmp" "$RECENT_DIRS_FILE"

    # Adiciona o novo diretório ao topo da lista
    echo "$dir_path" >> "$RECENT_DIRS_FILE"

    # Limita o número de diretórios armazenados
    recent_count=$(wc -l < "$RECENT_DIRS_FILE")
    if [[ $recent_count -gt $MAX_RECENT_DIRS ]]; then
        # Remove os mais antigos (mantém os mais recentes)
        tail -n $MAX_RECENT_DIRS "$RECENT_DIRS_FILE" > "$RECENT_DIRS_FILE.tmp" && mv "$RECENT_DIRS_FILE.tmp" "$RECENT_DIRS_FILE"
    fi
}

# Função principal para criar o diretório slug e acessar se a flag --cd for usada
slkdir() {
    cd_flag=false  # Inicializa a flag como falsa
    last_created_dir=""

    # Verifica se foi solicitado --help ou não há argumentos
    if [[ $# -lt 1 || "$1" == "--help" || "$1" == "-h" ]]; then
        _show_help
        return 0
    fi

    # Processa as flags e argumentos
    while [[ "$1" ]]; do
        case "$1" in
            -c|--cd)
                cd_flag=true
                shift
                ;;
            --recent)
                # Verifica se os diretórios ainda existem e exibe os existentes
                _check_existing_dirs
                if [[ -f "$RECENT_DIRS_FILE" ]]; then
                    echo -e "${YELLOW}Últimos diretórios criados (existentes):${RESET}"
                    cat "$RECENT_DIRS_FILE"
                else
                    echo -e "${RED}Nenhum diretório recente encontrado.${RESET}"
                fi
                return 0
                ;;
            --rename)
                if [[ -d "$2" ]]; then
                    new_name=$(_slugify "$2")
                    mv "$2" "$new_name"
                    echo -e "${GREEN}Diretório renomeado para:${RESET} ${BLUE}$new_name${RESET}"
                else
                    echo -e "${RED}O diretório '$2' não existe.${RESET}"
                fi
                return 0
                ;;
            *)
                folder_name=$(_slugify "$1")

                # Verifica se o diretório já existe
                if [[ -d "$folder_name" ]]; then
                    echo -e "${YELLOW}Aviso:${RESET} O diretório ${BLUE}$folder_name${RESET} já existe."
                else
                    mkdir -p "$folder_name"
                    echo -e "${GREEN}Diretório criado:${RESET} ${BLUE}$folder_name${RESET}"

                    # Armazena o último diretório criado
                    last_created_dir="$folder_name"

                    # Adiciona o diretório completo à lista de recentes
                    _add_to_recent_dirs "$folder_name"
                fi
                shift
                ;;
        esac
    done

    # Se a flag --cd ou -c foi passada, entra no último diretório criado
    if $cd_flag && [[ -n "$last_created_dir" ]]; then
        cd "$last_created_dir" || return 1
        echo -e "${YELLOW}Você entrou no diretório:${RESET} ${BLUE}$last_created_dir${RESET}"
    fi
}

# Alias para `sluggit`, para funcionar da mesma maneira que `slkdir`
alias sluggit='slkdir'
