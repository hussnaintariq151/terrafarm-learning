provider "aws" {
    region = "us-east-2"
    }

variable "server_port" {
  description = "Port used for HTTP requests"
  type        = number
}

# Get default VPC 
data "aws_vpc" "default" {
    default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for the instance
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"
    vpc_id = data.aws_vpc.default.id

    ingress {
        from_port   = var.server_port
        to_port     = var.server_port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        }
    } 

# Security Group for ALB
resource "aws_security_group" "alb" {
    name    = "terraform-example-alb"
    vpc_id  = data.aws_vpc.default.id

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
    }



# Launch template
resource "aws_launch_template" "example" {
    image_id                 = "ami-015627ae848dee040"
    instance_type            = "t2.micro"
    vpc_security_group_ids   = [aws_security_group.instance.id]

    user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y python3
                echo "Hello World!" > index.html
                nohup python3 -m http.server ${var.server_port} &
                EOF
    )
    lifecycle {
        create_before_destroy = true
    }
}

# Application Load Balancer
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

# Listener for ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# Target Group for ASG
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}



# Auto Scaling Group
resource "aws_autoscaling_group" "example" {
    vpc_zone_identifier = data.aws_subnets.default.ids
    launch_template {
        id      = aws_launch_template.example.id
        version = "$Latest"
    }


    min_size       = 2
    max_size       = 10

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    tag {
        key                  = "Name"
        value                = "terraform-asg-example"
        propagate_at_launch  =  true
    }
}

output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "DNS name of the Application Load Balancer"
}

    



