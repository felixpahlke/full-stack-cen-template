#!/usr/bin/env bash

set -e

JSON_MODE=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h) echo "Usage: $0 [--json] <documentation_intent_description>"; exit 0 ;;
        *) ARGS+=("$arg") ;;
    esac
done

DOC_INTENT_DESCRIPTION="${ARGS[*]}"
if [ -z "$DOC_INTENT_DESCRIPTION" ]; then
    echo "Usage: $0 [--json] <documentation_intent_description>" >&2
    exit 1
fi

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

# Resolve repository root. Prefer git information when available, but fall back
# to searching for repository markers so the workflow still functions in repositories that
# were initialised with --no-git.
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

ITERATIONS_DIR="$REPO_ROOT/iterations"
mkdir -p "$ITERATIONS_DIR"

HIGHEST=0
if [ -d "$ITERATIONS_DIR" ]; then
    for dir in "$ITERATIONS_DIR"/*; do
        [ -d "$dir" ] || continue
        dirname=$(basename "$dir")
        number=$(echo "$dirname" | grep -o '^[0-9]\+' || echo "0")
        number=$((10#$number))
        if [ "$number" -gt "$HIGHEST" ]; then HIGHEST=$number; fi
    done
fi

NEXT=$((HIGHEST + 1))
DOC_NUM=$(printf "%03d" "$NEXT")

DOC_NAME=$(echo "$DOC_INTENT_DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//')
WORDS=$(echo "$DOC_NAME" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//')
DOC_NAME="${DOC_NUM}-${WORDS}"

if [ "$HAS_GIT" = true ]; then
    git checkout -b "doc-$DOC_NAME"
else
    >&2 echo "[bobdocs] Warning: Git repository not detected; skipped branch creation for doc-$DOC_NAME"
fi

DOC_DIR="$ITERATIONS_DIR/$DOC_NAME"
mkdir -p "$DOC_DIR"

# Check for a template in multiple locations
TEMPLATE_LOCATIONS=(
    "$REPO_ROOT/templates/bobdocs/intent-template.md"
    "$REPO_ROOT/.bob/templates/intent-template.md"
    "$REPO_ROOT/.specify/templates/intent-template.md"
)

TEMPLATE=""
for loc in "${TEMPLATE_LOCATIONS[@]}"; do
    if [ -f "$loc" ]; then
        TEMPLATE="$loc"
        break
    fi
done

INTENT_FILE="$DOC_DIR/intent.md"
if [ -n "$TEMPLATE" ]; then 
    cp "$TEMPLATE" "$INTENT_FILE"
else 
    # Create a basic template if none exists
    cat > "$INTENT_FILE" << EOF
# Documentation Intent: [DOCUMENTATION NAME]

**Created**: $(date +%Y-%m-%d)  
**Status**: Draft  
**Input**: User description: "$DOC_INTENT_DESCRIPTION"

## Purpose
[Define the primary purpose of this documentation - what it aims to accomplish]

## Target Audience
- **Primary**: [Who is the main audience for this documentation?]
- **Secondary**: [Are there other audiences who might use this documentation?]
- **Technical Level**: [What level of technical expertise does the audience have?]

## Business Value
- [How does this documentation support business goals?]
- [What problems does it solve for the organization?]
- [How does it align with broader strategic objectives?]

## User Needs
- [What specific user problems or questions does this documentation address?]
- [What tasks will users accomplish with this documentation?]
- [What decisions will this documentation help users make?]

## Success Criteria
- [How will we know if this documentation is successful?]
- [What metrics or feedback would indicate success?]
- [What specific outcomes should result from this documentation?]

## Constraints & Requirements
- [Are there any specific constraints or requirements for this documentation?]
- [Are there any compliance, legal, or regulatory considerations?]
- [Are there any technical limitations or dependencies?]

## Notes & Clarifications
- [Any additional context or clarifications needed]
- [Areas that need further discussion or research]
- [NEEDS CLARIFICATION: specific questions]
EOF
fi

# Set the DOC_INTENT environment variable for the current session
export DOC_INTENT="$DOC_NAME"

if $JSON_MODE; then
    printf '{"DOC_NAME":"%s","INTENT_FILE":"%s","DOC_NUM":"%s"}\n' "$DOC_NAME" "$INTENT_FILE" "$DOC_NUM"
else
    echo "DOC_NAME: $DOC_NAME"
    echo "INTENT_FILE: $INTENT_FILE"
    echo "DOC_NUM: $DOC_NUM"
    echo "DOC_INTENT environment variable set to: $DOC_NAME"
fi


