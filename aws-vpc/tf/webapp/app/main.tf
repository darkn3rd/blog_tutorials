#####################################################################
# Data - fetch ami id from any region
#####################################################################
data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0*"]
  }

  owners = ["137112412989"] # Amazon
}

#####################################################################
# Instances
#####################################################################
resource "aws_instance" "w1-webserver" {
  ami           = "${data.aws_ami.amazon-linux-2.id}"
  instance_type = "t2.micro"
  key_name      = "webone"
  user_data     = "${file("${path.module}/user_data.sh")}"

  associate_public_ip_address = true
  subnet_id                   = "${var.sn_web}"

  vpc_security_group_ids = [
    "${var.sg_web}",
  ]

  tags {
    "Name" = "w1-webserver"
    "Site" = "web-one"
  }
}
