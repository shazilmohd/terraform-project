resource "aws_instance" "main" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data != "" ? base64encode(var.user_data) : null

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      Name = "EC2-Instance-${count.index + 1}"
    }
  )
}
