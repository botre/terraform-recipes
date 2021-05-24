# Terraform recipes

## AWS

## File naming convention

* data.tf
* locals.tf
* main.tf
* outputs.tf
* providers.tf
* variables.tf

## .gitignore

* .terraform

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

output "region" {
  value = data.aws_region.current.name
}
```

### Apply and save output to JSON

```bash
#!/bin/bash

set -e

terraform apply
terraform output -json > ../infrastructure.json
```

### Monthly budget alert

```hcl
locals {
  monthly_budget = "50.0"
  monthly_budget_alert_emails = [
    "example@email.com"]
}

resource "aws_budgets_budget" "budget" {
  name = "budget"
  budget_type = "COST"
  limit_amount = local.monthly_budget
  limit_unit = "USD"
  time_period_start = "2020-01-01_00:00"
  time_period_end = "2085-01-01_00:00"
  time_unit = "MONTHLY"
  notification {
    comparison_operator = "GREATER_THAN"
    threshold = 100
    threshold_type = "PERCENTAGE"
    notification_type = "FORECASTED"
    subscriber_email_addresses = local.monthly_budget_alert_emails
  }
}
```

### Providers setup

```hcl
terraform {
  required_version = "~> 0.15.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
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

### State bucket

```bash
#!/bin/bash

BUCKET_NAME=terraform-state
BUCKET_REGION=eu-west-1

echo Creating bucket
aws s3 mb s3://$BUCKET_NAME --region "$BUCKET_REGION"

echo Enabling versioning
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status = Enabled

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

### Alarm topic

```hcl
resource "aws_sns_topic" "alarm_topic" {
  name = "alarm-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF
}

resource "null_resource" "alarm_topic_subscriptions" {
  triggers = {
    alarm_topic_arn = aws_sns_topic.alarm_topic.arn
    alarm_emails = sha1(jsonencode(local.alarm_emails))
  }
  count = length(local.alarm_emails)
  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${aws_sns_topic.alarm_topic.arn} --protocol email --notification-endpoint ${local.alarm_emails[count.index]} --region ${data.aws_region.current.name} --profile ${local.profile}"
  }
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
resource "aws_route53_record" "route_53_root_mx" {
  zone_id = aws_route53_zone.hosted_zone.id
  name = ""
  type = "MX"
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
  source = "github.com/botre/terraform-recipes/modules/aws/s3-cloudfront-website"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  certificate_domain_name = module.certificate.certificate_domain_name
  bucket_name = local.bucket_name
  record_aliases = local.record_aliases
  providers = {
    aws.aws-us-east-1 = aws.aws-us-east-1
  }
}
```

Deploy test file to S3:

```bash
#!/bin/bash

BUCKET_NAME=test-bucket

aws s3 rm s3://$BUCKET_NAME --recursive
echo "<!DOCTYPE html><html><body>Hello, World!</body></html>" | aws s3 cp - s3://$BUCKET_NAME/index.html --content-type text/html
```

Deploy:

```bash
#!/bin/bash

aws s3 sync $BUILD_DIRECTORY s3://"$S3_BUCKET_ID" --delete --acl public-read --region "$REGION" && aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*" --region "$REGION"
```

### SES domain

```hcl
module "ses_domain" {
  source = "github.com/botre/terraform-recipes/modules/aws/ses-domain"
  hosted_zone_name = aws_route53_zone.hosted_zone.name
  email_domain_name = aws_route53_zone.hosted_zone.name
}
```

### Lambda warmer

```hcl
module "lambda_warmer" {
  source = "Nuagic/lambda-warmer/aws"
  version = "~> 3.0"
  function_name = aws_lambda_function.function.function_name
  function_arn = aws_lambda_function.function.arn
}
```

### Lambda API warmer

This solution pre-warms a container via an actual invocation that comes through API Gateway.

Do not use the /ping and /sping paths, they are reserved for API Gateway service health checks.

```hcl
module "lambda_api_warmer" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-api-warmer"
  name = "api-warmer"
  hostname = "api.domain.com"
  path = "/"
}
```

### Lambda alias

```hcl
resource "aws_lambda_alias" "function_alias" {
  name = local.function_alias
  function_name = aws_lambda_function.function.function_name
  function_version = aws_lambda_function.function.version
}
```

### Lambda provisioned concurrency

```hcl
resource "aws_lambda_provisioned_concurrency_config" "function_concurrency" {
  function_name = aws_lambda_function.function.function_name
  provisioned_concurrent_executions = local.function_provisioned_concurrency
  qualifier = aws_lambda_alias.function_alias.name
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

### Lambda X-Ray

```hcl
resource "aws_iam_role_policy_attachment" "xray_policy" {
  role = module.role.role_name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_lambda_function" "function" {
  role = module.role.role_arn
  tracing_config {
    mode = "Active"
  }
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

FUNCTION=
REGION=

ALIAS=

(cd $BUILD_DIRECTORY && mv $BUILD_FILE_NAME "$HANDLER_FILE_NAME" && zip "$DEPLOYMENT_OBJECT_KEY" "$HANDLER_FILE_NAME")

aws s3 sync $BUILD_DIRECTORY s3://"$DEPLOYMENT_BUCKET" --delete --region "$REGION"

VERSION=$(aws lambda update-function-code --function-name "$FUNCTION" --s3-bucket "$DEPLOYMENT_BUCKET" --s3-key "$DEPLOYMENT_OBJECT_KEY" --publish --region "$REGION" | jq '.Version | tonumber')

aws lambda update-alias --function-name "$FUNCTION" --name "$ALIAS" --function-version "$VERSION" --region "$REGION"
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
  memory_size = 256
  timeout = 6
}
```

```dockerfile
FROM node:12-alpine as build-image
WORKDIR /application/
COPY package*.json ./
COPY tsconfig.json ./
COPY ./src ./src
RUN npm ci
RUN npx tsc

FROM public.ecr.aws/lambda/nodejs:12
COPY package*.json ./
COPY .env* ./
COPY --from=build-image ./application/dist ./dist
RUN npm ci --production
CMD [ "dist/serverless.handler" ]
```

```bash
#!/bin/bash

ACCOUNT_ID=

REGION=

REPOSITORY=

TAG="latest"

FUNCTION=

IMAGE_URI=

ALIAS=

ENVIRONMENT_VARIABLES=

docker tag "$REPOSITORY:$TAG" "$IMAGE_URI"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker push "$IMAGE_URI"

aws lambda update-function-configuration --function-name "$FUNCTION" --environment "Variables=$ENVIRONMENT_VARIABLES" --region "$REGION"

VERSION=$(aws lambda update-function-code --function-name "$FUNCTION" --image-uri "$IMAGE_URI" --publish --region "$REGION" | jq '.Version | tonumber')

aws lambda update-alias --function-name "$FUNCTION" --name "$ALIAS" --function-version "$VERSION" --region "$REGION"
```

### Lambda API Gateway trigger

```hcl
module "api_gateway_trigger" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-api-gateway-trigger"
  function_name = aws_lambda_function.function.function_name
}
```

If you have configured provisioned concurrency using an alias, you need to make sure API Gateway is triggering that
published alias version instead of the $LATEST version.

```hcl
module "api_gateway_trigger" {
  source = "github.com/botre/terraform-recipes/modules/aws/lambda-api-gateway-trigger"
  function_name = aws_lambda_function.function.function_name
  alias_name = aws_lambda_alias.alias.name
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

```hcl
resource "aws_lambda_function" "function" {
  lifecycle {
    ignore_changes = [
      environment
    ]
  }
}
```

### Lambda scheduled trigger

```hcl
module "scheduled_trigger" {
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
  source = "github.com/botre/terraform-recipes/modules/aws/iam-ses-send-policy"
  role_name = module.role.role_name
}
```

### API Gateway logging account permission

```hcl
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-global"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_role_policy" {
  name = "default"
  role = aws_iam_role.api_gateway_cloudwatch_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
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
  resource_arn = module.api_gateway_trigger.gateway_stage_arn
  web_acl_arn = aws_wafv2_web_acl.api_firewall.arn
}
```

### Elastic Beanstalk Node.js Single-Instance

```hcl
# S3 bucket to store EB task definitions
resource "aws_s3_bucket" "eb_task_definitions" {
  bucket = "${var.application_name}-eb-task-definitions"
  force_destroy = true
}

# ECR for Docker images
resource "aws_ecr_repository" "container_repository" {
  name = var.application_name
}

# EB instance profile
resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "${var.application_name}-eb-instance-profile"
  role = aws_iam_role.eb_instance_role.name
}

resource "aws_iam_role" "eb_instance_role" {
  name = "${var.application_name}-eb-instance-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# EB instance policy
# Overriding because by default Beanstalk does not have a permission to Read ECR
resource "aws_iam_role_policy" "eb_instance_policy" {
  name = "${var.application_name}-eb-instance-policy"
  role = aws_iam_role.eb_instance_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:PutMetricData",
        "ds:CreateComputer",
        "ds:DescribeDirectories",
        "ec2:DescribeInstanceStatus",
        "logs:*",
        "ssm:*",
        "ec2messages:*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# EB application
resource "aws_elastic_beanstalk_application" "eb_application" {
  name = var.application_name
  description = var.application_description
}

# EB environment
resource "aws_elastic_beanstalk_environment" "eb_environment" {
  name = "${var.application_name}-${var.application_environment}"
  application = aws_elastic_beanstalk_application.eb_application.name
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.15.1 running Docker 19.03.6-ce"
  tier = "WebServer"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "EnvironmentType"
    value = "SingleInstance"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name = "MaxSize"
    value = "1"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = aws_iam_instance_profile.eb_instance_profile.name
  }
}
```

```bash
#!/bin/bash

set -e

SECONDS=0

echo "deploy started"

AWS_ACCOUNT_ID=$1
AWS_REGION=$2
APPLICATION_NAME=$3
APPLICATION_ENVIRONMENT=$4
APPLICATION_VERSION=$APPLICATION_ENVIRONMENT-$(date +%s)
APPLICATION_PORT=$5
S3_BUCKET=$APPLICATION_NAME-eb-task-definitions
S3_FILE="$APPLICATION_VERSION".zip
DIST_DIRECTORY="dist"

echo Deploying "$APPLICATION_NAME", stage: "$APPLICATION_ENVIRONMENT", region: "$AWS_REGION", version: "$APPLICATION_VERSION"

aws configure set default.region "$AWS_REGION"
aws configure set default.output json

echo Connecting to ECR
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo Building image
docker build -t "$APPLICATION_NAME:$APPLICATION_VERSION" .

echo Tagging image
docker tag "$APPLICATION_NAME:$APPLICATION_VERSION" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APPLICATION_NAME:$APPLICATION_VERSION"

echo Pushing to ECR
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APPLICATION_NAME:$APPLICATION_VERSION"

echo Creating Dockerrun
rm -rf $DIST_DIRECTORY
mkdir -p $DIST_DIRECTORY
cat >$DIST_DIRECTORY/Dockerrun.aws.json <<EOF
{
  "AWSEBDockerrunVersion": "1",
  "Image": {
    "Name": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APPLICATION_NAME:$APPLICATION_VERSION",
    "Update": "true"
  },
  "Ports": [
    {
      "ContainerPort": "$APPLICATION_PORT"
    }
  ]
}
EOF

echo Zipping Dockerrun
zip -j "$DIST_DIRECTORY/$S3_FILE" "$DIST_DIRECTORY/Dockerrun.aws.json"

echo Uploading Dockerrun
aws s3 cp "$DIST_DIRECTORY/$S3_FILE" "s3://$S3_BUCKET/$S3_FILE"

echo Creating new Beanstalk application version
aws elasticbeanstalk create-application-version --application-name "$APPLICATION_NAME" --version-label "$APPLICATION_VERSION" --source-bundle S3Bucket="$S3_BUCKET",S3Key="$S3_FILE"

echo Updating Beanstalk environment
aws elasticbeanstalk update-environment --environment-name "$APPLICATION_NAME"-"$APPLICATION_ENVIRONMENT" --version-label "$APPLICATION_VERSION"

duration=$SECONDS

echo "deploy finished ($duration seconds)"
```

```Dockerfile
FROM node:12-alpine

# Create app directory
WORKDIR /usr/src/application

ENV NODE_ENV ci

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy application source
COPY . .

# Compile TS
RUN npm run build

ENV NODE_ENV production

# Expose port and start server
EXPOSE 8080
CMD ["npm", "run", "start"]
```
