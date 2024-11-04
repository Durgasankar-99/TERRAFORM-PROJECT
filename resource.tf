resource "aws_launch_configuration" "app_lc" {
  name          = "app_lc"
  image_id     = "ami-04a37924ffe27da53" # Update to the latest Amazon Linux 2 AMI for us-east-1
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_http.id]
  key_name      = "ter123" # Replace with your key pair name

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  enable_deletion_protection = false

  tags = {
    Name = "app-lb"
  }
}

resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id  # Ensure this references the correct VPC

  health_check {
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    path                = "/"
    port                = 80
    protocol            = "HTTP"
  }

  tags = {
    Name = "app-target-group"
  }
}
resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "default" {
  identifier         = "mydbinstance"
  engine             = "mysql"
  engine_version     = "5.7"  # Change to a supported version
  instance_class     = "db.t3.micro"  # Use a supported instance class
  allocated_storage   = 20
  username           = "admin"
  password           = "password" # Change to a secure password
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  skip_final_snapshot = true

  tags = {
    Name = "mydbinstance"
  }
}
resource "aws_security_group" "allow_http" {
  vpc_id = aws_vpc.main.id  # Ensure this references the correct VPC
  name    = "allow_http"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22  # Allow SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change this to your IP for more security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP and SSH"
  }
}
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-2"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-ig"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "main-route-table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}
resource "aws_autoscaling_group" "app_asg" {
  launch_configuration = aws_launch_configuration.app_lc.id
  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tag {
    key                 = "Name"
    value               = "AutoScaledApp"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}