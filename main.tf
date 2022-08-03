resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.cidr[count.index]
  availability_zone = var.az[count.index]
  count             = 2

  tags = {
    Name = "public-sub"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1"

  tags = {
    Name = "private-sub"
  }

}

data "aws_subnet" "sid" {
  filter {
    name   = "vpc_id"
    values = [aws_vpc.main.id]
  }

  tags = {
    Tier = "Public"
  }
}

resource "aws_instance" "web" {
  ami                         = "ami-090fa75af13c156b4"
  instance_type               = "t2.micro"
  key_name                    = "themaestrokey"
  subnet_id                   = aws_subnet.public[count.index].id
  associate_public_ip_address = true
  count                       = 2

  tags = {
    Name = "webserver"
  }

  provisioner "file" {
    source      = "./themaestrokey.pem"
    destination = "/home/ec2-user/themaestrokey.pem"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ec2-user"
      private_key = "${file("./themaestrokey.pem")}"
    }
  }
}

resource "aws_instance" "db" {
  ami                    = "ami-090fa75af13c156b4"
  instance_type          = "t2.micro"
  key_name               = "themaestrokey"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.allow_tls_db.id]

  tags = {
    Name = "DBServer"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = {
    cidr_blocks = ["0.0.0.0/0"]
    description = "TLS from VPC"
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    description = "TLS from VPC"
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

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "allow_tls_db" {
  name        = "allow_tls_db"
  description = "allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = {
    cidr_blocks = ["0.0.0.0/0"]
    description = "TLS from VPC"
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls_db"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.owner_id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id

  route = {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "MyRoute"
  }
}

resource "aws_route_table_association" "asso" {
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rtb.id
  count          = 2
}


