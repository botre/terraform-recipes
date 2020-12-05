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

output "name_servers" {
  value = aws_route53_zone.hosted_zone.name_servers
}
```

## Route53 hosted zone certificate

```hcl
provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region = "us-east-1"
  alias = "aws-us-east-1"
}

locals {
  certificate_alternate_domain_names = [
    "test.com",
    "*.test.com"]
}

module "certificate" {
  depends_on = [
    aws_route53_zone.hosted_zone]
  source = "github.com/botre/terraform-recipes/modules/aws/route-53-hosted-zone-certificate"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  certificate_domain_name = aws_route53_zone.hosted_zone.name
  certificate_alternate_domain_names = local.certificate_alternate_domain_names
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```

## S3 + CloudFront website

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
  depends_on = [
    aws_route53_zone.hosted_zone,
    module.certificate]
  source = "github.com/botre/terraform-recipes/modules/aws/s3-cloudfront-website"
  hosted_zone_name = local.hosted_zone_name
  certificate_domain_name = local.certificate_domain_name
  bucket_name = local.bucket_name
  record_aliases = local.record_aliases
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```

```bash
#!/bin/bash

PROFILE=default
BUCKET_NAME=test-bucket

export AWS_PROFILE=$PROFILE

aws s3 rm s3://$BUCKET_NAME --recursive
echo "<!DOCTYPE html><html><body>Hello, World!</body></html>" | aws s3 cp - s3://$BUCKET_NAME/index.html --content-type text/html
```

## SES domain

```hcl
module "ses_domain" {
  depends_on = [
    aws_route53_zone.hosted_zone]
  source = "github.com/botre/terraform-recipes/modules/aws/ses-domain"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  email_domain_name = aws_route53_zone.hosted_zone.name
}
```

## Lambda IAM role

```hcl
module "role" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-iam-role"
  prefix = "project"
}

resource "aws_lambda_function" "function" {
  role = module.role.role_arn
}
```

## Lambda S3 deployment

```hcl
locals {
  function_name = "test-function"
  handler_file_name = "main"
  handler_function_name = "handler"
  deployment_bucket_name = "deployments"
  deployment_object_key = "deployment.zip"
}

module "deployment" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-s3-deployment"
  deployment_bucket_name = local.deployment_bucket_name
  deployment_object_key = local.deployment_object_key
  handler_file_name = local.handler_file_name
  handler_function_name = local.handler_function_name
}

resource "aws_lambda_function" "function" {
  function_name = local.function_name
  s3_bucket = module.deployment.deployment_bucket_id
  s3_key = module.deployment.deployment_object_key
  handler = "${local.handler_file_name}.${local.function_name}"
}
```

## Lambda API Gateway trigger

```hcl
module "api_gateway_trigger" {
  depends_on = [
    aws_lambda_function.function]
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-api-gateway-trigger"
  function_name = aws_lambda_function.function.function_name
}
```

## Lambda scheduled trigger

```hcl
module "scheduled_trigger" {
  depends_on = [
    aws_lambda_function.function]
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-scheduled-trigger"
  function_name = aws_lambda_function.function.function_name
  rule_name = "every-five-minutes"
  rule_description = "Fires every 5 minutes"
  rule_schedule_expression = "rate(5 minutes)"
}
```

## IAM logging policy

```hcl
module "role" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-iam-role"
  prefix = "project"
}

module "logging_policy" {
  depends_on = [
    module.role]
  source = "github.com/botre/terraform-recipes/modules/aws/iam-logging-policy"
  role_name = module.role.role_name
}
```

## IAM SES send policy

```hcl
module "role" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-iam-role"
  prefix = "project"
}

module "ses_send_policy" {
  depends_on = [
    module.role]
  source = "github.com/botre/terraform-recipes/modules/aws/iam-ses-send-policy"
  role_name = module.role.role_name
}
```