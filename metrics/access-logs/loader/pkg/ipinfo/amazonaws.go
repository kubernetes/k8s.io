package ipinfo

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"

	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/ipinfo/ipinfopb"
	"k8s.io/klog/v2"
)

type amazonawsInfo struct {
	CreateDate   string            `json:"createDate"`
	SyncToken    string            `json:"syncToken"`
	Ipv4Prefixes []amazonawsPrefix `json:"prefixes"`
	Ipv6Prefixes []amazonawsPrefix `json:"ipv6_prefixes"`
}

type amazonawsPrefix struct {
	IPV4Prefix string `json:"ip_prefix"`
	IPV6Prefix string `json:"ipv6_prefix"`

	Service            string `json:"service"`
	Region             string `json:"region"`
	NetworkBorderGroup string `json:"network_border_group"`
}

func loadAmazonCIDRs() (*ipinfopb.CIDRMap, error) {
	allCIDRs := &ipinfopb.CIDRMap{}

	cidrs, err := loadAmazon("https://ip-ranges.amazonaws.com/ip-ranges.json")
	if err != nil {
		return nil, err
	}
	allCIDRs.Cidrs = append(allCIDRs.Cidrs, cidrs.Cidrs...)

	return allCIDRs, nil
}

func loadAmazon(urlString string) (*ipinfopb.CIDRMap, error) {
	cidrs := &ipinfopb.CIDRMap{}

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

	i := &amazonawsInfo{}
	if err := json.Unmarshal(b, i); err != nil {
		return nil, fmt.Errorf("failed to parse url %q: %w", urlString, err)
	}

	parsePrefixes := func(prefixes []amazonawsPrefix) error {
		for _, prefix := range prefixes {
			info := &ipinfopb.CIDRInfo{}

			if prefix.IPV4Prefix != "" {
				info.Cidr = prefix.IPV4Prefix
			} else if prefix.IPV6Prefix != "" {
				info.Cidr = prefix.IPV6Prefix

			} else {
				return fmt.Errorf("neither ipv4 nor ipv6 prefix was found")
			}
			_, _, err := net.ParseCIDR(info.Cidr)
			if err != nil {
				return fmt.Errorf("failed to parse CIDR %q: %w", info.Cidr, err)
			}
			info.Entity = "amazonaws.com"
			info.Service = prefix.Service
			info.Region = prefix.Region
			info.AwsNetworkBorderGroup = prefix.NetworkBorderGroup
			cidrs.Cidrs = append(cidrs.Cidrs, info)
		}
		return nil
	}

	if err := parsePrefixes(i.Ipv4Prefixes); err != nil {
		return nil, err
	}
	if err := parsePrefixes(i.Ipv6Prefixes); err != nil {
		return nil, err
	}
	return cidrs, nil
}
