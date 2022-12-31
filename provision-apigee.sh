#!/bin/bash

# Copyright 2022 Google LLC
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

BUCKET="$(terraform -chdir=terraform output -raw bucket)"
FUNCTION_URI="$(terraform -chdir=terraform output -raw function_uri)"
# write Terraform output vars to apigee/apiproxy/resources/properties/props.properties
printf "bucket=$BUCKET\nfunction_url=$FUNCTION_URI" > 'apigee/apiproxy/resources/properties/props.properties'
# zip up apigee directory and POST it to apigee
(cd apigee && zip -r ../assets/apigee-signedurl-example.zip .)
# Set up Apigee proxies
curl -X POST "$MGMT_HOST/v1/organizations/$APIGEE_PROJECT_ID/apis?action=import&name=apigee-signedurl-example" \
        -H "Authorization: Bearer $TOKEN" --form file=@"assets/apigee-signedurl-example.zip"
# Deploy proxy
curl -X POST "$MGMT_HOST/v1/organizations/$APIGEE_PROJECT_ID/environments/$APIGEE_ENV/apis/apigee-signedurl-example/revisions/1/deployments" \
         -H "Authorization: Bearer ${TOKEN}"
