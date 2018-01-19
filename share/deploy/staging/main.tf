# ----------------------------------------------------------------------
#  Configuration
# ----------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket  = "civica-terraform-backend"
    key     = "staging/{{project_name}}"
    profile = "terraform"
    region  = "us-east-1"
  }
}

# ----------------------------------------------------------------------
#  Variables
# ----------------------------------------------------------------------
variable "project_name" {
  default = "{{project_name}}"
}

variable "jenkins_ssh_fingerprint" {
  # https://github.com/civica-ci.keys
  default = "24:c7:0c:6e:ba:b5:a9:50:58:cf:1e:a5:fe:39:51:49"
}

variable "digital_ocean_token" {}

# ----------------------------------------------------------------------
#  Providers
# ----------------------------------------------------------------------
provider "digitalocean" {
  token = "${var.digital_ocean_token}"
}

# Note: The terraform profile in `~/.aws/config` is expected.
#       Credentials are in 1Password.
provider "aws" {
  profile = "terraform"
  region  = "us-east-1"
}

# ----------------------------------------------------------------------
#  Access keys
# ----------------------------------------------------------------------
resource "aws_iam_user" "project" {
  name = "${var.project_name}"
}
resource "aws_iam_access_key" "project" {
  user = "${aws_iam_user.project.name}"
}

# ----------------------------------------------------------------------
#  Docker repository (ECR)
# ----------------------------------------------------------------------
resource "aws_ecr_repository" "repo" {
  name = "${var.project_name}"
}

resource "aws_iam_user_policy" "ecr" {
  name = "${var.project_name}-ECR"
  user = "${aws_iam_user.project.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*",
        "cloudtrail:LookupEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# ----------------------------------------------------------------------
#  Web server (Digital Ocean)
# ----------------------------------------------------------------------
resource "digitalocean_droplet" "web" {
  image     = "ubuntu-16-04-x64"
  name      = "${var.project_name}"
  region    = "nyc3"
  size      = "s-1vcpu-1gb"
  ssh_keys  = ["${var.jenkins_ssh_fingerprint}"]
  user_data = "${data.template_file.setup_server.rendered}"
}

data "template_file" "setup_server" {
  template = "${file("./scripts/setup-server.sh")}"

  vars {
    PROJECT_NAME   = "${var.project_name}"
    AWS_ACCESS_KEY = "${aws_iam_access_key.project.id}"
    AWS_SECRET_KEY = "${aws_iam_access_key.project.secret}"
    USERNAME       = "deploy"
  }
}

# ----------------------------------------------------------------------
#  DNS (Digital Ocean)
# ----------------------------------------------------------------------
resource "digitalocean_record" "civicadesarrolla" {
  domain = "civicadesarrolla.me"
  type   = "A"
  name   = "${var.project_name}"
  value  = "${digitalocean_droplet.web.ipv4_address}"
}

# Output
output "ip" {
  value = "${digitalocean_droplet.web.ipv4_address}"
}

output "url" {
  value = "${digitalocean_record.civicadesarrolla.fqdn}"
}

output "aws_key_id" {
  value = "${aws_iam_access_key.project.id}"
}

output "aws_key_secret" {
  value = "${aws_iam_access_key.project.secret}"
}
