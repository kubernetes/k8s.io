
package kubernetes

is_service {
    input.kind = "Service"
}

is_deployment {
    input.kind = "Deployment"
}

is_ingress {
    input.kind = "Ingress"
}