# an example instance in the private subnet
resource "aws_instance" "private_instance" {
  instance_type          = "t4g.micro"
  iam_instance_profile   = aws_iam_instance_profile.private_instance.name
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.private_instance.id]

  tags = {
    Name = "example-terraform-aws-nat-instance"
  }

  user_data = <<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
EOF
}

resource "aws_security_group" "private_instance" {
  name        = "example-terraform-aws-nat-instance"
  description = "expose http service"
  vpc_id      = module.vpc.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [module.nat.sg_id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# enable SSM access
resource "aws_iam_instance_profile" "private_instance" {
  role = aws_iam_role.private_instance.name
}

resource "aws_iam_role" "private_instance" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.private_instance.name
}

output "private_instance_id" {
  value = aws_instance.private_instance.id
}
