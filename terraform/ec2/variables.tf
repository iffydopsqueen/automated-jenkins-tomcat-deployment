variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Ubuntu Server 24.04 LTS AMI
variable "ami_id" {
  description = "The AMI ID to use for the EC2 instances"
  type        = string
  default     = "ami-0ecb62995f68bb549"
}

variable "instance_type" {
  description = "The type of instance to use"
  type        = string
  default     = "t3.micro"
}

variable "project" {
  description = "The project name"
  type        = string
  default     = "terraform"
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair to use"
  type        = string
}

variable "allowed_ipv4_cidr" {
  description = "IPv4 CIDR allowed to SSH into Jenkins and access Jenkins UI"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_ipv6_cidr" {
  description = "IPv6 CIDR allowed to SSH into Jenkins and access Jenkins UI"
  type        = string
  default     = "::/0"
}