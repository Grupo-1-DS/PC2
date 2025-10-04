RELEASE ?= 1.0.0
OUT_DIR ?= out
SRC_DIR := src
DIST_DIR := dist
TEST_DIR := tests
TOOLS := ss journalctl kill pgrep awk sed jq nc python3

export RELEASE OUT_DIR SRC_DIR TOOLS
export SIM_PORTS ?= 8080,8081,8082
export SIM_DURATION ?= 30
export JOURNAL_SINCE ?= 5m
export JOURNAL_FILTER ?= sim_

.PHONY: help tools build run simulate analyze diagnose test pack clean verify-logs


help: ## Muestra los targets disponibles
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':|##' '{printf "  %-12s %s\n", $$1, $$3}'

tools: ## Verifica que las herramientas necesarias estén instaladas
	@$(SRC_DIR)/check_tools.sh

build: ## Construye los artefactos necesario
	@mkdir -p $(OUT_DIR)
	@chmod +x $(SRC_DIR)/*.sh

run: build ## Ejecutar el auditor base
	@$(SRC_DIR)/auditor.sh

test: build ## Ejecuta tests de validación
	@$(TEST_DIR)/test.bats

clean: ## Limpia archivos generados
	@rm -rf $(OUT_DIR)/*
	@echo "✔ Limpieza completada"