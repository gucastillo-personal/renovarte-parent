# renovarte-parent — atajos para levantar el stack local del chat "Colibrí"
# (spec 0016) sin AWS: renovarte-catalogo (frontend) habla por WebSocket con
# el harness de dev de renovarte-chat-gateway, que a su vez invoca el
# conector real de renovarte-colibri-rag (Claude Haiku + Voyage AI reales,
# sin Lambda/API Gateway). `make help` lista los targets.
#
# Requiere los PRs (o ramas locales) del harness de dev en los 2 repos:
#   renovarte-chat-gateway#3, renovarte-colibri-rag#5 (apilado sobre #4,
#   el fix de OOM de combos.ts — necesario para que dev-rag no crashee).

CHAT_GATEWAY_DIR := renovarte-chat-gateway
COLIBRI_RAG_DIR  := renovarte-colibri-rag
CATALOGO_DIR     := renovarte-catalogo

DEV_WS_PORT  ?= 8787
DEV_RAG_PORT ?= 8788

.PHONY: help dev-colibri dev-rag dev-gateway dev-catalogo \
        _require-submodules _require-rag-env

help:
	@echo "renovarte-parent — targets disponibles:"
	@echo ""
	@echo "  make dev-colibri     levanta rag + gateway + catalogo juntos (Ctrl+C corta los 3)"
	@echo "  make dev-rag         solo el conector RAG local (renovarte-colibri-rag)"
	@echo "  make dev-gateway     solo el server WS local (renovarte-chat-gateway)"
	@echo "  make dev-catalogo    solo el frontend, apuntando al gateway local"
	@echo ""
	@echo "  dev-rag necesita ANTHROPIC_API_KEY/VOYAGE_API_KEY en"
	@echo "  $(COLIBRI_RAG_DIR)/.env (ver .env.example ahí) y catálogo"
	@echo "  sincronizado ('pnpm sync-catalog' en ese repo)."
	@echo ""
	@echo "  Puertos por defecto: gateway=$(DEV_WS_PORT) rag=$(DEV_RAG_PORT)"
	@echo "  (override: make dev-colibri DEV_WS_PORT=... DEV_RAG_PORT=...)"

_require-submodules:
	@for d in $(COLIBRI_RAG_DIR) $(CHAT_GATEWAY_DIR) $(CATALOGO_DIR); do \
		if [ ! -d "$$d" ] || [ -z "$$(ls -A $$d 2>/dev/null)" ]; then \
			echo "✗ Falta $$d/ (vacío o no existe) — corré 'git submodule update --init --recursive'."; \
			exit 1; \
		fi; \
	done

_require-rag-env:
	@if [ ! -f "$(COLIBRI_RAG_DIR)/.env" ]; then \
		echo "✗ Falta $(COLIBRI_RAG_DIR)/.env (ANTHROPIC_API_KEY/VOYAGE_API_KEY)."; \
		echo "  Ver $(COLIBRI_RAG_DIR)/.env.example."; \
		exit 1; \
	fi

dev-rag: _require-submodules _require-rag-env
	cd $(COLIBRI_RAG_DIR) && DEV_SERVER_PORT=$(DEV_RAG_PORT) pnpm dev:server

dev-gateway: _require-submodules
	cd $(CHAT_GATEWAY_DIR) && \
		DEV_WS_PORT=$(DEV_WS_PORT) RAG_DEV_SERVER_URL=http://localhost:$(DEV_RAG_PORT) \
		pnpm dev:ws

dev-catalogo: _require-submodules
	cd $(CATALOGO_DIR) && NEXT_PUBLIC_CHAT_WS_URL=ws://localhost:$(DEV_WS_PORT) pnpm dev

# Los 3 procesos en un solo `make`, con prefijo por servicio en cada línea
# de log. `trap 'kill 0'` corta los 3 juntos ante Ctrl+C (SIGINT) o
# cualquier salida de este target — sin eso quedan procesos huérfanos
# corriendo en los puertos 8787/8788/3000. `sed -l` (no `-u`) es a
# propósito: es el flag de BSD sed (macOS) para no bufferear la salida —
# en Linux con GNU sed habría que cambiarlo a `sed -u`.
dev-colibri: _require-submodules _require-rag-env
	@echo "Levantando rag ($(DEV_RAG_PORT)) + gateway ($(DEV_WS_PORT)) + catalogo — Ctrl+C corta los 3."
	@trap 'kill 0' EXIT INT TERM; \
	(cd $(COLIBRI_RAG_DIR) && DEV_SERVER_PORT=$(DEV_RAG_PORT) pnpm dev:server 2>&1 | sed -l 's/^/[rag]      /') & \
	(cd $(CHAT_GATEWAY_DIR) && DEV_WS_PORT=$(DEV_WS_PORT) RAG_DEV_SERVER_URL=http://localhost:$(DEV_RAG_PORT) pnpm dev:ws 2>&1 | sed -l 's/^/[gateway]  /') & \
	(cd $(CATALOGO_DIR) && NEXT_PUBLIC_CHAT_WS_URL=ws://localhost:$(DEV_WS_PORT) pnpm dev 2>&1 | sed -l 's/^/[catalogo] /') & \
	wait
