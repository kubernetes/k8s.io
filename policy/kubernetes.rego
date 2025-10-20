
package kubernetes

is_service if {
    input.kind = "Service"
}

is_deployment if {
    input.kind = "Deployment"
}

is_ingress if {
    input.kind = "Ingress"
}
