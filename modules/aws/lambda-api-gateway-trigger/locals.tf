locals {
  uri = var.alias_name != "" ? data.aws_lambda_alias.alias[0].invoke_arn : data.aws_lambda_function.function.invoke_arn
}