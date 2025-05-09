# Makefile for Mensura Bash Project

# ---- Paths & Files ----
TEST_DIR=tests
TEST_FILES=$(shell find $(TEST_DIR) -type f -name '*.test')
LINT_TARGETS=$(shell find . -type f -name '*.sh' ! -path './tests/*' ! -path './node_modules/*')

# ---- Targets ----
.PHONY: all test test-one lint clean help

# Default target: Run all tests
all: test


# Run all tests or run one specific test file with: make test-one F=tests/foo.test
test:
	@if [ -z "$(F)" ]; then \
		@echo "Running all tests..."
		@bash run-all-tests.sh
	else \
		echo "Running test file: $(F)"; \
		bash run-one-test.sh "$(F)"; \
	fi

# Run shellcheck on all Bash scripts, or a specific file with F=...
lint:
	@echo "🔍 Linting Bash scripts..."
	@if [ -n "$(F)" ]; then \
		echo "📄 File: $(F)"; \
		shellcheck -x "$(F)"; \
	else \
		shellcheck -x $(LINT_TARGETS); \
	fi


# Clean up temporary/output files
clean:
	@echo "🧹 Cleaning up *.out and *.tmp..."
	@rm -f *.out *.tmp

# Show available commands
help:
	@echo "📘 Available make targets:"
	@echo "  make test         – Run all test files"
	@echo "  make test  F=...  – Run a specific test file"
	@echo "  make lint         – Lint all .sh files with shellcheck"
	@echo "  make lint  F=..   – Lint all .sh files with shellcheck"
	@echo "  make clean        – Remove *.out and *.tmp files"
	@echo "  make help         – Show this help message"
