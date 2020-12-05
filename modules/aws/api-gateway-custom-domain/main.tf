resource "aws_api_gateway_domain_name" "custom_domain_name" {
  domain_name = var.domain_name
  certificate_arn = data.aws_acm_certificate.certificate.arn
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id = data.aws_api_gateway_rest_api.rest_api.id
  stage_name = var.gateway_deployment_stage_name
  domain_name = aws_api_gateway_domain_name.custom_domain_name.domain_name
}

resource "aws_route53_record" "custom_domain_record" {
  name = var.domain_name
  zone_id = data.aws_route53_zone.hosted_zone.id
  type = "A"
  alias {
    name = aws_api_gateway_domain_name.custom_domain_name.cloudfront_domain_name
    zone_id = aws_api_gateway_domain_name.custom_domain_name.cloudfront_zone_id
    evaluate_target_health = false
  }
}