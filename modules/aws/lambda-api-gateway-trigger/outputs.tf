output "gateway_rest_api_name" {
  value = aws_api_gateway_rest_api.gateway_rest_api.name
}

output "gateway_deployment_stage_name" {
  value = aws_api_gateway_deployment.gateway_deployment.stage_name
}

output "gateway_deployment_invoke_url" {
  value = aws_api_gateway_deployment.gateway_deployment.invoke_url
}

output "gateway_stage_arn" {
  value = "${aws_api_gateway_rest_api.gateway_rest_api.arn}/stages/${aws_api_gateway_deployment.gateway_deployment.stage_name}"
}