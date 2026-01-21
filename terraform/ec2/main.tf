# VPC
resource "aws_vpc" "devops_vpc" {
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, {
    Name = "${var.project}-vpc"
  })
}

# Subnet
resource "aws_subnet" "devops_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-public-subnet"
  })
}

# Internet gateway
resource "aws_internet_gateway" "devops_igw" {
  vpc_id = aws_vpc.devops_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project}-igw"
  })
}

# Route table
resource "aws_route_table" "devops_rt" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-rt"
  })
}

# Associate route table with subnet
resource "aws_route_table_association" "devops_rt_assoc" {
  subnet_id      = aws_subnet.devops_subnet.id
  route_table_id = aws_route_table.devops_rt.id
}

# Security Group - Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project}-jenkins-sg"
  description = "Jenkins SG - Allow SSH and HTTP"
  vpc_id      = aws_vpc.devops_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project}-jenkins-sg"
  })
}

# Ingress rules for Jenkins SG
resource "aws_vpc_security_group_ingress_rule" "jenkins" {
  for_each = local.jenkins_ingress_rules

  security_group_id = aws_security_group.jenkins_sg.id
  description       = each.value.description
  cidr_ipv4         = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6         = lookup(each.value, "cidr_ipv6", null)
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
}

# Outbound traffic allowed to everywhere (Internet and other AWS resources)
resource "aws_vpc_security_group_egress_rule" "jenkins" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.jenkins_sg.id
  description       = each.value.description
  cidr_ipv4         = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6         = lookup(each.value, "cidr_ipv6", null)
  ip_protocol       = each.value.ip_protocol
}

# Security Group - Tomcat
resource "aws_security_group" "tomcat_sg" {
  name        = "${var.project}-tomcat-sg"
  description = "Tomcat SG - Allow SSH and HTTP"
  vpc_id      = aws_vpc.devops_vpc.id

  tags = merge(local.common_tags, {
    Name = "${var.project}-tomcat-sg"
  })
}

# Ingress rules for Tomcat SG
resource "aws_vpc_security_group_ingress_rule" "tomcat" {
  for_each = local.tomcat_ingress_rules

  security_group_id            = aws_security_group.tomcat_sg.id
  description                  = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
}

resource "aws_vpc_security_group_egress_rule" "tomcat" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.tomcat_sg.id
  description       = each.value.description
  cidr_ipv4         = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6         = lookup(each.value, "cidr_ipv6", null)
  ip_protocol       = each.value.ip_protocol
}

# EC2 instances for Jenkins and Tomcat
resource "aws_instance" "app" {
  for_each = local.instances

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.devops_subnet.id
  vpc_security_group_ids      = [each.value.security_group_id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  tags = merge(local.common_tags, {
    Name = "${var.project}-${each.value.name}"
    Role = each.value.name
  })
}