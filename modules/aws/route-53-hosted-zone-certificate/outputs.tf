output "certificate_domain_name" {
  value = aws_acm_certificate.certificate.domain_name
}

output "certificate_record_name" {
  value = aws_route53_record.validation_record.name
}

output "certificate_record_type" {
  value = aws_route53_record.validation_record.type
}

output "certificate_record_value" {
  value = aws_acm_certificate.certificate.domain_validation_options[0].resource_record_value
  sensitive = true
}