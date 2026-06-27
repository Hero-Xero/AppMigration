resource "aws_iam_policy" "fluent_bit_cloudwatch" {
  name = "FluentBitCloudWatchPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluent_bit_attachment" {
  policy_arn = aws_iam_policy.fluent_bit_cloudwatch.arn
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
}