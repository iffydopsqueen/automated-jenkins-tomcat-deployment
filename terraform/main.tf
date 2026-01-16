# VPC
resource "aws_vpc" "devops_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "${var.project}-vpc"
    }
}

# Subnet
resource "aws_subnet" "devops_subnet" {
    vpc_id            = aws_vpc.devops_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "jenkins-public-subnet"
    }
}

# Internet gateway
resource "aws_internet_gateway" "devops_igw" {
    vpc_id = aws_vpc.devops_vpc.id

    tags = {
        Name = "jenkins-igw"
    }
}

# Route table
resource "aws_route_table" "devops_rt" {
    vpc_id = aws_vpc.devops_vpc.id

    route {
        cidr_block      = "0.0.0.0/0"
        gateway_id      = aws_internet_gateway.devops_igw.id
    }

    tags = {
        Name = "jenkins-rt"
    }
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

  tags = {
    Name = "${var.project}-jenkins-sg"
  }
}

# Inbound traffic is allowed on port 22 (SSH) from any IP address (Internet and in the VPC)
# If I was using my IP address, inbound traffic would be allowed on port 22 (SSH), 
# but only if it's coming from my IP address
resource "aws_vpc_security_group_ingress_rule" "jenkins_allow_ssh_ipv4" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "SSH access from anywhere"
  cidr_ipv4         = "0.0.0.0/0" # will restrict to my IP later
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_allow_ssh_ipv6" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "SSH access from anywhere"
  cidr_ipv6         = "::/0" # will restrict to my IP later
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Inbound traffic is allowed on port 8080 (Jenkins UI) from any IP address (Internet and in the VPC)
resource "aws_vpc_security_group_ingress_rule" "jenkins_ui_ipv4" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Jenkins UI - Allow on port 8080"
  cidr_ipv4         = "0.0.0.0/0" # will restrict to my IP later
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui_ipv6" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Jenkins UI - Allow on port 8080"
  cidr_ipv6         = "::/0" # will restrict to my IP later
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

# Outbound traffic allowed to everywhere (Internet and other AWS resources)
resource "aws_vpc_security_group_egress_rule" "jenkins_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "jenkins_allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Allow all outbound traffic"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Security Group - Tomcat
resource "aws_security_group" "tomcat_sg" {
  name        = "${var.project}-tomcat-sg"
  description = "Tomcat SG - Allow SSH and HTTP"
  vpc_id      = aws_vpc.devops_vpc.id

  tags = {
    Name = "${var.project}-tomcat-sg"
  }
}

# Inbound traffic is allowed on port 8080 (Tomcat) only from Jenkins SG
resource "aws_vpc_security_group_ingress_rule" "tomcat_from_jenkins" {
  security_group_id = aws_security_group.tomcat_sg.id
  description       = "Tomcat from Jenkins SG"
  referenced_security_group_id = aws_security_group.jenkins_sg.id
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

# Inbound traffic is allowed on port 22 (SSH) only from Jenkins SG - allow Jenkins to SSH into Tomcat for deployment
resource "aws_vpc_security_group_ingress_rule" "tomcat_ssh_from_jenkins" {
  security_group_id = aws_security_group.tomcat_sg.id
  description       = "SSH from Jenkins SG for deployment"
  referenced_security_group_id = aws_security_group.jenkins_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tomcat_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.tomcat_sg.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "tomcat_allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.tomcat_sg.id
  description       = "Allow all outbound traffic"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# EC2 instance for Jenkins
resource "aws_instance" "jenkins_instance" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.devops_subnet.id
  security_groups = [ aws_security_group.jenkins_sg.id ]
  key_name        = var.key_pair_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project}-jenkins"
    Role = "jenkins"
  }
}

# EC2 instance for Tomcat
resource "aws_instance" "tomcat_instance" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.devops_subnet.id
  security_groups = [ aws_security_group.tomcat_sg.id ]
  key_name        = var.key_pair_name

  tags = {
    Name = "${var.project}-tomcat"
    Role = "tomcat"
  }
}