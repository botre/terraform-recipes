resource "aws_acm_certificate" "certificate" {
  provider = aws.aws-us-east-1
  domain_name = var.certificate_domain_name
  subject_alternative_names = var.certificate_alternate_domain_names
  validation_method = "DNS"
}

resource "aws_route53_record" "validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
      zone_id = data.aws_route53_zone.hosted_zone.zone_id
    }
  }

  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
  zone_id = each.value.zone_id
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  provider = aws.aws-us-east-1
  certificate_arn = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}