# Terraform recipes

## AWS

### Save output to JSON

```bash
terraform output -json > infrastructure.json
```

### Monthly budget alert

```hcl
resource "aws_budgets_budget" "budget" {
  name = "budget"
  budget_type = "COST"
  limit_amount = "50.0"
  limit_unit = "USD"
  time_period_start = "2020-01-01_00:00"
  time_period_end = "2085-01-01_00:00"
  time_unit = "MONTHLY"
  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 100
    threshold_type = "PERCENTAGE"
    notification_type = "FORECASTED"
    subscriber_email_addresses = [
      "your@email.com"]
  }
}
```

### State bucket

```bash
#!/bin/bash

BUCKET_NAME=terraform-state
BUCKET_REGION=eu-west-1

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

To use a named profile, add the following to the above snippet:

```bash
export AWS_PROFILE=your-named-profile
```

```hcl
terraform {
  backend "s3" {
    profile = "your-named-profile"
    region = "eu-west-1"
    bucket = "terraform-state"
    key = "project-key"
  }
}
```

### Providers setup

```hcl
terraform {
  required_providers {
    aws = {
      version = "~> 3.0"
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "your-named-profile"
  region = "eu-west-1"
}

provider "aws" {
  profile = "your-named-profile"
  region = "us-east-1"
  alias = "aws-us-east-1"
}
```

### Route53 hosted zone

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

### Route53 hosted zone certificate

```hcl
provider "aws" {
  region = "us-east-1"
  alias = "aws-us-east-1"
}

locals {
  certificate_alternate_domain_names = [
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

### TXT records

```hcl
resource "aws_route53_record" "route_53_root_txt" {
  zone_id = aws_route53_zone.hosted_zone.id
  name = ""
  type = "TXT"
  ttl = "300"
  records = [
    "service-a=service-a-secret",
    "service-b=service-b-secret",
    "service-c=service-c-secret"
  ]
}
```

### MX records

```hcl
resource "aws_route53_record" "route_53_root_txt" {
  zone_id = aws_route53_zone.hosted_zone.id
  name = ""
  type = "TXT"
  ttl = "300"
  records = [
    "1 MX.EXAMPLE.COM.",
    "5 MX.EXAMPLE.COM.",
    "10 MX.EXAMPLE.COM."
  ]
}
```

### S3 + CloudFront website

```hcl
provider "aws" {
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

BUCKET_NAME=test-bucket

aws s3 rm s3://$BUCKET_NAME --recursive
echo "<!DOCTYPE html><html><body>Hello, World!</body></html>" | aws s3 cp - s3://$BUCKET_NAME/index.html --content-type text/html
```

```bash
#!/bin/bash

aws s3 sync $BUILD_DIRECTORY s3://"$S3_BUCKET_NAME" --delete --acl public-read && aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*"
```

### SES domain

```hcl
module "ses_domain" {
  depends_on = [
    aws_route53_zone.hosted_zone]
  source = "github.com/botre/terraform-recipes/modules/aws/ses-domain"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  email_domain_name = aws_route53_zone.hosted_zone.name
}
```

### Lambda IAM role

```hcl
module "role" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-iam-role"
  prefix = "project"
}

resource "aws_lambda_function" "function" {
  role = module.role.role_arn
}
```

### Lambda S3 deployment

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

```bash
#!/bin/bash

set -e

BUILD_DIRECTORY=
BUILD_FILE_NAME=

DEPLOYMENT_BUCKET=
DEPLOYMENT_OBJECT_KEY=

HANDLER_FILE_NAME=

FUNCTION_NAME=
FUNCTION_REGION=

(cd $BUILD_DIRECTORY && mv $BUILD_FILE_NAME "$HANDLER_FILE_NAME" && zip "$DEPLOYMENT_OBJECT_KEY" "$HANDLER_FILE_NAME")
aws s3 sync $BUILD_DIRECTORY s3://"$DEPLOYMENT_BUCKET" --delete
aws lambda update-function-code --function-name "$FUNCTION_NAME" --s3-bucket "$DEPLOYMENT_BUCKET" --s3-key "$DEPLOYMENT_OBJECT_KEY" --region "$FUNCTION_REGION" --publish
aws lambda update-function-configuration --function-name "$FUNCTION_NAME" --region "$FUNCTION_REGION"
```

### Lambda API Gateway trigger

```hcl
module "api_gateway_trigger" {
  depends_on = [
    aws_lambda_function.function]
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-api-gateway-trigger"
  function_name = aws_lambda_function.function.function_name
}
```

### Lambda scheduled trigger

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

### IAM logging policy

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

### IAM SES send policy

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

### API Gateway custom domain

```hcl
provider "aws" {
  region = "us-east-1"
  alias = "aws-us-east-1"
}

locals {
  api_domain_name = "api.test.com"
}

module "custom_domain" {
  depends_on = [
    aws_route53_zone.hosted_zone,
    module.certificate,
    module.api_gateway_trigger]
  source = "github.com/botre/terraform-recipes/modules/aws/api-gateway-custom-domain"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  certificate_domain_name = module.certificate.certificate_domain_name
  domain_name = local.api_domain_name
  gateway_rest_api_name = module.api_gateway_trigger.gateway_rest_api_name
  gateway_deployment_stage_name = module.api_gateway_trigger.gateway_deployment_stage_name
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```