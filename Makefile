RELEASE ?= 2.0.0
OUT_DIR ?= out
SRC_DIR := src
DIST_DIR := dist
TEST_DIR := tests
TOOLS := ss journalctl kill pgrep awk sed jq nc python3

export RELEASE OUT_DIR SRC_DIR TOOLS

.PHONY: help tools build run simulate analyze diagnose test pack clean verify-logs


help: ## Muestra los targets disponibles
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':|##' '{printf "  %-12s %s\n", $$1, $$3}'

tools: ## Verifica que las herramientas necesarias estén instaladas
	@$(SRC_DIR)/check_tools.sh

build: ## Construye los artefactos necesario
	@mkdir -p $(OUT_DIR)
	@chmod +x $(SRC_DIR)/*.sh

run: build ## Ejecutar el auditor
	@$(SRC_DIR)/auditor.sh

test: build ## Ejecuta tests de validación
	@$(TEST_DIR)/test.bats

pack: ## Empaqueta el release
	@mkdir -p $(DIST_DIR)
	@tar -czf $(DIST_DIR)/auditor-$(RELEASE).tar.gz $(SRC_DIR) $(TEST_DIR) 

clean: ## Limpia archivos generados
	@rm -rf $(OUT_DIR)/*
	@echo "✔ Limpieza completada"