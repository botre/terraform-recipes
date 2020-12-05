# Terraform recipes

## AWS

## State bucket

```bash
#!/bin/bash

PROFILE=default
BUCKET_NAME=terraform-state
BUCKET_REGION=eu-west-1

export AWS_PROFILE=$PROFILE

echo Creating bucket
aws s3 mb s3://$BUCKET_NAME --region "$BUCKET_REGION"

echo Enabling versioning
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

echo Enabling encryption
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

echo Making bucket private
aws s3api put-bucket-acl --bucket $BUCKET_NAME --acl private

Echo Finished
```

```hcl
terraform {
  backend "s3" {
    profile = "default"
    region = "eu-west-1"
    bucket = "terraform-state"
    key = "project-key"
  }
}
```

## Providers setup

```hcl
provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region = "eu-west-1"
}

provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region = "us-east-1"
  alias = "aws-us-east-1"
}
```

## Route53 hosted zone

```hcl
locals {
  hosted_zone_name = "test.com"
}

resource "aws_route53_zone" "hosted_zone" {
  name = local.hosted_zone_name
}
```

## Route53 hosted zone certificate

Dependencies:

- Route53 hosted zone

```hcl
provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region = "us-east-1"
  alias = "aws-us-east-1"
}

locals {
  hosted_zone_name = "test.com"
  certificate_domain_name = "test.com"
  certificate_alternate_domain_names = [
    "test.com",
    "*.test.com"]
}

module "route53_hosted_zone_certificate" {
  source = "github.com/botre/terraform-recipes/modules/aws/route-53-hosted-zone-certificate"
  hosted_zone_name = local.hosted_zone.name
  certificate_domain_name = local.certificate_domain_name
  certificate_alternate_domain_names = local.certificate_alternate_domain_names
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```

## S3 + CloudFront website

Dependencies:

- Route53 hosted zone
- Certificate covering domain name and record aliases

```hcl
provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region = "us-east-1"
  alias = "aws-us-east-1"
}

locals {
  hosted_zone_name = "test.com"
  certificate_domain_name = "test.com"
  bucket_name = "test-bucket"
  record_aliases = [
    "test.com",
    "www.test.com"]
}

module "s3_cloudfront_website" {
  source = "github.com/botre/terraform-recipes/modules/aws/s3-cloudfront-website"
  hosted_zone_name = local.hosted_zone.name
  certificate_domain_name = local.certificate_domain_name
  bucket_name = local.bucket_name
  record_aliases = local.record_aliases
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```

## SES domain

Dependencies:

- Route53 hosted zone

```hcl
locals {
  hosted_zone_name = "test.com"
  email_domain_name = "test.com"
}

module "ses_domain" {
  source = "github.com/botre/terraform-recipes/modules/aws/ses-domain"
  hosted_zone_name = local.hosted_zone.name
  email_domain_name = local.email_domain_name
}
```