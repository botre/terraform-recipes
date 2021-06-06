output "s3_bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}

output "s3_bucket_id" {
  value = aws_s3_bucket.bucket.id
}

output "s3_bucket_region" {
  value = aws_s3_bucket.bucket.region
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.distribution.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.distribution.id
}