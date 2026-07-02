resource "aws_iam_openid_connect_provider" "eks_build_cluster" {
  url             = "https://oidc.eks.us-east-2.amazonaws.com/id/F8B73554FE6FBAF9B19569183FB39762"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["06b25927c42a721631c1efd9431e648fa62e1e39"]
}

resource "aws_iam_openid_connect_provider" "gke_build_cluster" {
  url             = "https://container.googleapis.com/v1/projects/k8s-infra-prow-buildlocations/us-central1/clusters/prow-build"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["08745487e891c19e3078c1f2a07e452950ef36f6"]
}

resource "aws_iam_role" "boskos" {
  name = "boskos"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.eks_build_cluster.arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.us-east-2.amazonaws.com/id/F8B73554FE6FBAF9B19569183FB39762:sub" : [
              "system:serviceaccount:test-pods:boskos",
              "system:serviceaccount:test-pods:default"
            ]
          }
        }
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.gke_build_cluster.arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "container.googleapis.com/v1/projects/k8s-infra-prow-build/locations/us-central1/clusters/prow-build:sub" : [
              "system:serviceaccount:test-pods:boskos",
              "system:serviceaccount:test-pods:default"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 43200
}

resource "aws_iam_role_policy_attachment" "boskos" {
  role       = aws_iam_role.boskos.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "boskos_arn" {
  value = aws_iam_role.boskos.arn
}
