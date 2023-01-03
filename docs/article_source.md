# Signed URLs on GCP with Apigee

This article describes an approach to using signed URLs for large files in conjunction with an API-centric application managed by Apigee, and is accompanied by [a repo](https://github.com/mdorn/apigee-gcp-signed-url-example) that deploys the relevant Google Cloud resources, including a Cloud Function responsible for the signing.

## Why signed URLs?

API management solutions like Apigee are well suited to managing interactions between clients and backends via standard data exchange formats like JSON and XML in a secure and scalable fashion, but when it comes to sending or receiving large files, we must take into account performance considerations and system limitations.  For example, Apigee's message payload size limit is 10MB, and while [HTTP streaming](https://cloud.google.com/apigee/docs/api-platform/develop/enabling-streaming) offers one way of addressing that limitation, using it to manage large file requests is neither recommended nor officially supported because of the performance issues that can arise.

Signed URLs used with a cloud provider storage solution like [Cloud Storage](https://cloud.google.com/storage) is thus the recommended solution to securely managing file transfers in conjunction with an API-based application architecture, in this case one enabled by Apigee.  But what is a signed URL?  As explained [here](https://cloud.google.com/cdn/docs/using-signed-urls),

> A signed URL is a URL that provides limited permission and time to make a request. Signed URLs contain authentication information in their query strings, allowing users without credentials to perform specific actions on a resource. When you generate a signed URL, you specify a user or service account that must have sufficient permission to make the request associated with the URL.

## Implementation

This topic has been [covered previously](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Screencast-Using-Apigee-to-create-a-Signed-URL-for-Google-Cloud/ta-p/77686) on this site, and the approach illustrated there works well and offers the advantage of encapsulating all the required logic within your proxy. The approach is limited, however, in a couple of key respects: 1) It requires the careful management of service account credentials, generating a key pair for a service account and securely storing the private key in a [key value map (KVM)](https://cloud.google.com/apigee/docs/api-platform/cache/key-value-maps), and 2) it [implements the RSA-SHA256-based signing logic](https://cloud.google.com/storage/docs/access-control/signing-urls-manually) at a relatively low level without fully taking advantage of Google SDKs that do this for you.

In the implementation described below and available in [this repo](https://github.com/mdorn/apigee-gcp-signed-url-example) we instead outsource our signing logic to a [Cloud Function](https://cloud.google.com/functions) that uses the [Cloud Storage libraries](https://cloud.google.com/storage/docs/samples/storage-generate-signed-url-v4) to overcome both of these limitations.  In addition to simplifying the signing logic and relying on the official Google libraries to ensure the implementation is secure and up to date, using this approach enables us to use the Application Default Credential (ADC) of the service account specified to run the function so that we don't need a private key.

To help you explore the solution proposed here, I've provided a [repo](https://github.com/mdorn/apigee-gcp-signed-url-example) with Terraform code that deploys the following resources:

* A service account with a binding to a custom IAM role that enables the service account to generate a signed URL and also read and write from a storage bucket.
* A Cloud Storage bucket without public access enabled, and an IAM binding that gives access to the service account. The bucket also includes an example file that can be downloaded with a signed URL.
* A Cloud Function, written in Python, that signs the URL based on supplied bucket and object parameters, and an IAM binding that gives the service account the Cloud Run invoker role. (It's a 2nd generation Cloud Function, and is thus based on [Cloud Run and Eventarc](https://cloud.google.com/functions/docs/concepts/version-comparison).)

Two additional scripts deploy a proxy to your Apigee X environment showing how you might implement the solution in conjunction with Apigee.

See the [`README`](https://github.com/mdorn/apigee-gcp-signed-url-example/blob/main/README.md) in the repo for deployment instructions and prerequisites.

Once these resources are deployed, you can run some requests against the Apigee proxy to see the solution in action:

Imagine the first request being issued by your client application on behalf of a properly authenticated user who wants to download a file that belongs to their account.  The `file` API endpoint is called:

```sh
curl -X GET "https://1.2.3.4.nip.io/signed/v1/file/1"
```

and the JSON response looks like this:

```json
{"id": "1", "title": "Example invoice", "file": "fake_invoice.pdf"}
```

A subsequent call to sign the URL via the `/signed/v1/download` endpoint and redirect the client to download the file then takes place:

```sh
curl -L "https://34.117.156.38.nip.io/signed/v1/download?file=$FILE" --output example.pdf
```

Here a Service Callout invokes the Cloud Function URL, which returns a time-constrained URL that looks like this:

```
https://storage.googleapis.com/apigee-signedurl-bucket-0ed14900/fake_invoice.pdf?Expires=1672517695&GoogleAccessId=apigee-signedurl-svc-acct%40my-gcp-project.iam.gserviceaccount.com&Signature=51B19lC7KSfdFRxqvniBepAspKRJFRxKTb0rhY%2FG9pIaXtijWS1eIij5cS%2BIOtORvFqpOn08B77mGa9VBvRjM83h%2FHylA7WudhbDQ%2BHMPyPI451EwLsSjz137nCQ%2Fb%2BORtN9%2FSo%2BYc7tOAp9JWOyEfrMyHtyGIiWcZL1cZUAg5Y%2B2RnDQH5YUzre3WpuquEFdRcakxboHvFgEi9nQJtAUltaXdt8pTdDkVe%2FHoXb43mkq4YCa37aKh7YaNGOgJcJNFls%2BrhRxQHvD0M7qSWYYsgU%2FXI1R6YyVMutaVgQbxlKcrvyQTW%2BrAvW1cC3LoYJrqEZcyslJPthJq%2FcUUFERQ%3D%3D
```

And the proxy flow finally issues the redirect to the URL for the download.

## Additional security considerations

> **DISCLAIMER**: This discussion is not intended to be exhaustive, but merely to point in the direction of some considerations to ensure the security of this solution. In a future iteration of this article I may delve into these matters in more detail.

**Securing the URL**: Once the URL has been signed, anyone in possession of it will have access to the object, to either `GET` or `PUT` a file, depending on what you've specified in the signing process.  The example Apigee proxy includes an OAuth 2.0 token validation policy which is disabled for demo simplification, but which is there to serve as a reminder that it's up to the API developer to ensure that the signing function itself is only invoked in response to an action by an authenticated user, with data supplied by a properly secured interaction.  Beyond that, at a minimum, HTTPS should always be used to encrypt the URL in transit, and an appropriate expiration time be set to render the URL worthless shortly after it's used.  In our implementation [5 minutes is specified](https://github.com/mdorn/apigee-gcp-signed-url-example/blob/main/cloud_function/main.py#L42).

**IAM and least privilege**: As indicated in the description of provisioned resources above, we have attempted to scope service account permissions in such a way that the account only has the minimum level of access needed to perform the core functions: accessing specific storage buckets, invoking a Cloud Function, and generating a URL signature when that function is invoked.  Also as noted, doing this in a way that doesn't require managing a private key is a security bonus.

**Networking**: In this implementation, the Cloud Function runs at a publicly accessible URL.  In a real-world implementation you would most likely want to serve it behind an internal load balancer where it can only be accessed by an Apigee instance where, for instance, appropriate VPC peering relationships have been defined. For more, consult [this guide](https://cloud.google.com/load-balancing/docs/l7-internal/setting-up-l7-internal-serverless) in the Cloud Load Balancing documentation.
