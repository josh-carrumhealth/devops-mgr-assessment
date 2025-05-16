resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "staging-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = toset([var.availability_zones[0]])

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[0]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "staging-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = toset([var.availability_zones[0]])

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[0]
  availability_zone = each.key

  tags = {
    Name = "staging-private-subnet-${each.key}"
  }
}


resource "aws_ecs_cluster" "main" {
  name = "staging-cluster"
}

resource "aws_ecs_task_definition" "api" {
  family                   = "api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "nginx"
      portMappings = [{
        containerPort = 80
        protocol      = "tcp"
      }]
      environment = [
        {
          name  = "DB_PASSWORD"
          value = var.db_password
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.private.id]
    assign_public_ip = false
    security_groups = []
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}

resource "aws_lb" "api_alb" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public["us-west-2a"].id]

  tags = {
    Environment = "staging"
  }
}

resource "aws_lb_target_group" "api" {
  name     = "api-targets"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "13.7"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = var.db_password
  publicly_accessible  = true            
  skip_final_snapshot  = true            
  vpc_security_group_ids = []

  tags = {
    Name = "staging-db"
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecsTaskPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/api"
  retention_in_days = 1
}

