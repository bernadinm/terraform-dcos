# Deploy the bootstrap instance
resource "aws_instance" "bootstrap" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "${module.aws-tested-oses.user}"
    private_key = "${local.private_key}"
    agent = "${local.agent}"

    # The connection will use the local SSH agent for authentication.
  }

  root_block_device {
    volume_size = "${var.aws_bootstrap_instance_disk_size}"
  }

  instance_type = "${var.aws_bootstrap_instance_type}"

  tags {
   owner = "${coalesce(var.owner, data.external.whoami.result["owner"])}"
   expiration = "${var.expiration}"
   Name = "${data.template_file.cluster-name.rendered}-bootstrap"
   cluster = "${data.template_file.cluster-name.rendered}"
  }

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${module.aws-tested-oses.aws_ami}"

  # The name of our SSH keypair we created above.
  key_name = "${var.ssh_key_name}"

  # Our Security group to allow http, SSH, and outbound internet access only for pulling containers from the web
  vpc_security_group_ids = ["${aws_security_group.any_access_internal.id}", "${aws_security_group.ssh.id}", "${aws_security_group.internet-outbound.id}"]


  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  #subnet_id = "${aws_subnet.public.id}"

#  network_interface {
#    network_interface_id = "${aws_network_interface.public.id}"
#    device_index         = 0
#  }
#
#  network_interface {
#    network_interface_id = "${aws_network_interface.private.id}"
#    device_index         = 1
#  }
#

  lifecycle {
    ignore_changes = ["tags.Name"]
  }
}

resource "aws_network_interface" "public" {
  subnet_id       = "${aws_subnet.public.id}"
  private_ips     = ["10.0.0.50"]
  security_groups = ["${aws_security_group.any_access_internal.id}", "${aws_security_group.ssh.id}", "${aws_security_group.internet-outbound.id}"]

  attachment {
    instance     = "${aws_instance.bootstrap.id}"
    device_index = 0
  }
}
resource "aws_network_interface" "private" {
  subnet_id       = "${aws_subnet.private.id}"
  private_ips     = ["10.0.0.50"]
  security_groups = ["${aws_security_group.any_access_internal.id}", "${aws_security_group.ssh.id}", "${aws_security_group.internet-outbound.id}"]

  attachment {
    instance     = "${aws_instance.bootstrap.id}"
    device_index = 1
  }
}

output "Bootstrap Host Public IP" {
  value = "${aws_instance.bootstrap.public_ip}"
}
