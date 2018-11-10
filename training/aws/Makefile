SHELL := $(SHELL) -e
VARS_FILE  := aws.tfvars
PLAN_FILE  := aws.tfplan
STATE_FILE := aws.tfstate
OUT_FILE   := properties.yml
YAMLER     ?= ../../bin/yamler

all: manifest deploy

manifest:
	@chmod 0400 *.pem || true
	terraform init
	terraform get -update
	terraform plan -var-file $(VARS_FILE) -out $(PLAN_FILE) .

info:
	@./bin/info

deploy:
	terraform apply -var-file $(VARS_FILE)
	terraform output | $(YAMLER) meta tf > $(OUT_FILE)
	./bin/info

destroy:
	terraform plan -destroy -var-file $(VARS_FILE) -out $(PLAN_FILE)
	terraform apply $(PLAN_FILE)

cc:
	@spruce merge --prune meta cloud-config.yml properties.yml

clean:
	rm -f $(PLAN_FILE)
	rm -f $(STATE_FILE)


.PHONY: all manifest deploy clean
