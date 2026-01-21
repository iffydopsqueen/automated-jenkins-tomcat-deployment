locals {
  common_tags = {
    Project = var.project
  }

  jenkins_ingress_rules = {
    ssh_ipv4 = {
      description = "SSH access from allowed IPv4"
      cidr_ipv4   = var.allowed_ipv4_cidr
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
    }
    ssh_ipv6 = {
      description = "SSH access from allowed IPv6"
      cidr_ipv6   = var.allowed_ipv6_cidr
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
    }
    ui_ipv4 = {
      description = "Jenkins UI - Allow on port 8080 (IPv4)"
      cidr_ipv4   = var.allowed_ipv4_cidr
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
    }
    ui_ipv6 = {
      description = "Jenkins UI - Allow on port 8080 (IPv6)"
      cidr_ipv6   = var.allowed_ipv6_cidr
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
    }
  }

  tomcat_ingress_rules = {
    from_jenkins_ui = {
      description                  = "Tomcat from Jenkins SG"
      referenced_security_group_id = aws_security_group.jenkins_sg.id
      from_port                    = 8080
      to_port                      = 8080
      ip_protocol                  = "tcp"
    }
    ssh_from_jenkins = {
      description                  = "SSH from Jenkins SG for deployment"
      referenced_security_group_id = aws_security_group.jenkins_sg.id
      from_port                    = 22
      to_port                      = 22
      ip_protocol                  = "tcp"
    }
  }

  egress_rules = {
    all_ipv4 = {
      description = "Allow all outbound traffic (IPv4)"
      cidr_ipv4   = var.allowed_ipv4_cidr
      ip_protocol = "-1"
    }
    all_ipv6 = {
      description = "Allow all outbound traffic (IPv6)"
      cidr_ipv6   = var.allowed_ipv6_cidr
      ip_protocol = "-1"
    }
  }

  instances = {
    jenkins = {
      name              = "jenkins"
      security_group_id = aws_security_group.jenkins_sg.id
    }
    tomcat = {
      name              = "tomcat"
      security_group_id = aws_security_group.tomcat_sg.id
    }
  }
}