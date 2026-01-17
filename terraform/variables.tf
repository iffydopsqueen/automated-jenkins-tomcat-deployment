# Ubuntu Server 24.04 LTS AMI
variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
  default     = "ami-0ecb62995f68bb549"
}

variable "instance_type" {
  description = "The type of instance to use"
  type        = string
  default     = "t3.small"
}

variable "project" {
  description = "The project name"
  type        = string
  default     = "terraform"
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair to use"
  type        = string
  default     = "aws-keypair"
}