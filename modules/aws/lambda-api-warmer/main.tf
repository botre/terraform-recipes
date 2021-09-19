data "archive_file" "inline" {
  type        = "zip"
  output_path = "${path.module}/${var.name}.zip"
  source {
    content  = <<EOF
const ping = ({protocol, hostname, path}) => {
    return new Promise((resolve, reject) => {
        const http = protocol === "http" ? require("http") : require("https");
        const options = {
            hostname,
            path,
            method: "GET"
        };
        const request = http.request(
            options,
            (response) => {
                response.on("data", () => {
                    resolve({
                        statusCode: response.statusCode
                    })
                });
            }
        );
        request.on("error", (error) => {
            reject(error);
        });
        request.end();
    })
}

module.exports.handler = async () => {
    const response = await ping({
        protocol: "${var.protocol}",
        hostname: "${var.hostname}",
        path: "${var.path}"
    })
    return response
}
EOF
    filename = "main.js"
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_role" "role" {
  name               = "${var.name}-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : "sts:AssumeRole",
        Effect : "Allow",
        Principal : {
          "Service" : "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "logging_policy" {
  name   = "${var.name}-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logging_policy_attachment" {
  role       = aws_iam_role.role.id
  policy_arn = aws_iam_policy.logging_policy.arn
}

resource "aws_lambda_function" "function" {
  function_name    = var.name
  filename         = data.archive_file.inline.output_path
  source_code_hash = data.archive_file.inline.output_base64sha256
  handler          = "main.handler"
  runtime          = "nodejs12.x"
  role             = aws_iam_role.role.arn
  memory_size      = 128
  timeout          = var.timeout
}

module "trigger" {
  source                   = "../lambda-scheduled-trigger"
  function_arn             = aws_lambda_function.function.arn
  function_name            = aws_lambda_function.function.function_name
  rule_name                = "${var.name}-trigger"
  rule_description         = "${var.name}-trigger"
  rule_schedule_expression = var.rate
}