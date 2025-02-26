output "rds_endpoint" {
  value = aws_db_instance.spa_db.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.spa_ecr.repository_url
}

output "ec2_public_ip" {
  value = aws_instance.spa_ec2.public_ip
}

output "nameservers" {
  value = aws_route53_zone.spa_domain.name_servers
}