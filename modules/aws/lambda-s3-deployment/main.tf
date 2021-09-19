resource "aws_s3_bucket" "deployment_bucket" {
  bucket        = var.deployment_bucket_name
  acl           = "private"
  force_destroy = true
}

data "archive_file" "zip" {
  type        = "zip"
  output_path = "./tmp/dummy-lambda.zip"
  source {
    filename = "${var.handler_file_name}.js"
    content  = <<EOF
module.exports.${var.handler_function_name} = (event, context, callback) => {
  console.log("Hello, Dummy Lambda!");
  callback(null, {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello, World!",
    }),
  });
};
EOF
  }
}

resource "aws_s3_bucket_object" "deployment_object" {
  key    = var.deployment_object_key
  bucket = aws_s3_bucket.deployment_bucket.id
  source = data.archive_file.zip.output_path
}