# Create the secret in Secrets Manager
resource "aws_secretsmanager_secret" "datadog_api_key" {
  name = "datadog/api_key"
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.datadog_api_key  # Only needed for initial setup
}

# Add permissions to ECS execution role to read secrets
resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "ecs-execution-role-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.datadog_api_key.arn
        ]
      }
    ]
  })
}

# Update the ECS task definition to use the secret
resource "aws_ecs_task_definition" "app" {
  family                   = "app-with-datadog"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "application"
      image = var.app_image
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DD_ENV"
          value = var.environment
        },
        {
          name  = "DD_SERVICE"
          value = "your-api-name"
        }
      ]
    },
    {
      name  = "datadog-agent"
      image = "public.ecr.aws/datadog/agent:latest"
      essential = true
      environment = [
        {
          name  = "DD_SITE"
          value = "datadoghq.com"
        },
        {
          name  = "ECS_FARGATE"
          value = "true"
        },
        {
          name  = "DD_APM_ENABLED"
          value = "true"
        },
        {
          name  = "DD_APM_NON_LOCAL_TRAFFIC"
          value = "true"
        }
      ],
      secrets = [
        {
          name      = "DD_API_KEY"
          valueFrom = aws_secretsmanager_secret.datadog_api_key.arn
        }
      ]
      portMappings = [
        {
          containerPort = 8126
          protocol      = "tcp"
        }
      ]
    }
  ])
}
