init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply

clean:
	rm -rf .terraform*

.PHONY: init plan apply clean
