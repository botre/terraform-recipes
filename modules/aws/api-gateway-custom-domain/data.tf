data "aws_route53_zone" "hosted_zone" {
  name = var.hosted_zone_name
}

data "aws_api_gateway_rest_api" "rest_api" {
  name = var.gateway_rest_api_name
}