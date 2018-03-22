#!/bin/bash

# The intention of this script is to setup a server with the default
# configuration, documenting (infrastructure as code) the tasks
# that we normaly use in our staging/production environments.
#
# It should be runned with a user with `sudo` powers, that doesn't require
# password for it, as many commands requires root access and runs in
# a non-interactive environment.

# As we are running this with Terraform, it interprets the $ { var }
# as interpolation, that's why we are using the $var syntax
username=${USERNAME}
project_name=${PROJECT_NAME}
app_dir="/var/www/$project_name"

main() {
  create_user
  make_app_dir
  configure_ssh
  install_docker
  configure_docker
  install_docker_compose
  configure_docker_compose
  install_python_pip
  install_awscli
  configure_awscli
}

create_user() {
  # Creates a user (by default, named `deploy`), and
  # copies the SSH keys from root
  useradd --create-home --shell /bin/bash $username
  gpasswd -a $username sudo
  cp -R ~/.ssh /home/$username/
  chown -R $username:$username /home/$username/.ssh
}

make_app_dir() {
  # Creates a directory with the project name, and allows
  # the user access to manage it
  mkdir -p $app_dir
  chown -R $username:$username $app_dir
}

configure_ssh() {
  echo -e "\n# Security settings" | sudo tee --append /etc/ssh/sshd_config

  # Disallow login with the `root` user through SSH
  echo 'PermitRootLogin no' | sudo tee --append /etc/ssh/sshd_config

  # Password based logins are disabled - only public key based logins are allowed.
  echo 'AuthenticationMethods publickey' | sudo tee --append /etc/ssh/sshd_config

  # LogLevel VERBOSE logs user's key fingerprint on login.
  # Needed to have a clear audit track of which key was using to log in.
  echo 'LogLevel VERBOSE' | sudo tee --append /etc/ssh/sshd_config

  systemctl restart sshd
}

install_docker() {
  # Update repository
  sudo apt-get -y update

  # Install dependencies
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  # Add Docker’s official GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  # Add Docker's repository
  sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

  # Install Docker (Community edition)
  sudo apt-get update -y \
    && apt-get install -y docker-ce
}

configure_docker() {
  # Add user to the Docker group and specify some useful functions
  gpasswd -a $username docker

  cat <<EOF>> /home/$username/.profile

export COMPOSE_FILE=$app_dir/docker-compose.yml
alias dc=docker-compose
alias web-index="dc ps | grep -Eio 'web_[0-9]+' | grep -Eo '[0-9]+'"
shell() { dc exec --index=\$(web-index) web bash ; }
rails() { dc exec --index=\$(web-index) web rails \$@ ; }
rake() { dc exec --index=\$(web-index) web rake \$@ ; }
EOF
}

install_docker_compose() {
  sudo curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o docker-compose
  sudo mv docker-compose /usr/local/bin/
  sudo chmod +x /usr/local/bin/docker-compose
}

configure_docker_compose() {
  # Create an acme.json for Traefik SSL
  touch $app_dir/acme.json
  sudo chmod 600 $app_dir/acme.json

  sudo chown -R $username:$username $app_dir
}

install_python_pip() {
  # The Ubuntu 16 distro doesn't ship with `pip` in Digital Ocean
  sudo apt-get install -y python-pip
}

install_awscli() {
  # Mostly, used to login to ECR (where we host our Docker images)
  sudo pip install awscli
}

configure_awscli() {
  # Add the default profile to the user
  local aws_dir="/home/$username/.aws"

  mkdir -p $aws_dir

  cat <<EOF > $aws_dir/config
[default]
output = json
region = us-east-1
EOF

  cat <<EOF > $aws_dir/credentials
[default]
aws_access_key_id = $aws_access_key
aws_secret_access_key = $aws_secret_key
EOF

  chmod 600 $aws_dir/*
  chown -R $username:$username $aws_dir
}

main
