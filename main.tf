
provider "aws" {
    region = "us-east-2"
    }

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }
    } 



resource "aws_instance" "example" {
    ami                    = "ami-015627ae848dee040"
    instance_type          = "t2.micro"
    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y python3
                echo "Hello World!" > index.html
                nohup python3 -m http.server 8080 &
                EOF
    
    user_data_replace_on_change = true

    tags = {
        Name = "example-instance"
    }
}

    output "public_ip" {
    value = aws_instance.example.public_ip
    }

