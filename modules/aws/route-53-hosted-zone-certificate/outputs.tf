output "certificate" {
  value = aws_acm_certificate.certificate
}

output "certificate_arn" {
  value = aws_acm_certificate.certificate.arn
}

output "certificate_id" {
  value = aws_acm_certificate.certificate.id
}