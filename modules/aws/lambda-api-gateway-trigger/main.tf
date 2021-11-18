resource "aws_api_gateway_rest_api" "gateway_rest_api" {
  name = var.api_name
}

resource "aws_api_gateway_method_settings" "gateway_settings" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  stage_name  = var.stage_name
  method_path = "*/*"
  settings {
    metrics_enabled = true
    logging_level   = var.logging_level
  }
}

resource "aws_api_gateway_resource" "gateway_proxy_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  parent_id   = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "gateway_any_method" {
  rest_api_id   = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id   = aws_api_gateway_resource.gateway_proxy_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "gateway_root_method" {
  rest_api_id   = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id   = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "gateway_any_integration" {
  rest_api_id             = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id             = aws_api_gateway_method.gateway_any_method.resource_id
  http_method             = aws_api_gateway_method.gateway_any_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.uri
}

resource "aws_api_gateway_integration" "gateway_root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id             = aws_api_gateway_method.gateway_root_method.resource_id
  http_method             = aws_api_gateway_method.gateway_root_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.uri
}

resource "aws_api_gateway_deployment" "gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      local.uri,
      aws_api_gateway_method.gateway_any_method.id,
      aws_api_gateway_method.gateway_root_method.id,
      aws_api_gateway_integration.gateway_any_integration.id,
      aws_api_gateway_integration.gateway_root_integration.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "gateway_stage" {
  deployment_id         = aws_api_gateway_deployment.gateway_deployment.id
  rest_api_id           = aws_api_gateway_rest_api.gateway_rest_api.id
  stage_name            = var.stage_name
  // See https://github.com/hashicorp/terraform-provider-aws/issues/17661
  cache_cluster_enabled = false
  cache_cluster_size    = "0.5"
}

resource "aws_cloudwatch_log_group" "gateway_execution_log_group" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.gateway_rest_api.id}/${var.stage_name}"
  retention_in_days = 7
}

resource "aws_lambda_permission" "lambda_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke-${var.api_name}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gateway_rest_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "lambda_gateway_alias_permission" {
  count         = var.alias_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeAlias-${var.api_name}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.function.function_name
  qualifier     = data.aws_lambda_alias.alias[0].name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gateway_rest_api.execution_arn}/*/*"
}