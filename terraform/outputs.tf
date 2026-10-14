output "nginx_url" {
  value = "http://127.0.0.1:${var.nginx_port}"
}

output "network_name" {
  value = docker_network.nginx.name
}

output "volume_name" {
  value = docker_volume.nginx.name
}
