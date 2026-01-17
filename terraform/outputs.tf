output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = aws_instance.jenkins_instance.public_ip
}

output "tomcat_private_ip" {
  description = "The private IP address of the Tomcat server"
  value       = aws_instance.tomcat_instance.private_ip
}

output "tomcat_public_ip" {
  description = "The public IP address of the Tomcat server"
  value       = aws_instance.tomcat_instance.public_ip
}