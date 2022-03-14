plan: | .terraform
	terraform plan

apply: | .terraform
	terraform apply

clean:
	rm -rf .terraform*

.PHONY: build clean plan apply

.terraform .terraform.lock.hcl:
	terraform init
	touch $@
