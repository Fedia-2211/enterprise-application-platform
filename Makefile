# Makefile — DevOps Portfolio Project
# Usage: make <target>
# Run `make help` to see all available commands

.PHONY: help tf-init tf-plan tf-apply tf-destroy \
        ansible-check ansible-deploy ansible-deploy-tag \
        ssm-params keys verify-ssh clean

TERRAFORM_DIR := terraform/environments/production
ANSIBLE_DIR   := ansible
INVENTORY     := ansible/inventories/production/hosts.yml
AWS_REGION    := us-east-1
PROJECT       := enterprise-application-platform

# ── Colours ───────────────────────────────────────────────────────────────────
CYAN  := \033[0;36m
RESET := \033[0m

help:
	@echo ""
	@echo "$(CYAN)DevOps Portfolio — Available Commands$(RESET)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  $(CYAN)Terraform$(RESET)"
	@echo "  make tf-init      — terraform init (first time only)"
	@echo "  make tf-plan      — terraform plan (preview changes)"
	@echo "  make tf-apply     — terraform apply (create/update infra)"
	@echo "  make tf-destroy   — terraform destroy (tear down everything)"
	@echo "  make tf-output    — show all terraform outputs"
	@echo ""
	@echo "  $(CYAN)Ansible$(RESET)"
	@echo "  make ansible-check         — syntax check all playbooks"
	@echo "  make ansible-deploy        — deploy everything (full run)"
	@echo "  make ansible-app           — deploy app role only"
	@echo "  make ansible-common        — run common hardening only"
	@echo "  make ansible-mysql         — configure MySQL only"
	@echo "  make ansible-monitoring    — configure CloudWatch agents"
	@echo ""
	@echo "  $(CYAN)Setup$(RESET)"
	@echo "  make keys        — generate SSH key pair for EC2"
	@echo "  make ssm-params  — populate AWS SSM with required secrets"
	@echo "  make verify-ssh  — test SSH connectivity through Bastion"
	@echo "  make export-ips  — export Terraform outputs as env vars"
	@echo ""

# ── Terraform ─────────────────────────────────────────────────────────────────
tf-init:
	cd $(TERRAFORM_DIR) && terraform init

tf-plan:
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

tf-apply:
	cd $(TERRAFORM_DIR) && terraform apply tfplan

tf-apply-auto:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

tf-destroy:
	@echo "WARNING: This will destroy ALL infrastructure. Type 'yes' to confirm:"
	cd $(TERRAFORM_DIR) && terraform destroy

tf-output:
	cd $(TERRAFORM_DIR) && terraform output

tf-state-list:
	cd $(TERRAFORM_DIR) && terraform state list

# ── Ansible ───────────────────────────────────────────────────────────────────
ansible-check:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --syntax-check

ansible-deploy:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml -v

ansible-common:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags common -v

ansible-nginx:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags nginx -v

ansible-mysql:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags mysql -v

ansible-rabbitmq:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags rabbitmq -v

ansible-memcached:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags memcached -v

ansible-app:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags app -v

ansible-jenkins:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags jenkins -v

ansible-monitoring:
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) site.yml --tags monitoring -v

# ── Setup utilities ───────────────────────────────────────────────────────────
keys:
	@echo "Generating SSH key pair..."
	aws ec2 create-key-pair \
		--key-name $(PROJECT)-key \
		--query 'KeyMaterial' \
		--output text \
		--region $(AWS_REGION) > ~/.ssh/$(PROJECT)-key.pem
	chmod 400 ~/.ssh/$(PROJECT)-key.pem
	@echo "Key saved: ~/.ssh/$(PROJECT)-key.pem"

export-ips:
	$(eval export BASTION_PUBLIC_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip))
	$(eval export APP1_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw app_server_1_private_ip))
	$(eval export APP2_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw app_server_2_private_ip))
	$(eval export DB_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw db_private_ip))
	$(eval export RABBITMQ_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw rabbitmq_private_ip))
	$(eval export MEMCACHED_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw memcached_private_ip))
	$(eval export JENKINS_PRIVATE_IP=$(shell cd $(TERRAFORM_DIR) && terraform output -raw jenkins_private_ip))
	$(eval export S3_BUCKET_NAME=$(shell cd $(TERRAFORM_DIR) && terraform output -raw s3_bucket_name))
	@echo "Environment variables exported"
	@echo "  BASTION_PUBLIC_IP  = $(BASTION_PUBLIC_IP)"
	@echo "  APP1_PRIVATE_IP    = $(APP1_PRIVATE_IP)"
	@echo "  APP2_PRIVATE_IP    = $(APP2_PRIVATE_IP)"
	@echo "  DB_PRIVATE_IP      = $(DB_PRIVATE_IP)"
	@echo "  RABBITMQ_PRIVATE_IP= $(RABBITMQ_PRIVATE_IP)"
	@echo "  JENKINS_PRIVATE_IP = $(JENKINS_PRIVATE_IP)"
	@echo "  S3_BUCKET_NAME     = $(S3_BUCKET_NAME)"

verify-ssh:
	@BASTION=$$(cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip); \
	APP1=$$(cd $(TERRAFORM_DIR) && terraform output -raw app_server_1_private_ip); \
	echo "Testing SSH to Bastion: $$BASTION"; \
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/$(PROJECT)-key.pem ubuntu@$$BASTION "echo Bastion OK"; \
	echo "Testing SSH to App1 via Bastion: $$APP1"; \
	ssh -o StrictHostKeyChecking=no -i ~/.ssh/$(PROJECT)-key.pem \
	    -J ubuntu@$$BASTION ubuntu@$$APP1 "echo App1 OK"

ssm-params:
	@echo "Storing secrets in AWS SSM Parameter Store..."
	@read -sp "MySQL root password: " MYSQL_ROOT; echo; \
	aws ssm put-parameter --name "/$(PROJECT)/production/mysql/root_password" \
	    --type SecureString --value "$$MYSQL_ROOT" --region $(AWS_REGION) --overwrite
	@read -sp "MySQL app password: " MYSQL_APP; echo; \
	aws ssm put-parameter --name "/$(PROJECT)/production/mysql/app_password" \
	    --type SecureString --value "$$MYSQL_APP" --region $(AWS_REGION) --overwrite
	@read -sp "RabbitMQ password: " RABBIT_PASS; echo; \
	aws ssm put-parameter --name "/$(PROJECT)/production/rabbitmq/password" \
	    --type SecureString --value "$$RABBIT_PASS" --region $(AWS_REGION) --overwrite
	@aws ssm put-parameter --name "/$(PROJECT)/production/gitea/secret_key" \
	    --type SecureString --value "$$(openssl rand -hex 32)" --region $(AWS_REGION) --overwrite
	@aws ssm put-parameter --name "/$(PROJECT)/production/gitea/internal_token" \
	    --type SecureString --value "$$(openssl rand -hex 64)" --region $(AWS_REGION) --overwrite
	@aws ssm put-parameter --name "/$(PROJECT)/production/gitea/metrics_token" \
	    --type SecureString --value "$$(openssl rand -hex 16)" --region $(AWS_REGION) --overwrite
	@echo "All SSM parameters stored successfully"

clean:
	find . -name "*.tfplan" -delete
	find . -name ".terraform.lock.hcl" -delete
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaned temporary files"
