variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "brain-task"
}

variable "cluster_name" {
  default = "brain-task-eks"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "instance_type" {
  default = "t3.medium"
}
