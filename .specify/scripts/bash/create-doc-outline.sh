#!/usr/bin/env bash

# Create documentation outline for BobDocs workflow
#
# This script initializes the outline phase by creating an outline.md file
# in the iterations directory for the current documentation branch.
#
# Usage: ./create-doc-outline.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --help, -h          Show help message

set -e

# Parse command line arguments
JSON_MODE=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: create-doc-outline.sh [OPTIONS]

Create documentation outline for BobDocs workflow.

OPTIONS:
  --json              Output in JSON format
  --help, -h          Show this help message

EXAMPLES:
  # Create outline in JSON mode
  ./create-doc-outline.sh --json
  
  # Create outline with text output
  ./create-doc-outline.sh
  
EOF
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Function to find the repository root by searching for existing project markers
find_repo_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] || [ -d "$dir/.specify" ] || [ -d "$dir/.bob" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Get current documentation branch/directory
get_current_doc() {
    # First check if DOC_INTENT environment variable is set
    if [[ -n "${DOC_INTENT:-}" ]]; then
        echo "$DOC_INTENT"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        local branch=$(git rev-parse --abbrev-ref HEAD)
        # Remove 'doc-' prefix if present
        echo "${branch#doc-}"
        return
    fi

    # For non-git repos, try to find the latest doc directory
    local repo_root=$(find_repo_root "$(pwd)")
    local iterations_dir="$repo_root/iterations"

    if [[ -d "$iterations_dir" ]]; then
        local latest_doc=""
        local highest=0

        for dir in "$iterations_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_doc=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_doc" ]]; then
            echo "$latest_doc"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    HAS_GIT=true
else
    REPO_ROOT="$(find_repo_root "$SCRIPT_DIR")"
    if [ -z "$REPO_ROOT" ]; then
        echo "Error: Could not determine repository root. Please run this script from within the repository." >&2
        exit 1
    fi
    HAS_GIT=false
fi

cd "$REPO_ROOT"

# Get current documentation name
CURRENT_DOC=$(get_current_doc)

if [[ -z "$CURRENT_DOC" ]] || [[ "$CURRENT_DOC" == "main" ]]; then
    echo "ERROR: Not in a documentation branch or DOC_INTENT not set" >&2
    echo "Run /bobdocs.intent first to create a documentation intent." >&2
    exit 1
fi

# Set up paths
ITERATIONS_DIR="$REPO_ROOT/iterations"
DOC_DIR="$ITERATIONS_DIR/$CURRENT_DOC"
OUTLINE_FILE="$DOC_DIR/outline.md"
INTENT_FILE="$DOC_DIR/intent.md"

# Verify documentation directory exists
if [[ ! -d "$DOC_DIR" ]]; then
    echo "ERROR: Documentation directory not found: $DOC_DIR" >&2
    echo "Run /bobdocs.intent first to create the documentation structure." >&2
    exit 1
fi

# Verify intent file exists
if [[ ! -f "$INTENT_FILE" ]]; then
    echo "ERROR: Intent file not found: $INTENT_FILE" >&2
    echo "Run /bobdocs.intent first to create the documentation intent." >&2
    exit 1
fi

# Check for outline template in multiple locations
TEMPLATE_LOCATIONS=(
    "$REPO_ROOT/templates/bobdocs/outline-template.md"
    "$REPO_ROOT/.bob/templates/outline-template.md"
    "$REPO_ROOT/.specify/templates/outline-template.md"
)

TEMPLATE=""
for loc in "${TEMPLATE_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        TEMPLATE="$loc"
        break
    fi
done

# Create outline file
if [ -n "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$OUTLINE_FILE"
else
    # Create a basic outline template if none exists
    cat > "$OUTLINE_FILE" << EOF
# Documentation Outline: [DOCUMENTATION NAME]

**Created**: $(date +%Y-%m-%d)  
**Status**: Draft  
**Based on**: intent.md

## Document Structure

### 1. Introduction
- Purpose and scope
- Target audience
- How to use this document

### 2. [Main Section 1]
- [Subsection 1.1]
- [Subsection 1.2]

### 3. [Main Section 2]
- [Subsection 2.1]
- [Subsection 2.2]

### 4. [Main Section 3]
- [Subsection 3.1]
- [Subsection 3.2]

### 5. Conclusion
- Summary of key points
- Next steps
- Additional resources

## Content Requirements

### Required Elements
- [ ] Clear introduction explaining purpose
- [ ] Logical section organization
- [ ] Appropriate depth for target audience
- [ ] Examples and illustrations where needed
- [ ] Conclusion with actionable takeaways

### Optional Elements
- [ ] Glossary of terms
- [ ] Appendices for detailed information
- [ ] References and citations
- [ ] Index for longer documents

## Notes
- This outline should be refined based on the intent document
- Sections can be added, removed, or reorganized as needed
- Each section should have a clear purpose aligned with user needs
EOF
fi

# Output results
if $JSON_MODE; then
    printf '{"DOC_NAME":"%s","OUTLINE_FILE":"%s","INTENT_FILE":"%s","DOC_DIR":"%s"}\n' \
        "$CURRENT_DOC" "$OUTLINE_FILE" "$INTENT_FILE" "$DOC_DIR"
else
    echo "DOC_NAME: $CURRENT_DOC"
    echo "OUTLINE_FILE: $OUTLINE_FILE"
    echo "INTENT_FILE: $INTENT_FILE"
    echo "DOC_DIR: $DOC_DIR"
fi

