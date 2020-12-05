data "aws_route53_zone" "hosted_zone" {
  name = var.hosted_zone_name
}

data "aws_acm_certificate" "certificate" {
  domain = var.certificate_domain_name
  provider = aws.aws-us-east-1
}