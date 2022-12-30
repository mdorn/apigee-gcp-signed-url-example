# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "org_id" {
  default = "299810056172"
}

variable "project_id" {
  default = "apigeex-sandbox-mdorn"
}

variable "region" {
  default = "us-central1"
}

provider "google" {
  region = "${var.region}"
  project = "apigeex-sandbox-mdorn"
}

resource "google_project_iam_custom_role" "role" {
  role_id     = "ApigeeSignedURLRole"
  title       = "Apigee Signed URL Role"
  description = ""
  permissions = ["storage.buckets.get", "storage.objects.create", "storage.objects.delete", "storage.objects.get"]
}

resource "google_service_account" "service_account" {
  account_id   = "apigee-signedurl-svc-acct"
  display_name = "Apigee Signed URL Example"
}

resource "google_project_iam_binding" "binding" {
  project = "${var.project_id}"
  role = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:${google_service_account.service_account.email}"
  ]
}

resource "random_id" "bucket_prefix" {
  byte_length = 4
}

resource "google_storage_bucket" "bucket" {
  name          = "apigee-signedurl-bucket-${random_id.bucket_prefix.hex}"
  force_destroy = false
  location      = "US"
  storage_class = "STANDARD"
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.bucket.name
  role = "projects/${var.project_id}/roles/${google_project_iam_custom_role.role.role_id}"
  members = [
    "serviceAccount:${google_service_account.service_account.email}"
  ]
}

resource "google_storage_bucket_object" "example_file" {
  name   = "fake_invoice.pdf"
  source = "../fake_invoice.pdf"
  bucket = google_storage_bucket.bucket.name
}

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../function-source.zip"  # Add path to the zipped function source code
}

resource "google_cloudfunctions2_function" "function" {
  name = "apigee-signedurl-function"
  location = "${var.region}"
  description = ""

  build_config {
    runtime = "python310"
    entry_point = "get_url"  # Set the entry point 
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }
  service_config {
    max_instance_count  = 1
    available_memory    = "256M"
    timeout_seconds     = 60
    service_account_email = "${google_service_account.service_account.email}"
    ingress_settings = "ALLOW_ALL" # TODO: use internal load balancer
  }
}

resource "google_cloud_run_service_iam_binding" "binding" {
  project = google_cloudfunctions2_function.function.project
  location = google_cloudfunctions2_function.function.location
  service = google_cloudfunctions2_function.function.name
  role = "roles/run.invoker"
  members = [
    "allUsers",  # FIXME: this shouldn't be needed
    "serviceAccount:${google_service_account.service_account.email}"
  ]
}

output "function_uri" { 
  value = google_cloudfunctions2_function.function.service_config[0].uri
}

output "bucket" { 
  value = google_storage_bucket.bucket.name
}