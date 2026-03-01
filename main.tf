# 1. VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "devops-project-vpc" }
}

# 2. Internet Access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "main-gateway" }
}

# 3. Subnet public
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
  tags                    = { Name = "public-subnet" }
}

# 4. Routing Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt.id
}

# 5. Firewall - Security Group
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main_vpc.id

  # Port SSH (22) - for remote access to servers
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Real projects should restrict this to known IPs for security
  }

  # Port HTTP (80) - for application access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (egress)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Resource - Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("my-vps-key.pub") # Public key will be get by terraform from local file
}

# 7. Creating 3 servers (Jenkins, K8s Master, K8s Worker)
# t3.micro
# Automatic selection of the latest Ubuntu 24.04 AMI in the specified region
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Dynamic ID for AMI
resource "aws_instance" "servers" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id 
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = "Server-${count.index}"
  }
}

# 8. Output - Public IPs of created servers
output "instance_ips" {
  value = aws_instance.servers[*].public_ip
}