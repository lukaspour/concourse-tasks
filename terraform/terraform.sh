#!/bin/sh

set -e

print() {
    local GREEN='\033[1;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m'
    local BOLD='\e[1m'
    local REGULAR='\e[0m'
    case "$1" in
        'failure' ) echo -e "${RED}✗ $2${NC}" ;;
        'success' ) echo -e "${GREEN}√ $2${NC}" ;;
        'warning' ) echo -e "${YELLOW}⚠ $2${NC}" ;;
        'header'  ) echo -e "${BOLD}$2${REGULAR}" ;;
    esac
}

setup() {
    export DIR="$PWD"
    export AWS_ACCESS_KEY_ID="${access_key}"
    export AWS_SECRET_ACCESS_KEY="${secret_key}"
    export AWS_SESSION_TOKEN="${session_token}"
    mkdir -p $DIR/source/cache
}

install_tflint() {
    curl -s -L -o /tmp/tflint.zip https://github.com/wata727/tflint/releases/download/v0.5.3/tflint_linux_amd64.zip
    unzip -o -q /tmp/tflint.zip -d $DIR/source/cache
    ln -s $DIR/source/cache/tflint /usr/local/bin/tflint
    print success "Download and install tflint"
}

terraform_tflint() {
    if [ ! -f "/usr/local/bin/tflint" ]; then
        install_tflint
    fi
    tflint >> /dev/null
    print success "tflint"
}

terraform_fmt() {
    if ! terraform fmt -check=true >> /dev/null; then
        print failure "terraform fmt (Some files need to be formatted, run 'terraform fmt' to fix.)"
        exit 1
    fi
    print success "terraform fmt"
}

terraform_get() {
    # NOTE: We are using init here to download providers in addition to modules.
    terraform init -backend=false -input=false >> /dev/null
    print success "terraform get (init without backend)"
}

terraform_init() {
    terraform init -input=false -lock-timeout=$lock_timeout >> /dev/null
    print success "terraform init"
}

terraform_apply() {
    terraform_init
    terraform apply -refresh=true -auto-approve=true -lock-timeout=$lock_timeout
}

terraform_test_module() {
    terraform_fmt
    terraform_get
    terraform validate -check-variables=false
    print success "terraform validate (not including variables)"
}

terraform_test() {
    terraform_fmt
    terraform_get
    terraform validate
    print success "terraform validate"
    terraform_tflint
}

main() {
    if [ -z "$command" ]; then
        echo "Command is a required parameter and must be set."
        exit 1
    fi
    if [ -z "$directories" ]; then
        echo "No directories provided. Please set the parameter."
        exit 1
    fi

    setup
    for directory in $directories; do
        if [ ! -d "$DIR/source/$directory" ]; then
            print failure "Directory not found: $directory"
            exit 1
        fi
        cd $DIR/source/$directory
        print header "Current directory: $directory"
        case "$command" in
            'test'        ) terraform_test ;;
            'test-module' ) terraform_test_module ;;
            'apply'       ) terraform_apply ;;
            *             ) echo "Command not supported: $command" && exit 1;;
        esac
    done
}

main
