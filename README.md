# Apigee/GCP Signed URL Example

This repo is the companion to the Google Cloud Community article "[Signed URLs on GCP with Apigee](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Signed-URLs-on-GCP-with-Apigee/ta-p/505017)".


## Prerequisites

* A Google Cloud account an an active project
* An Apigee X instance and organization.
* Tested with Terraform v1.3.6

## Deployment

### Provision

```bash
# Ensure you're authenticated with your GCP account and working in the context of your active project.

# Set environment variables
export TF_VAR_project_id=my-project-id  # GCP project
export TF_VAR_region=us-central1
export TOKEN=$(gcloud auth print-access-token)
export APIGEE_PROJECT_ID=my-project-id  # Apigee org
export APIGEE_ENV=eval
export RUNTIME_HOST=https://1.2.3.4.nip.io  # Apigee runtime hostname
export MGMT_HOST=https://apigee.googleapis.com  # Apigee X APIs

# Provision resources
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
./provision-apigee.sh
```

### Usage

```bash
# get file info from API call
curl -X GET "$RUNTIME_HOST/signed/v1/file/1"
# get file from output: {"id": "1", "title": "Example invoice", "file": "fake_invoice.pdf"} ane make call to download API
curl -X GET -L "$RUNTIME_HOST/signed/v1/download?file=fake_invoice.pdf" --output example.pdf
# open downloaded example.pdf in PDF viewer
```

### Deprovision

```bash
# Deprovision resources
terraform -chdir=terraform destroy
./deprovision-apigee.sh
```
