module github.com/kubernetes/k8s.io/infra/aws/aws-costexplorer-export

go 1.16

require (
	cloud.google.com/go/bigquery v1.8.0
	github.com/aws/aws-sdk-go-v2 v1.13.0
	github.com/aws/aws-sdk-go-v2/config v1.13.1
	github.com/aws/aws-sdk-go-v2/service/costexplorer v1.15.0
	gocloud.dev v0.24.0
)
