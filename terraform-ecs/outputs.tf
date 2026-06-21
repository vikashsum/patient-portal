output "vpc_id" {
  value = aws_vpc.main.id
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "lb_dns_name" {
  value = aws_lb.app.dns_name
}

output "appointment_task_definition_arn" {
  value = aws_ecs_task_definition.appointmentservice.arn
}

output "patient_task_definition_arn" {
  value = aws_ecs_task_definition.patientservice.arn
}

output "doctor_task_definition_arn" {
  value = aws_ecs_task_definition.doctorservice.arn
}

output "portal_task_definition_arn" {
  value = aws_ecs_task_definition.patientportal.arn
}
