terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "hospital-microservices-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "hospital-microservices-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "hospital-microservices-subnet-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "hospital-microservices-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ecs" {
  name        = "hospital-microservices-ecs-sg"
  description = "Allow HTTP access to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3001
    to_port   = 3003
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "hospital-microservices-ecs-sg" }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "microservices.local"
  vpc  = aws_vpc.main.id
  description = "Private namespace for ECS service discovery"
}

resource "aws_service_discovery_service" "appointmentservice" {
  name = "appointmentservice"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "patientservice" {
  name = "patientservice"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "doctorservice" {
  name = "doctorservice"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "hospital-microservices-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "hospital-microservices-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "appointmentservice" {
  family                   = "appointmentservice-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "appointmentservice"
      image     = "${var.appointment_image}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 3002, protocol = "tcp" }]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3002" },
        { name = "SERVICE_NAME", value = "appointment-service" },
        { name = "DB_DIALECT", value = "mysql" },
        { name = "PATIENT_SERVICE_URL", value = "http://patientservice.microservices.local:3001" },
        { name = "DOCTOR_SERVICE_URL", value = "http://doctorservice.microservices.local:3003" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/appointmentservice"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "appointmentservice"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "patientservice" {
  family                   = "patientservice-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "patientservice"
      image     = "${var.patient_image}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 3001, protocol = "tcp" }]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3001" },
        { name = "SERVICE_NAME", value = "patient-service" },
        { name = "DB_DIALECT", value = "postgres" },
        { name = "APPOINTMENT_SERVICE_URL", value = "http://appointmentservice.microservices.local:3002" },
        { name = "DOCTOR_SERVICE_URL", value = "http://doctorservice.microservices.local:3003" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/patientservice"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "patientservice"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "doctorservice" {
  family                   = "doctorservice-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "doctorservice"
      image     = "${var.doctor_image}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 3003, protocol = "tcp" }]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3003" },
        { name = "SERVICE_NAME", value = "doctor-service" },
        { name = "DB_DIALECT", value = "postgres" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/doctorservice"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "doctorservice"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "patientportal" {
  family                   = "patientportal-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions    = jsonencode([
    {
      name      = "patient-portal"
      image     = "${var.portal_image}:${var.image_tag}"
      essential = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      environment = [
        { name = "VITE_API_URL", value = "/api/v1" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/patient-portal"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "patient-portal"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "appointmentservice" {
  name            = "appointmentservice-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.appointmentservice.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.appointmentservice.arn
    container_name   = "appointmentservice"
    container_port   = 3002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.appointmentservice.arn
  }
}

resource "aws_ecs_service" "patientservice" {
  name            = "patientservice-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.patientservice.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.patientservice.arn
    container_name   = "patientservice"
    container_port   = 3001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.patientservice.arn
  }
}

resource "aws_ecs_service" "doctorservice" {
  name            = "doctorservice-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.doctorservice.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.doctorservice.arn
    container_name   = "doctorservice"
    container_port   = 3003
  }

  service_registries {
    registry_arn = aws_service_discovery_service.doctorservice.arn
  }
}

resource "aws_ecs_service" "patientportal" {
  name            = "patientportal-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.patientportal.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.patientportal.arn
    container_name   = "patient-portal"
    container_port   = 80
  }
}

resource "aws_lb" "app" {
  name               = "hospital-microservices-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "appointmentservice" {
  name_prefix  = "appt-"
  port         = 3002
  protocol     = "HTTP"
  target_type  = "ip"
  vpc_id       = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/api/v1/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "patientservice" {
  name_prefix  = "pat-"
  port         = 3001
  protocol     = "HTTP"
  target_type  = "ip"
  vpc_id       = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/api/v1/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "doctorservice" {
  name_prefix  = "doc-"
  port         = 3003
  protocol     = "HTTP"
  target_type  = "ip"
  vpc_id       = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/api/v1/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "patientportal" {
  name_prefix  = "port-"
  port         = 80
  protocol     = "HTTP"
  target_type  = "ip"
  vpc_id       = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "appointmentservice" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appointmentservice.arn
  }
  condition {
    path_pattern {
      values = ["/api/v1/appointments*", "/api/v1/appointments"]
    }
  }
}

resource "aws_lb_listener_rule" "patientservice" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.patientservice.arn
  }
  condition {
    path_pattern {
      values = ["/api/v1/patients*", "/api/v1/patients"]
    }
  }
}

resource "aws_lb_listener_rule" "doctorservice" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.doctorservice.arn
  }
  condition {
    path_pattern {
      values = ["/api/v1/doctors*", "/api/v1/doctors"]
    }
  }
}

resource "aws_lb_listener_rule" "patientportal" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 130
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.patientportal.arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
