data "aws_lambda_function" "function" {
  function_name = var.function_name
}

data "aws_lambda_alias" "alias" {
  count = var.alias_name != "" ? 1 : 0
  function_name = var.function_name
  name = var.alias_name.name
}