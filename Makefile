
## Variables de entorno
RELEASE ?= 1.0.0
OUT_DIR ?= out
SRC_DIR := src
DIST_DIR := dist
TEST_DIR := tests
TOOLS := ss journalctl kill pgrep awk sed jq

export RELEASE OUT_DIR SRC_DIR TOOLS

.PHONY: help tools build run test pack clean

help: ## Muestra los targets disponibles
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':|##' '{printf "  %-12s %s\n", $$1, $$3}'

tools: ## Verifica que las herramientas necesarias estén instaladas
	@$(SRC_DIR)/check_tools.sh

build:
	@mkdir -p $(OUT_DIR)

run: build ##Ejecutar el auditor
	@$(SRC_DIR)/auditor.sh

test:
	@$(TEST_DIR)/test.bats

pack:


clean: