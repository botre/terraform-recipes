# Terraform recipes

## AWS

### Get caller identity

```bash
aws sts get-caller-identity --profile named-profile
```

```hcl
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}
```

### Get current region

```hcl
data "aws_region" "current" {}
```

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

### Lambda ECR deployment

```hcl
resource "aws_ecr_repository" "container_repository" {
  name = local.container_repository_name
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.container_repository.name
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire untagged images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
```

```hcl
resource "aws_lambda_function" "function" {
  function_name = local.function_name
  image_uri = "${aws_ecr_repository.container_repository.repository_url}:latest"
  package_type = "Image"
  memory_size = 1024
  timeout = 10
}
```

```dockerfile
FROM public.ecr.aws/lambda/nodejs:12
COPY package*.json ./
COPY tsconfig.json ./
COPY ./src ./src
RUN npm ci
RUN npx tsc
CMD [ "dist/serverless.handler" ]
```

```bash
#!/bin/bash

ACCOUNT_ID=
REGION=
REPOSITORY=
TAG="latest"
FUNCTION_NAME=
FUNCTION_REGION=
IMAGE_URI=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY:$TAG

docker tag $REPOSITORY:$TAG $IMAGE_URI

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker push $IMAGE_URI

aws lambda update-function-code --function-name "$FUNCTION_NAME" --region "$FUNCTION_REGION" --image-uri $IMAGE_URI --publish
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

### Setting Lambda environment variables from a .env file

```bash
ENVIRONMENT_VARIABLES="{$(
  < .env.production sed '/^#/d' | \
  sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/,/g'
)}"

aws lambda update-function-configuration --function-name "$FUNCTION" --region "$REGION" --environment "Variables=$ENVIRONMENT_VARIABLES"
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

### Lambda log group

```hcl
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
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

### API Gateway WAF

```hcl
resource "aws_wafv2_web_acl" "api_firewall" {
  name = "api-firewall"

  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name = "ip-rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit = 300
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "RateLimitedIP"
      sampled_requests_enabled = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "Allowed"
    sampled_requests_enabled = true
  }
}

resource "aws_wafv2_web_acl_association" "api_firewall_association" {
  depends_on = [
    module.api_gateway_trigger,
    aws_wafv2_web_acl.api_firewall]
  resource_arn = module.api_gateway_trigger.gateway_stage_arn
  web_acl_arn = aws_wafv2_web_acl.api_firewall.arn
}
```