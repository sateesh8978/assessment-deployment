provider "aws" {
  region                  = var.aws_region
  shared_credentials_file = ".aws/credentials"
}

resource "aws_instance" "Test-EC2" {
  ami           = var.ami_id
  instance_type = var.aws_instance_type


  tags = {
    Name = "Test-EC2"
  }
}

resource "aws_sqs_queue" "test_queue" {
  name = "terraform-test-queue"
  tags = {
    Environment = "QA"
  }
}
resource "aws_subnet" "test_subnet" {
  vpc_id     = "${aws_vpc.demovpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
}


resource "aws_db_subnet_group" "test_dbsubnet" {
  name       = "main"
  subnet_ids = ["${aws_subnet.test_subnet}"]

  tags {
    Name = "My SQL DB subnet group"
  }
}

resource "aws_lambda_mysql_function" "MysqlForLambda" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  instance_class       = "db.t2.micro"
  name                 = "test"
  username             = "dbmaster"
  password             = "Pass1234"
  db_subnet_group_name = "${aws_db_subnet_group.demo_dbsubnet.id}"
  vpc_security_group_ids = ["${list("${aws_security_group.demosg.id}")}"]
  final_snapshot_identifier = "someid"
  skip_final_snapshot  = true
}



resource "aws_iam_role" "lambda_role" {
  name = "lambda-vpc-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
    role       = "${aws_iam_role.lambda_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "aws_lambda_mysql_function" {
  filename         = "app.zip"
  function_name    = "AWSLambdaExecutionCounter"
  role             = "arn:aws:iam::${var.account_id}:role/lambda-vpc-execution-role"
  handler          = "app.handler"
  runtime          = "python3.6"
  source_code_hash = "${base64sha256(file("${data.archive_file.lambda.output_path}"))}"
  vpc_config {
      subnet_ids = ["${aws_subnet.test_subnet.id}"]
      security_group_ids = ["${list("${aws_security_group.demosg.id}")}"]
  }
  environment {
    variables = {
      rds_endpoint = "${aws_db_instance.MysqlForLambda.endpoint}"
    }
  }
}

resource "aws_api_gateway_rest_api" "MyDemoAPI" {
  name        = "MyDemoAPI"
  description = "This is my API for demonstration purposes"
}

resource "aws_api_gateway_resource" "mysqldb_Resource" {
  rest_api_id = "${aws_api_gateway_rest_api.MyDemoAPI.id}"
  parent_id   = "${aws_api_gateway_rest_api.MyDemoAPI.root_resource_id}"
  path_part   = "mysqldb_Resource"
}

resource "aws_api_gateway_method" "SQS_INSERT" {
  rest_api_id   = "${aws_api_gateway_rest_api.MyDemoAPI.id}"
  resource_id   = "${aws_api_gateway_resource.mysqldb_Resource.id}"
  http_method   = "ANY"
  authorization = "NONE"
}


resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.MyDemoAPI.id}"
  resource_id             = "${aws_api_gateway_resource.mysqldb_Resource.id}"
  http_method             = "${aws_api_gateway_method.SQS_INSERT.test}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/${aws_lambda_function.test_lambda.arn}/invocations"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_lambda.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-west-2:${var.account_id}:${aws_api_gateway_rest_api.MyDemoAPI.id}/*/${aws_api_gateway_method.SQS_INSERT.test}${aws_api_gateway_resource.MyDemoResource.path}"
}

resource "aws_api_gateway_deployment" "dev" {
  depends_on = ["aws_api_gateway_integration.integration"]
  rest_api_id = "${aws_api_gateway_rest_api.MyDemoAPI.id}"
  stage_name = "dev"
}


# Ansible requires Python to be installed on the remote machine as well as the local machine.
  provisioner "remote-exec" {
    inline = ["sudo apt-get -qq install python -y"]
  }

  connection {
    private_key = file(var.private_key)
    user        = "ubuntu"
  }

 provisioner "local-exec" {
    command = "ansible-playbook -u "var.ansible_user" -i " aws_instance.public_ip " --private-key" var.ssh_key_private" ~/Ansible/nginx.yaml" 
  }

resource "aws_security_group" "web" {
  name        = "default-web-example"
  description = "Security group for web that allows web traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "web-example-default-vpc"
  }
}


resource "aws_security_group" "ssh" {
  name        = "default-ssh-example"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "ssh-example-default-vpc"
  }
}

# Allow the web app to receive requests on port 8080
resource "aws_security_group" "web_server" {
  name        = "default-web_server-example"
  description = "Default security group that allows to use port 8080"
  #vpc_id      = "${aws_vpc.my-vpc.id}"
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "web_server-example-default-vpc"
  }
}