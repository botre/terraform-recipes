resource "aws_ses_domain_identity" "email_domain_identity" {
  domain = var.email_domain_name
}

resource "aws_route53_record" "email_identity_record" {
  zone_id = data.aws_route53_zone.hosted_zone.id
  name = "_amazonses.${var.email_domain_name}"
  type = "TXT"
  ttl = "600"
  records = [
    aws_ses_domain_identity.email_domain_identity.verification_token,
  ]
}
resource "aws_ses_domain_dkim" "email_dkim" {
  domain = aws_ses_domain_identity.email_domain_identity.domain
}

resource "aws_route53_record" "email_dkim_records" {
  count = 3
  zone_id = data.aws_route53_zone.hosted_zone.id
  name = "${element(aws_ses_domain_dkim.email_dkim.dkim_tokens, count.index)}._domainkey.${var.email_domain_name}"
  type = "CNAME"
  ttl = "600"
  records = [
    "${element(aws_ses_domain_dkim.email_dkim.dkim_tokens, count.index)}.dkim.amazonses.com",
  ]
}

