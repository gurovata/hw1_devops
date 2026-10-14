terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

resource "docker_network" "nginx" {
  name = "hw1_terraform_network"
}

resource "docker_volume" "nginx" {
  name = "hw1_nginx_data"
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name         = "hw1_terraform_nginx"
  image        = docker_image.nginx.image_id
  restart      = "unless-stopped"
  network_mode = docker_network.nginx.name

  networks_advanced {
    name = docker_network.nginx.name
  }

  ports {
    internal = 80
    external = var.nginx_port
    ip       = "127.0.0.1"
  }

  volumes {
    volume_name    = docker_volume.nginx.name
    container_path = "/usr/share/nginx/html"
    read_only      = true
  }
}
