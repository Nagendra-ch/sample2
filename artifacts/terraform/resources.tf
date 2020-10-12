resource "aws_key_pair" "demo_key" {
  key_name   = "MyKeyPair"
  public_key = "file(var.public_key)"
}

resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16" # Defines overall VPC address space
  enable_dns_hostnames = true          # Enable DNS hostnames for this VPC
  enable_dns_support   = true          # Enable DNS resolving support for this VPC
  instance_tenancy     = "default"
  enable_classiclink   = "false"

  tags = {
    Name = "VPC-my-vpc" # Tag VPC with name
  }
}

resource "aws_instance" "master" {
  count = "var.instance_count"

  #ami = "${lookup(var.amis,var.region)}"
  ami           = "var.ami"
  instance_type = var.instance
  key_name      = "aws_key_pair.demo_key.key_name"

  vpc_security_group_ids = [
    "aws_security_group.master_sg.id",
    "aws_security_group.agent_sg.id"   
  ]


  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_size           = 500
    volume_type           = "io1"
    iops                  = 2000
    encrypted             = true
    delete_on_termination = true
  }

  connection {
    private_key = "file(var.private_key)"
    user        = "var.ansible_user"
  }

  # Ansible requires Python to be installed on the remote machine as well as the local machine.
  provisioner "remote-exec" {
    inline = ["sudo yum install python3 -y"]
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = "file(var.private_key)"
    }
  }

  # This is where we configure the instance with ansible-playbook  
  provisioner "local-exec" {
    command = "ansible-playbook -u ec2-user -i '${self.public_ip},' --private-key ${var.ssh_key_private} playovision.yml"
  }
    
  tags = {
    Name     = "server"    
  }
}

resource "aws_security_group" "master_sg" {
  name        = "master-security-group"
  description = "Security group for master that allows the traffic from internet and agents"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = {
    Name = "master_sg"
  }
}

# Allow the traffic from master
resource "aws_security_group" "agent_server" {
  name        = "agent-server"
  description = "Default security group that allows traffic from master"
  #vpc_id      = "${aws_vpc.my-vpc.id}"
  
  ingress {
    from_port   = 7918
    to_port     = 7918
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
    Name = "agent_sg"
  }
}
