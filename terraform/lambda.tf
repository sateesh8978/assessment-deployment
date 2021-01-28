
resource "aws_iam_role_policy" "lambda_policy" {
    name = "lambda_policy"
    role = aws_iam_role.lambda_role.id
    policy = file("iam/lambda_policy.json")
  
}

resource "aws_iam_role" "lambda_role" {
    name = "lambda_role"
    assume_role_policy = file("iam/lambda_role.json")
  
}


locals {
  lambda_zip_location = "outputs/test_script.zip"
}

data "archive_file" "script" {
  type        = "zip"
  source_file = "test_script/test_script.yaml"
  output_path = local.lambda_zip_location

}

resource "aws_lambda_function" "test_lambda" {
  filename      = local.lambda_zip_location
  function_name = "test_script"
  role          = aws_iam_role.lambda_role.arn
  handler       = "test_script.nginx"

  #source_code_hash = filebase64sha256(local.lambda_zip_location)

  runtime = "node.js"

}

