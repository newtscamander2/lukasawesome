# lukasawesome bootstrap. Run `make help` for the list of targets.
# The heavy lifting lives in scripts/; this is a thin, discoverable front-end.

SHELL  := /bin/bash
INSTALL := scripts/install.sh

.DEFAULT_GOAL := help
.PHONY: help configure plan install yay packages drivers services stow apps repos protondrive check-system repair-display

help: ## Show this help
	@echo "lukasawesome bootstrap targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1;34m%-12s\033[0m %s\n", $$1, $$2}'

configure: ## Interactive questionnaire -> install.conf
	@bash $(INSTALL) configure

plan: ## Dry-run: print every action, change nothing
	@bash $(INSTALL) plan

install: ## Full install (questionnaire -> plan -> confirm -> run)
	@bash $(INSTALL) install

yay: ## Bootstrap the yay AUR helper
	@bash $(INSTALL) yay

packages: ## Install package groups (from install.conf)
	@bash $(INSTALL) packages

drivers: ## Install GPU drivers + multi-monitor tooling
	@bash $(INSTALL) drivers

services: ## Enable display manager, docker, virtualbox
	@bash $(INSTALL) services

stow: ## Symlink config packages into $$HOME
	@bash $(INSTALL) stow

apps: ## Apply VSCode settings (no network credentials needed)
	@bash $(INSTALL) apps

repos: ## Set up SSH key for GitLab/GitHub + clone personal repos
	@bash $(INSTALL) repos

protondrive: ## One-time Proton Drive login + enable the ~/ProtonDrive mount
	@bash $(INSTALL) protondrive

check-system: ## Verify packages, services, audio and symlinks are set up
	@bash $(INSTALL) check-system

repair-display: ## Fix a black screen / no greeter: repair LightDM + Awesome from a TTY
	@bash $(INSTALL) repair-display
