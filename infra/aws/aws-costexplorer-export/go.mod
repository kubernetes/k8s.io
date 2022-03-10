module github.com/kubernetes/k8s.io/infra/aws/aws-costexplorer-export

go 1.16

require (
	cloud.google.com/go/bigquery v1.8.0
	github.com/aws/aws-sdk-go-v2 v1.13.0
	github.com/aws/aws-sdk-go-v2/config v1.13.1
	github.com/aws/aws-sdk-go-v2/service/costexplorer v1.15.0
	github.com/google/uuid v1.3.0
	github.com/jszwec/csvutil v1.6.0
	gocloud.dev v0.24.0
	google.golang.org/api v0.56.0
	sigs.k8s.io/yaml v1.3.0
)
