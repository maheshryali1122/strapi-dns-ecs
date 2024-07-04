resource "aws_security_group" "sgfornginx" {
  vpc_id      = aws_vpc.Ecsvpcstrapi.id
  description = "This is for strapy application"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Sg-for-nginx-rm"
  }
  depends_on = [ data.external.get_task_public_ip ]

}
resource "tls_private_key" "fornginx" {
  algorithm  = "RSA"
  rsa_bits   = 4096
  depends_on = [aws_security_group.sgfornginx]

  lifecycle {
    ignore_changes = [private_key_pem, public_key_openssh]
  }
}
resource "aws_key_pair" "keypairfornginx" {
  key_name   = "keyforstrapi-rm"
  public_key = tls_private_key.fornginx.public_key_openssh
  depends_on = [ tls_private_key.fornginx ]
  lifecycle {
    ignore_changes = [public_key]  
  }
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] 
  depends_on = [ aws_key_pair.keypairfornginx ]
}

resource "aws_instance" "ec2fornginx" {
  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = "us-west-2a"
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.sgfornginx.id]
  subnet_id                   = aws_subnet.publicsubnets[0].id
  key_name                    = aws_key_pair.keypairfornginx.key_name
  associate_public_ip_address = true
  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 20
    volume_type = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "ec2fornginx-rm"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y nginx jq

    CLUSTER_NAME="${aws_ecs_cluster.strapiecscluster.name}"
    SERVICE_NAME="${aws_ecs_service.ecs_service_strapi.name}"
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query 'taskArns[0]' --output text --region ${var.aws_region})
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region ${var.aws_region})
    PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region ${var.aws_region})

    cat <<EOT > /etc/nginx/sites-available/strapi
    server {
        listen 80;
        server_name maheshr.contentecho.in;

        location / {
            proxy_pass http://$PUBLIC_IP:1337;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    EOT

    sudo ln -s /etc/nginx/sites-available/strapi /etc/nginx/sites-enabled/
    sudo rm /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
    EOF
}

