output "deployment_bucket_id" {
  value = aws_s3_bucket.deployment_bucket.id
}

output "deployment_object_key" {
  value = aws_s3_bucket_object.deployment_object.key
}