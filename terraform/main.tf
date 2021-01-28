provider "aws" {
  region                  = var.aws_region
  shared_credentials_file = ".aws/credentials"
}

resource "aws_instance" "Test" {
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

# Ansible requires Python to be installed on the remote machine as well as the local machine.
  provisioner "remote-exec" {
    inline = ["sudo apt-get -qq install python -y"]
  }

  connection {
    private_key = file(var.private_key)
    user        = "ubuntu"
  }

 provisioner "local-exec" {
    command = "ansible-playbook -u " var.ansible_user" -i " aws_instance.public_ip " --private-key" var.ssh_key_private" ~/Ansible-project/nginx_postgres.yaml" 
  }

resource "aws_security_group" "web" {
  name        = "default-web-example"
  description = "Security group for web that allows web traffic from internet"
 

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

