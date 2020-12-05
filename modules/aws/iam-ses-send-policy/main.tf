resource "aws_iam_policy" "policy" {
  name = "${data.aws_iam_role.role.name}-ses-send-policy"
  path = "/"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Action": [
              "ses:SendEmail",
              "ses:SendRawEmail"
          ],
          "Resource": "*"
      }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attachment" {
  role = data.aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}