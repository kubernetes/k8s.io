// the code

package main

import (
	"fmt"
	"os"

	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm"
	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm/types"
)

const (
	realIPKey       = "x-real-ip"
	matchIPEnvKey   = "MATCH_IP"
	authorityEnvKey = "AUTHORITY"
	locationKey     = "location"
	authorityKey    = ":authority"
	statusKey       = ":status"
	pathKey         = ":path"
	statusCode      = 302
	defaultHost     = "k8s.gcr.io"
	rewriteHost     = "registry-1.docker.io"
)

var (
	authority = os.Getenv(authorityEnvKey)
	matchIP   = os.Getenv(matchIPEnvKey)
)

func main() {
	proxywasm.SetVMContext(&vmContext{})
}

type vmContext struct {
	// Embed the default VM context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultVMContext
}

// Override types.DefaultVMContext.
func (*vmContext) NewPluginContext(contextID uint32) types.PluginContext {
	return &pluginContext{}
}

type pluginContext struct {
	// Embed the default plugin context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultPluginContext
}

// Override types.DefaultPluginContext.
func (*pluginContext) NewHttpContext(contextID uint32) types.HttpContext {
	return &httpRouting{}
}

type httpRouting struct {
	// Embed the default http context here,
	// so that we don't need to reimplement all the methods.
	types.DefaultHttpContext
	bodySize    int
	endOfStream bool
}

func (ctx *pluginContext) OnPluginStart(pluginConfigurationSize int) types.OnPluginStartStatus {
	return types.OnPluginStartStatusOK
}

// Override types.DefaultHttpContext.
func (ctx *httpRouting) OnHttpRequestHeaders(numHeaders int, endOfStream bool) types.Action {
	host := defaultHost
	remoteAddr, err := proxywasm.GetHttpRequestHeader(realIPKey)
	if err != nil {
		proxywasm.LogCritical(fmt.Sprintf("Error: getting request header: '%v'", realIPKey))
	}
	if matchIP == remoteAddr {
		host = rewriteHost
	}

	path, _ := proxywasm.GetHttpRequestHeader(pathKey)
	body := fmt.Sprintf(`<a href="https://%v%v">%v</a>.`, host, path, statusCode)
	if err := proxywasm.SendHttpResponse(statusCode, [][2]string{
		{authorityKey, authority},
		{locationKey, fmt.Sprintf("https://%v%v", host, path)},
		{statusKey, fmt.Sprintf("%s", statusCode)},
		{pathKey, path},
	}, []byte(body)); err != nil {
		proxywasm.LogErrorf("Error: sending http response: %v", err)
		proxywasm.ResumeHttpRequest()
	}
	return types.ActionPause
}

func (ctx *pluginContext) OnTick() {}
