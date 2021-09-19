resource "aws_cloudwatch_event_rule" "rule" {
  name                = var.rule_name
  description         = var.rule_description
  schedule_expression = var.rule_schedule_expression
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.rule.name
  target_id = "lambda"
  arn       = var.function_arn
}

resource "aws_lambda_permission" "permission" {
  statement_id  = "cloud-watch-${var.rule_name}"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rule.arn
}