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
  subnet_id = "${aws_subnet.public.id}"

  # OS init script
  provisioner "file" {
   content = "${module.aws-tested-oses.os-setup}"
   destination = "/tmp/os-setup.sh"
   }

 # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
    provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/os-setup.sh",
      "sudo bash /tmp/os-setup.sh",
    ]
  }


  lifecycle {
    ignore_changes = ["tags.Name"]
  }
}

resource "aws_network_interface_attachment" "bootstrap" {
  instance_id          = "${aws_instance.bootstrap.id}"
  network_interface_id = "${aws_network_interface.private.id}"
  device_index         = 1
}

resource "aws_network_interface" "private" {
  subnet_id       = "${aws_subnet.private.id}"
   security_groups = ["${aws_security_group.any_access_internal.id}", "${aws_security_group.ssh.id}", "${aws_security_group.internet-outbound.id}"]
}

output "Bootstrap Host Public IP" {
  value = "${aws_instance.bootstrap.public_ip}"
}
