resource "aws_acm_certificate" "certificate" {
  provider = aws.aws-us-east-1
  domain_name = var.certificate_domain_name
  subject_alternative_names = var.certificate_alternate_domain_names
  validation_method = "DNS"
}

resource "aws_route53_record" "validation_record" {
  name = aws_acm_certificate.certificate.domain_validation_options[0].resource_record_name
  type = aws_acm_certificate.certificate.domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  records = [
    aws_acm_certificate.certificate.domain_validation_options[0].resource_record_value]
  ttl = 60
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  provider = aws.aws-us-east-1
  certificate_arn = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [
    aws_route53_record.validation_record.fqdn,
  ]
}