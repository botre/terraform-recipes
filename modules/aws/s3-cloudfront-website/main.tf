resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl = "public-read"
  force_destroy = true
  policy = jsonencode({
    "Version": "2008-10-17",
    "Statement": [
      {
        Sid: "PublicReadForGetBucketObjects",
        Effect: "Allow",
        Principal: {
          "AWS": "*"
        },
        Action: "s3:GetObject",
        Resource: "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
  website {
    index_document = "index.html"
    error_document = var.error_document
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.website_endpoint
    origin_id = "origin"
    custom_origin_config {
      http_port = "80"
      https_port = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [
        "TLSv1",
        "TLSv1.1",
        "TLSv1.2"
      ]
    }
  }
  aliases = var.record_aliases
  enabled = "true"
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]
    cached_methods = [
      "GET",
      "HEAD"
    ]
    target_origin_id = "origin"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
    compress = true
  }
  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "record" {
  count = length(var.record_aliases)
  name = var.record_aliases[count.index]
  zone_id = var.hosted_zone_id
  type = "A"
  alias {
    name = aws_cloudfront_distribution.distribution.domain_name
    zone_id = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}