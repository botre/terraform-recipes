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

resource "aws_cloudwatch_log_group" "log_group" {
  name = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

module "role" {
  source = "../lambda-iam-role"
  prefix = var.name
}

module "logging_policy" {
  source = "../iam-logging-policy"
  role_name = module.role.role_name
}

resource "aws_lambda_function" "function" {
  function_name = var.name
  filename = data.archive_file.inline.output_path
  source_code_hash = data.archive_file.inline.output_base64sha256
  handler = "main.handler"
  runtime = "nodejs12.x"
  role = module.role.role_arn
  memory_size = 128
  timeout = var.timeout
}

module "trigger" {
  source = "../lambda-scheduled-trigger"
  function_name = aws_lambda_function.function.function_name
  rule_name = "${var.name}-trigger"
  rule_description = "${var.name}-trigger"
  rule_schedule_expression = var.rate
}