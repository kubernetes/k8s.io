resource "aws_iam_user" "bentheelder" {
  name = "bentheelder"
}
resource "aws_iam_user_policy_attachment" "benthelder_billing" {
  user       = aws_iam_user.bentheelder.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}
