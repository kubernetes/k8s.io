package ipinfo

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"

	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/ipinfo/ipinfopb"
	"k8s.io/klog"
)

type googleInfo struct {
	CreationTime string         `json:"creationTime"`
	SyncToken    string         `json:"syncToken"`
	Prefixes     []googlePrefix `json:"prefixes"`
}

// Example:
// {
//     "ipv4Prefix": "35.242.47.0/24",
//     "service": "Google Cloud",
//     "scope": "us-west2"
// },

type googlePrefix struct {
	IPV4Prefix string `json:"ipv4Prefix"`
	IPV6Prefix string `json:"ipv6Prefix"`

	Service string `json:"service"`
	Scope   string `json:"scope"`
}

func loadGoogleCIDRs() (*ipinfopb.CIDRMap, error) {
	allCIDRs := &ipinfopb.CIDRMap{}

	cidrs, err := loadGoogle("https://www.gstatic.com/ipranges/goog.json")
	if err != nil {
		return nil, err
	}
	allCIDRs.Cidrs = append(allCIDRs.Cidrs, cidrs.Cidrs...)

	cidrs, err = loadGoogle("https://www.gstatic.com/ipranges/cloud.json")
	if err != nil {
		return nil, err
	}
	allCIDRs.Cidrs = append(allCIDRs.Cidrs, cidrs.Cidrs...)

	return allCIDRs, nil
}

func loadGoogle(urlString string) (*ipinfopb.CIDRMap, error) {
	klog.Infof("fetching %s", urlString)
	response, err := http.Get(urlString)
	if err != nil {
		return nil, fmt.Errorf("failed to get url %q: %w", urlString, err)
	}
	defer response.Body.Close()

	b, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read url %q: %w", urlString, err)
	}

	i := &googleInfo{}
	if err := json.Unmarshal(b, i); err != nil {
		return nil, fmt.Errorf("failed to parse url %q: %w", urlString, err)
	}

	cidrs := &ipinfopb.CIDRMap{}
	for _, prefix := range i.Prefixes {
		info := &ipinfopb.CIDRInfo{}

		if prefix.IPV4Prefix != "" {
			info.Cidr = prefix.IPV4Prefix
		} else if prefix.IPV6Prefix != "" {
			info.Cidr = prefix.IPV6Prefix

		} else {
			return nil, fmt.Errorf("neither ipv4 nor ipv6 prefix was found")
		}
		_, _, err := net.ParseCIDR(info.Cidr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse CIDR %q: %w", info.Cidr, err)
		}
		info.Entity = "google.com"
		info.Service = prefix.Service
		info.Region = prefix.Scope
		cidrs.Cidrs = append(cidrs.Cidrs, info)
	}
	return cidrs, nil
}
