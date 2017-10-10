# Configura terraform
terraform {
  backend "s3" {
    bucket  = "civica-terraform-backend"
    key     = "staging/{{project_name}}"
    profile = "terraform"
    region  = "us-east-1"
  }
}

# Variables
variable "project_name" {
  default = "{{project_name}}"
}

variable "jenkins_ssh_key_id" {
  default = 11986881
}

variable "digital_ocean_token" {}
variable "aws_ecr_access_key" {}
variable "aws_ecr_secret_key" {}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = "${var.digital_ocean_token}"
}

# Configure the AWS Provider
provider "aws" {
  profile = "terraform"
  region  = "us-east-1"
}

# Create a user for to access the project's resources
resource "aws_iam_user" "project" {
  name = "${var.project_name}"
}

# Create a key to access the project's data
resource "aws_iam_access_key" "project" {
  user = "${aws_iam_user.project.name}"
}

# Create a web server
resource "digitalocean_droplet" "web" {
  image     = "ubuntu-16-04-x64"
  name      = "${var.project_name}"
  region    = "nyc3"
  size      = "512mb"
  ssh_keys  = ["${var.jenkins_ssh_key_id}"]
  user_data = "${data.template_file.setup_server.rendered}"
}

# Add a record alias to our staging domain
resource "digitalocean_record" "civicadesarrolla" {
  domain = "civicadesarrolla.me"
  type   = "A"
  name   = "${var.project_name}"
  value  = "${digitalocean_droplet.web.ipv4_address}"
}

# Create AWS ECR repository
resource "aws_ecr_repository" "repo" {
  name = "${var.project_name}"
}

# Data
data "template_file" "setup_server" {
  template = "${file("../scripts/setup-server.sh")}"

  vars {
    PROJECT_NAME       = "${var.project_name}"
    AWS_ECR_ACCESS_KEY = "${var.aws_ecr_access_key}"
    AWS_ECR_SECRET_KEY = "${var.aws_ecr_secret_key}"
    USERNAME           = "deploy"
  }
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
