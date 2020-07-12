provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${var.orgid}:role/OrganizationAccountAccessRole"
  }
}

resource "aws_iam_user" "main" {
  name = var.id

  tags = {
  }
}


resource "aws_iam_access_key" "main" {
  user = aws_iam_user.main.name
  # TODO: encrypt with pgp_key?
}


# Grant permissions needed by CAPA / Test Accounts
# TODO: More precise permissions?

resource "aws_iam_user_policy_attachment" "main-ec2" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_user_policy_attachment" "main-iam" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_user_policy_attachment" "main-cloudformation" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/AWSDeepRacerCloudFormationAccessPolicy"
}

# Per https://github.com/kubernetes/k8s.io/issues/984
resource "aws_iam_user_policy_attachment" "main-ssm" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}
