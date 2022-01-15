# =========| ECR |=========

resource "aws_ecr_repository" "ecr_repository" {
  name = local.repository_name
}


# =========| ECS |=========

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}-cluster"
}

data "template_file" "cb_app" {
  template = file(var.taskdef_template)

  vars = {
    app_image      = local.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
    env            = var.environment
    app_name       = var.app_name
    image_tag      = var.image_tag
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-${var.environment}-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions = jsonencode([{
    name        = "first"
    image       = "692807581431.dkr.ecr.eu-west-2.amazonaws.com/utilities-dev:v.1"
    essential   = true
    cpu         = 256
    memory      = 512

    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

resource "aws_ecs_service" "main" {
  name            = "${var.app_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.alb-security-group.id]
    subnets          = ["${aws_subnet.private-subnet-1.id}", "${aws_subnet.private-subnet-2.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.asg.id
    container_name   = "first"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.http, aws_iam_role_policy.ecs_task_execution_role]
}