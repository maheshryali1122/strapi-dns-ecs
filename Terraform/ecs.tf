resource "aws_security_group" "sgforstrapi" {
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

    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Sg-strapi-rm"
  }
  depends_on = [ aws_route_table_association.association ]

}
resource "aws_ecs_cluster" "strapiecscluster" {
    name = "Ecs-strapi-rm"
    depends_on = [ aws_security_group.sgforstrapi]
}
resource "aws_ecs_task_definition" "strapiecstaskdefinition" {
    family = "strapiecstaskdefinition-rm"
    network_mode             = "awsvpc"
    cpu = "256"
    memory = "512"
    
    container_definitions = jsonencode([
        {
            name = "strapicontainer"
            image = "maheshryali/strapi:new"
            essential = true
            portMappings = [
                {
                    containerPort = 1337
                    hostPort = 1337
                }
            ]
        }
    ])
    requires_compatibilities = ["FARGATE"]
    execution_role_arn = aws_iam_role.Ecstaskdefnitionrole.arn
    task_role_arn = aws_iam_role.Ecstaskdefnitionrole.arn
    depends_on = [ 
        aws_ecs_cluster.strapiecscluster
     ]
}
resource "aws_ecs_service" "ecs_service_strapi" {
    name = "Strapi-ecs-service-rm"
    cluster = aws_ecs_cluster.strapiecscluster.id
    task_definition = aws_ecs_task_definition.strapiecstaskdefinition.arn
    desired_count = 1
    enable_ecs_managed_tags = true
    capacity_provider_strategy {
      capacity_provider = "FARGATE_SPOT"
      weight = 1
    }
    network_configuration {
      subnets = [aws_subnet.publicsubnets[0].id, aws_subnet.publicsubnets[1].id]
      security_groups = [aws_security_group.sgforstrapi.id]
      assign_public_ip = true
    }
    depends_on = [ aws_ecs_task_definition.strapiecstaskdefinition ]
  
}

data "external" "get_task_public_ip" {
  program = ["bash", "${path.module}/public_ip_script.sh", aws_ecs_cluster.strapiecscluster.name, aws_ecs_service.ecs_service_strapi.name]
}

output "public_ip" {
  value = data.external.get_task_public_ip.result["public_ip"]
}
resource "aws_route53_record" "subdomain" {
  zone_id = var.Hostedzoneid  
  name    = "maheshr.contentecho.in"  
  type    = "A"
  ttl     = 300

  records = [ aws_instance.ec2fornginx.public_ip ]
  depends_on = [ aws_instance.ec2fornginx ]
}



