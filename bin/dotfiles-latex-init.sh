#!/bin/bash

# Simple LaTeX Project Initialization Script
# Creates basic LaTeX projects from templates/latex/*_template/

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-dotfiles.sh"
TEMPLATES_DIR="$SCRIPT_DIR/../templates/latex"

template_dir_for() {
    local template_type="$1"

    case "$template_type" in
    "default")
        echo "$TEMPLATES_DIR/default_template"
        ;;
    "uio-presentation")
        echo "$TEMPLATES_DIR/uio_presentation_template"
        ;;
    "arxiv-preprint")
        echo "$TEMPLATES_DIR/arxiv_preprint_template"
        ;;
    *)
        return 1
        ;;
    esac
}

show_help() {
    cat <<EOF
LaTeX Project Initialization Script

Usage: $0 [OPTIONS] PROJECT_NAME

Arguments:
    PROJECT_NAME    Name of the project directory to create

Options:
    -t, --type TYPE     Project type: default|uio-presentation|arxiv-preprint
    -d, --directory DIR Target directory (default: current directory)
    --no-git           Skip Git initialization
    -h, --help         Show this help message

Examples:
    $0 -t default my-doc                       # Plain LaTeX article project
    $0 -t uio-presentation my-uio-talk         # UiO presentation project
    $0 -t arxiv-preprint my-paper                # arXiv preprint with versioned sources

Available templates:
    default           - Plain LaTeX article with minimal preamble
    uio-presentation  - University of Oslo official beamer presentation
    arxiv-preprint    - arXiv preprint with arxiv.sty and latexdiff helper
EOF
}

create_project_structure() {
    local project_dir="$1"

    log_info "Creating project structure..."

    # Basic directories
    mkdir -p "$project_dir"/{src,figures,output,aux}

    # Create .gitignore
    cat >"$project_dir/.gitignore" <<'EOF'
# LaTeX auxiliary files
*.aux
*.fdb_latexmk
*.fls
*.log
*.out
*.toc
*.bbl
*.blg
*.bcf
*.run.xml
*.synctex.gz
*.nav
*.snm
*.vrb

# Build directories
aux/
output/

# OS generated files
.DS_Store
Thumbs.db

# Backup files
*~
*.backup
*.bak

# Editor files
.vscode/
*.swp
*.swo
EOF
}

setup_git_repo() {
    local project_dir="$1"
    local project_name="$2"

    log_info "Initializing Git repository..."

    cd "$project_dir"
    git init

    # Set up Git LFS for figures
    git lfs install
    git lfs track "figures/*"
    git lfs track "*.png"
    git lfs track "*.jpg"
    git lfs track "*.jpeg"
    git lfs track "*.pdf"
    git lfs track "*.eps"

    # Add .gitattributes
    git add .gitattributes

    # Initial commit
    git add .
    git commit -m "Initial commit: LaTeX project '$project_name'"

    log_success "Git repository initialized with LFS for figures"
}

push_to_github() {
    local project_name="$1"

    # ensure_cmd exits on failure, so we check first if we want to proceed.
    if ! command -v gum >/dev/null 2>&1 || ! command -v gh >/dev/null 2>&1; then
        log_warning "gum or gh CLI not found. Skipping GitHub push option."
        log_info "Install with: pacman -S gum github-cli"
        return 0
    fi

    local push_choice
    push_choice=$(gum choose \
        "Yes, create and push to GitHub" \
        "No, keep local only" \
        --header "Create GitHub repository and push?") || return 0

    case "$push_choice" in
    "Yes, create and push to GitHub")
        log_info "Creating GitHub repository..."

        local repo_visibility
        repo_visibility=$(gum choose \
            "private" \
            "public" \
            --header "Repository visibility:") || repo_visibility="private"

        # Create GitHub repository
        if gh repo create "$project_name" --"$repo_visibility" --source=. --remote=origin --push; then
            log_success "Repository created and pushed to GitHub!"
            log_info "Repository URL: https://github.com/$(gh api user --jq .login)/$project_name"
        else
            log_error "Failed to create GitHub repository"
        fi
        ;;
    "No, keep local only")
        log_info "Repository kept local only"
        ;;
    esac
}

substitute_project_name() {
    local file="$1"
    local project_name="$2"

    sed -i "s/PROJECT_NAME/$project_name/g" "$file"
}

setup_uio_template() {
    local project_dir="$1"
    local project_name="$2"
    local template_dir
    template_dir="$(template_dir_for uio-presentation)"

    log_info "Setting up UiO presentation template..."

    if [[ -f "$template_dir/main.tex" && -f "$template_dir/preamble.tex" ]]; then
        cp "$template_dir/main.tex" "$project_dir/src/main.tex"
        cp "$template_dir/preamble.tex" "$project_dir/src/preamble.tex"
        substitute_project_name "$project_dir/src/main.tex" "$project_name"
    else
        log_error "UiO template files not found in $template_dir"
        exit 1
    fi
}

setup_default_template() {
    local project_dir="$1"
    local project_name="$2"
    local template_dir
    template_dir="$(template_dir_for default)"

    log_info "Setting up default plain document template..."

    if [[ -f "$template_dir/main.tex" && -f "$template_dir/preamble.tex" ]]; then
        cp "$template_dir/main.tex" "$project_dir/src/main.tex"
        cp "$template_dir/preamble.tex" "$project_dir/src/preamble.tex"
        substitute_project_name "$project_dir/src/main.tex" "$project_name"
    else
        log_error "Default template files not found in $template_dir"
        exit 1
    fi
}

setup_arxiv_preprint_template() {
    local project_dir="$1"
    local project_name="$2"
    local template_dir
    template_dir="$(template_dir_for arxiv-preprint)"

    log_info "Setting up arXiv preprint template..."

    if [[ -f "$template_dir/v0/main.tex" && -f "$template_dir/v0/arxiv.sty" ]]; then
        cp -r "$template_dir/v0" "$project_dir/src/v0"
        cp "$template_dir/v0/main.tex" "$project_dir/src/main.tex"
        cp "$template_dir/diff.tex" "$project_dir/diff.tex"
        substitute_project_name "$project_dir/src/main.tex" "$project_name"
        substitute_project_name "$project_dir/src/v0/main.tex" "$project_name"
    else
        log_error "arXiv preprint template files not found in $template_dir"
        exit 1
    fi
}

main() {
    local project_name=""
    local template_type="default"
    local target_directory="."
    local init_git=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -t | --type)
            template_type="$2"
            shift 2
            ;;
        -d | --directory)
            target_directory="$2"
            shift 2
            ;;
        --no-git)
            init_git=false
            shift
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$project_name" ]]; then
                project_name="$1"
            else
                log_error "Unknown argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
        esac
    done

    # Validate arguments
    if [[ -z "$project_name" ]]; then
        log_error "Project name is required"
        show_help
        exit 1
    fi

    if ! template_dir_for "$template_type" >/dev/null 2>&1; then
        log_error "Invalid template type: $template_type"
        log_info "Currently available: default, uio-presentation, arxiv-preprint"
        exit 1
    fi

    # Create project
    local project_dir="$target_directory/$project_name"

    if [[ -d "$project_dir" ]]; then
        log_error "Directory $project_dir already exists"
        exit 1
    fi

    log_info "Creating LaTeX project ($template_type): $project_name"
    log_info "Target directory: $project_dir"

    create_project_structure "$project_dir"
    case "$template_type" in
    "uio-presentation")
        setup_uio_template "$project_dir" "$project_name"
        ;;
    "default")
        setup_default_template "$project_dir" "$project_name"
        ;;
    "arxiv-preprint")
        setup_arxiv_preprint_template "$project_dir" "$project_name"
        ;;
    esac

    if [[ "$init_git" == true ]]; then
        setup_git_repo "$project_dir" "$project_name"
        push_to_github "$project_name"
    fi

    log_success "LaTeX project '$project_name' created successfully!"
    log_info "Next steps:"
    log_info "  1. cd $project_dir"
    log_info "  2. nvim src/main.tex"
    log_info "  3. Use ,ll to compile and ,lv to view"

    if [[ "$init_git" == true ]]; then
        log_info "  4. Large figures will be tracked with Git LFS automatically"
    fi

    if [[ "$template_type" == "arxiv-preprint" ]]; then
        log_info "  5. Create src/v1/ when ready to track revisions with diff.tex"
    fi
}

main "$@"
