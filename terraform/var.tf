variable "ami_id" {
  description = "ID of AMI to use for the instance"
  default     = "ami-0be2609ba883822ec"
}

variable "aws_instance_type" {
  description = "The type of instance to start"
  default     = "t2.micro"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "ansible_user" {
  default = "ubuntu"
}
