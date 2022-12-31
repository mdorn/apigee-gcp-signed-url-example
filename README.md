# Apigee/GCP Signed URL Example

```bash
# Set environment variables
export TF_VAR_project_id=my-project-id
export TF_VAR_region=us-central1
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_PROJECT_ID=my-project-id
export APIGEE_ENV=eval
export RUNTIME_HOST=https://1.2.3.4.nip.io
export MGMT_HOST=https://apigee.googleapis.com

# Provision resources
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
./provision-apigee.sh

# Deprovision resources
terraform -chdir=terraform destroy
./deprovision-apigee.sh
```
