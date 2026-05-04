#!/usr/bin/env bash

# Setup script for the BobDocs Draft-Proof Loop
#
# This script initializes the document drafting process by:
# 1. Setting up the directory structure for iterations
# 2. Initializing the draft document based on the template
# 3. Creating the proof tracking file
# 4. Facilitating the iterative feedback loop
#
# Usage: ./setup-draft.sh [OPTIONS] <document_type> <document_title>
#
# OPTIONS:
#   --json              Output results in JSON format
#   --existing-content  Path to existing content to convert/incorporate
#   --skip-branch-check Skip the feature branch name check
#   --help, -h          Show this help message
#
# EXAMPLES:
#   ./setup-draft.sh "Whitepaper" "Blockchain Security Best Practices"
#   ./setup-draft.sh --existing-content=/path/to/content.docx "API Documentation" "Payment API v2"

set -e

# Parse command line arguments
JSON_MODE=false
EXISTING_CONTENT=""
SKIP_BRANCH_CHECK=false
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --existing-content=*)
            EXISTING_CONTENT="${arg#*=}"
            ;;
        --skip-branch-check)
            SKIP_BRANCH_CHECK=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] <document_type> <document_title>"
            echo "  --json                 Output results in JSON format"
            echo "  --existing-content=PATH Path to existing content to convert/incorporate"
            echo "  --skip-branch-check    Skip the feature branch name check"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get all paths and variables from common functions
eval $(get_feature_paths)

# Check if we're on a proper feature branch (only for git repos)
if [ "$SKIP_BRANCH_CHECK" = false ]; then
    check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1
else
    echo "Skipping branch name check. Using branch: $CURRENT_BRANCH"
fi

# Check for required arguments
if [ ${#ARGS[@]} -lt 2 ]; then
    echo "ERROR: Missing required arguments" >&2
    echo "Usage: $0 [OPTIONS] <document_type> <document_title>" >&2
    exit 1
fi

DOCUMENT_TYPE="${ARGS[0]}"
DOCUMENT_TITLE="${ARGS[1]}"

# Create iterations directory
ITERATIONS_DIR="$REPO_ROOT/iterations/$CURRENT_BRANCH"
mkdir -p "$ITERATIONS_DIR"

# Set up file paths
DRAFT_FILE="$ITERATIONS_DIR/draft.md"
PROOF_FILE="$ITERATIONS_DIR/proof.md"

# Check for draft template in multiple locations
TEMPLATE_LOCATIONS=(
    "$REPO_ROOT/templates/bobdocs/draft-template.md"
    "$REPO_ROOT/.bob/templates/draft-template.md"
    "$REPO_ROOT/.specify/templates/bobdocs.draft.md"
    "$REPO_ROOT/.specify/templates/draft-template.md"
)

TEMPLATE=""
for loc in "${TEMPLATE_LOCATIONS[@]}"; do
    if [[ -f "$loc" ]]; then
        TEMPLATE="$loc"
        break
    fi
done

if [[ -n "$TEMPLATE" ]]; then
    # Create a temporary file for processing the template
    TEMP_FILE=$(mktemp)
    
    # Copy template to temp file
    cp "$TEMPLATE" "$TEMP_FILE"
    
    # Replace template variables
    sed -i.bak "s/{{document_type}}/$DOCUMENT_TYPE/g" "$TEMP_FILE"
    sed -i.bak "s/{{document_title}}/$DOCUMENT_TITLE/g" "$TEMP_FILE"
    sed -i.bak "s/{{document_purpose}}/Generated from feature $CURRENT_BRANCH/g" "$TEMP_FILE"
    sed -i.bak "s/{{document_outline}}/To be defined/g" "$TEMP_FILE"
    sed -i.bak "s/{{iteration_count}}/1/g" "$TEMP_FILE"
    sed -i.bak "s/{{max_iterations}}/5/g" "$TEMP_FILE"
    
    # Handle existing content if provided
    if [[ -n "$EXISTING_CONTENT" ]]; then
        if [[ -f "$EXISTING_CONTENT" ]]; then
            CONTENT_PATH=$(realpath "$EXISTING_CONTENT")
            sed -i.bak "s|{{existing_content}}|$CONTENT_PATH|g" "$TEMP_FILE"
        else
            echo "WARNING: Existing content file not found: $EXISTING_CONTENT" >&2
            sed -i.bak "s/{{existing_content}}/None/g" "$TEMP_FILE"
        fi
    else
        sed -i.bak "s/{{existing_content}}/None/g" "$TEMP_FILE"
    fi
    
    # Move processed template to draft file
    mv "$TEMP_FILE" "$DRAFT_FILE"
    rm -f "$TEMP_FILE.bak"
    
    echo "Created draft template at $DRAFT_FILE"
else
    echo "ERROR: Draft template not found at $TEMPLATE" >&2
    exit 1
fi

# Create initial proof tracking file
cat > "$PROOF_FILE" << EOF
# Proof Tracking: $DOCUMENT_TITLE

## Iteration 1 ($(date +%Y-%m-%d))

### Issues Found
*To be filled during the proof phase*

### Quality Scores by Section
*To be filled during the proof phase*

### Changes Made
*To be filled after user feedback*

## Summary of Progress
- Initial draft created
- Awaiting first proof review
EOF

echo "Created proof tracking file at $PROOF_FILE"

# Create example draft based on document type
EXAMPLE_DRAFT="$ITERATIONS_DIR/example-draft.md"

cat > "$EXAMPLE_DRAFT" << EOF
# $DOCUMENT_TYPE: $DOCUMENT_TITLE

## Introduction
This document provides an overview of... [NEEDS MORE DETAIL]

## Main Section 1
Content for main section 1...

## Main Section 2
Content for main section 2... [VERIFY]

## Conclusion
Summary of key points...
EOF

echo "Created example draft at $EXAMPLE_DRAFT"

# Output results
if $JSON_MODE; then
    printf '{"DRAFT_FILE":"%s","PROOF_FILE":"%s","ITERATIONS_DIR":"%s","DOCUMENT_TYPE":"%s","DOCUMENT_TITLE":"%s"}\n' \
        "$DRAFT_FILE" "$PROOF_FILE" "$ITERATIONS_DIR" "$DOCUMENT_TYPE" "$DOCUMENT_TITLE"
else
    echo "DRAFT_FILE: $DRAFT_FILE"
    echo "PROOF_FILE: $PROOF_FILE"
    echo "ITERATIONS_DIR: $ITERATIONS_DIR"
    echo "DOCUMENT_TYPE: $DOCUMENT_TYPE"
    echo "DOCUMENT_TITLE: $DOCUMENT_TITLE"
    
    if [[ -n "$EXISTING_CONTENT" ]]; then
        echo "EXISTING_CONTENT: $EXISTING_CONTENT"
    fi
fi

echo ""
echo "Draft-Proof Loop initialized. To start the process:"
echo "1. Edit the draft file: $DRAFT_FILE"
echo "2. Run the proof review process"
echo "3. Update the proof tracking file: $PROOF_FILE"
echo "4. Iterate until quality standards are met"


