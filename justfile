[private]
default:
    @just --list

# Run pre-commit hooks on all files
lint:
    pre-commit run --all-files
