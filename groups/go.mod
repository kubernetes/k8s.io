module k8s.io/k8s.io/groups

go 1.12

require (
	cloud.google.com/go v0.56.0
	github.com/bmatcuk/doublestar v1.1.1
	golang.org/x/net v0.0.0-20200324143707-d3edc9973b7e
	golang.org/x/oauth2 v0.0.0-20200107190931-bf48bf16ab8d
	google.golang.org/api v0.20.0
	google.golang.org/genproto v0.0.0-20200429120912-1f37eeb960b2
	gopkg.in/yaml.v2 v2.2.2
	k8s.io/apimachinery v0.0.0-20190817020851-f2f3a405f61d
	k8s.io/test-infra v0.0.0-20191024183346-202cefeb6ff5
)

replace k8s.io/apimachinery => k8s.io/apimachinery v0.0.0-20190817020851-f2f3a405f61d
