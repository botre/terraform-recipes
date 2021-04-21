data "archive_file" "inline" {
  type = "zip"
  output_path = "${path.module}/${var.name}.zip"
  source {
    content = <<EOF
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

resource "aws_iam_role" "role" {
  name = "${var.name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "function" {
  function_name = var.name
  filename = data.archive_file.inline.output_path
  source_code_hash = data.archive_file.inline.output_base64sha256
  handler = "main.handler"
  runtime = "nodejs12.x"
  role = aws_iam_role.role.arn
  memory_size = 128
  timeout = var.timeout
}

resource "aws_cloudwatch_event_rule" "rule" {
  name = "${var.name}-rule"
  schedule_expression = var.rate
}

resource "aws_cloudwatch_event_target" "target" {
  rule = aws_cloudwatch_event_rule.rule.name
  target_id = "lambda"
  arn = aws_lambda_function.function.arn
}

resource "aws_lambda_permission" "permission" {
  statement_id = "cloud-watch-${var.name}"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.rule.arn
}
