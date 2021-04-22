resource "aws_api_gateway_rest_api" "gateway_rest_api" {
  name = "${data.aws_lambda_function.function.function_name}-api"
}

resource "aws_api_gateway_resource" "gateway_proxy_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  parent_id = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
  path_part = "{proxy+}"
}

resource "aws_api_gateway_method" "gateway_any_method" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id = aws_api_gateway_resource.gateway_proxy_resource.id
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "gateway_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id = aws_api_gateway_method.gateway_any_method.resource_id
  http_method = aws_api_gateway_method.gateway_any_method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = var.alias_name != "" ? data.aws_lambda_alias.alias[0].invoke_arn : data.aws_lambda_function.function.invoke_arn
}

resource "aws_api_gateway_method" "gateway_root_method" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "gateway_root_integration" {
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  resource_id = aws_api_gateway_method.gateway_root_method.resource_id
  http_method = aws_api_gateway_method.gateway_root_method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = var.alias_name != "" ? data.aws_lambda_alias.alias[0].invoke_arn : data.aws_lambda_function.function.invoke_arn
}

resource "aws_api_gateway_deployment" "gateway_deployment" {
  depends_on = [
    aws_api_gateway_integration.gateway_proxy_integration,
    aws_api_gateway_integration.gateway_root_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
  stage_name = var.stage_name
}

resource "aws_lambda_permission" "lambda_gateway_permission" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.function.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.gateway_rest_api.execution_arn}/*/*"
  qualifier = var.alias_name != "" ? var.alias_name : null
}