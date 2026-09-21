provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_vpc" "primary" {
  default = true
}

data "aws_subnets" "primary" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }
  filter {
    name   = "availability-zone"
    values = [for az in data.aws_availability_zones.primary.names : az if !contains(var.excluded_azs, az)]
  }
}

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_ami" "primary" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_vpc" "secondary" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.secondary
  default  = true
}

data "aws_subnets" "secondary" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.secondary
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.secondary[0].id]
  }
  filter {
    name   = "availability-zone"
    values = [for az in data.aws_availability_zones.secondary[0].names : az if !contains(var.excluded_azs, az)]
  }
}

data "aws_availability_zones" "secondary" {
  count    = var.environment == "prod" ? 1 : 0
  provider = aws.secondary
  state    = "available"
}

data "aws_ami" "secondary" {
  count       = var.environment == "prod" ? 1 : 0
  provider    = aws.secondary
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "primary" {
  name        = "${var.project_name}-${var.environment}-primary-sg"
  description = "Primary region SG"
  vpc_id      = data.aws_vpc.primary.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-${var.environment}-primary-sg" }
}

resource "aws_security_group" "secondary" {
  count       = var.environment == "prod" ? 1 : 0
  provider    = aws.secondary
  name        = "${var.project_name}-${var.environment}-secondary-sg"
  description = "Secondary region SG"
  vpc_id      = data.aws_vpc.secondary[0].id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-${var.environment}-secondary-sg" }
}

resource "aws_instance" "primary" {
  count                  = var.environment == "prod" ? var.instance_count - 1 : var.instance_count
  ami                    = data.aws_ami.primary.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.primary.ids[count.index % length(data.aws_subnets.primary.ids)]
  vpc_security_group_ids = [aws_security_group.primary.id]
  tags                   = { Name = "${var.project_name}-${var.environment}-primary-${count.index + 1}" }
}

resource "aws_instance" "secondary" {
  count                  = var.environment == "prod" ? 1 : 0
  provider               = aws.secondary
  ami                    = data.aws_ami.secondary[0].id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.secondary[0].ids[count.index % length(data.aws_subnets.secondary[0].ids)]
  vpc_security_group_ids = [aws_security_group.secondary[0].id]
  tags                   = { Name = "${var.project_name}-${var.environment}-secondary-${count.index + 1}" }
}