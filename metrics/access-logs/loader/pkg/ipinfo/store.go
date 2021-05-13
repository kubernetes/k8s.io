package ipinfo

import (
	"io"
	"net"

	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/ipinfo/ipinfopb"
	"k8s.io/klog"
)

type Store struct {
	ipv4 *TreeNode
	ipv6 *TreeNode
}

func (s *Store) Dump(w io.StringWriter) {
	s.ipv4.Dump(w)
	s.ipv6.Dump(w)
}

func loadAllCIDRS() (*ipinfopb.CIDRMap, error) {
	allCIDRs := &ipinfopb.CIDRMap{}

	cidrs, err := loadAmazonCIDRs()
	if err != nil {
		return nil, err
	}
	allCIDRs.Cidrs = append(allCIDRs.Cidrs, cidrs.Cidrs...)

	cidrs, err = loadGoogleCIDRs()
	if err != nil {
		return nil, err
	}
	allCIDRs.Cidrs = append(allCIDRs.Cidrs, cidrs.Cidrs...)

	return allCIDRs, nil
}

func (s *Store) Lookup(ipString string) *ipinfopb.CIDRInfo {
	ip := net.ParseIP(ipString)
	if ip == nil {
		klog.Warningf("cannot parse ip %q", ipString)
		return nil
	}

	ipv4 := ip.To4()
	if ipv4 != nil {
		return s.ipv4.Lookup(ipv4)
	}
	return s.ipv6.Lookup(ip)
}

func (s *Store) Refresh() error {
	cidrs, err := loadAllCIDRS()
	if err != nil {
		return err
	}

	{
		ipv4, err := BuildTree(cidrs, true)
		if err != nil {
			return err
		}
		s.ipv4 = ipv4
	}

	{
		ipv6, err := BuildTree(cidrs, false)
		if err != nil {
			return err
		}

		s.ipv6 = ipv6
	}

	return nil
}
