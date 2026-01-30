data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-${var.environment}-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:tier"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:tier"
    values = ["private"]
  }
}

module "app" {
  source = "../../modules/alb-ec2"

  app_name           = var.app_name
  environment        = var.environment
  vpc_id             = data.aws_vpc.selected.id
  public_subnet_ids  = sort(data.aws_subnets.public.ids)
  private_subnet_ids = sort(data.aws_subnets.private.ids)
  instance_type      = var.instance_type
  allowed_http_cidrs = var.allowed_http_cidrs
  enable_ssm         = var.enable_ssm
  tags               = var.tags
}
