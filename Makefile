export README_DEPS ?=  docs/terraform.md

-include $(shell curl -sSL -o .build-harness "https://gitlab.com/snippets/1957473/raw"; echo .build-harness)

fmt:
	terraform13 fmt -recursive
