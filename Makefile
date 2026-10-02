# AI Codegen Pipeline Guardrails — local + CI entrypoints

.PHONY: demo demo-fail demo-pass guardrails-bad guardrails-good clean help

help:
	@echo "Targets:"
	@echo "  make demo            Full talk arc: bad fails, good passes"
	@echo "  make demo-fail       Apply bad agent proposal + run guardrails"
	@echo "  make demo-pass       Apply good agent proposal + run guardrails"
	@echo "  make guardrails-bad  Check fixtures/bad only"
	@echo "  make guardrails-good Check fixtures/good only"

demo:
	./scripts/run-demo.sh

demo-fail:
	./scripts/simulate-agent-pr.sh bad
	./scripts/run-guardrails.sh fixtures/bad

demo-pass:
	./scripts/simulate-agent-pr.sh good
	./scripts/run-guardrails.sh fixtures/good

guardrails-bad:
	./scripts/run-guardrails.sh fixtures/bad

guardrails-good:
	./scripts/run-guardrails.sh fixtures/good

clean:
	rm -rf .demo-work
	@echo "cleaned .demo-work"
