
provider "aws" {
    region = "us-east-2"
    }

resource "aws_instance" "example" {
    ami         = "ami-015627ae848dee040"
    instance_type = "t2.micro"

    tags = {
        Name = "example-instance"
    }
}