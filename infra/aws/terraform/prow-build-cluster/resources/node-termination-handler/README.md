# AWS Node Termination Handler

[AWS Node Termination Handler](https://github.com/aws/aws-node-termination-handler) gracefully handles EC2 instance shutdown within Kubernetes. The project ensures that the Kubernetes control plane responds appropriately to events that can cause your EC2 instance to become unavailable, such as EC2 maintenance events, EC2 Spot interruptions, ASG Scale-In, ASG AZ Rebalance, and EC2 Instance Termination via the API or Console. If not handled, your application code may not stop gracefully, take longer to recover full availability, or accidentally schedule work to nodes that are going down.

### Installation

[Installing the Chart](https://github.com/aws/aws-node-termination-handler/tree/main/config/helm/aws-node-termination-handler#installing-the-chart)
