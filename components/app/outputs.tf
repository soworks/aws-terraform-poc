output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = module.app.alb_dns_name
}
