package ipinfo

import (
	"fmt"
	"io"
	"net"
	"sort"

	"k8s.io/k8s.io/metrics/access-logs/loader/pkg/ipinfo/ipinfopb"
)

type TreeNode struct {
	Position int
	IPV4     bool
	Children map[byte]*TreeNode
	Leafs    []leaf
}

type leaf struct {
	CIDR net.IPNet
	Info *ipinfopb.CIDRInfo
}

func (n *TreeNode) Dump(w io.StringWriter) {
	n.dump(w, "")
}

func (n *TreeNode) dump(w io.StringWriter, indent string) {
	for k, child := range n.Children {
		w.WriteString(indent + fmt.Sprintf("%d:\n", k))
		child.dump(w, indent+"  ")
	}
	for _, l := range n.Leafs {
		w.WriteString(indent + fmt.Sprintf("%s: %v\n", l.CIDR, l.Info))
	}
}

func (n *TreeNode) Lookup(ip net.IP) *ipinfopb.CIDRInfo {
	next := ip[n.Position]
	child := n.Children[next]
	if child != nil {
		info := child.Lookup(ip)
		if info != nil {
			return info
		}
	}
	for _, leaf := range n.Leafs {
		if leaf.CIDR.Contains(ip) {
			return leaf.Info
		}
	}
	return nil
}

func BuildTree(cidrs *ipinfopb.CIDRMap, ipv4 bool) (*TreeNode, error) {
	root := &TreeNode{
		Position: 0,
		IPV4:     ipv4,
	}

	for _, info := range cidrs.Cidrs {
		ip, cidr, err := net.ParseCIDR(info.Cidr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse CIDR %q: %w", info.Cidr, err)
		}

		isIPv4 := ip.To4() != nil
		if isIPv4 != ipv4 {
			continue
		}

		root.insert(cidr, info)
	}

	root.finalize()
	return root, nil
}

func (n *TreeNode) finalize() {
	for _, child := range n.Children {
		child.finalize()
	}

	sort.Slice(n.Leafs, func(i, j int) bool {
		iSize, _ := n.Leafs[i].CIDR.Mask.Size()
		jSize, _ := n.Leafs[j].CIDR.Mask.Size()
		// Most specific CIDR first
		return !(iSize < jSize)
	})
}

func (n *TreeNode) insert(cidr *net.IPNet, info *ipinfopb.CIDRInfo) {
	if (n.IPV4 && n.Position >= 2) || n.Position >= 8 {
		n.Leafs = append(n.Leafs, leaf{
			CIDR: *cidr,
			Info: info,
		})
		return
	}

	prefixLen, _ := cidr.Mask.Size()
	myPrefixLen := (1 + n.Position) * 8

	if myPrefixLen > prefixLen {
		n.Leafs = append(n.Leafs, leaf{
			CIDR: *cidr,
			Info: info,
		})
		return
	}

	next := cidr.IP[n.Position]
	child := n.Children[next]
	if child == nil {
		child = &TreeNode{
			Position: n.Position + 1,
			IPV4:     n.IPV4,
		}
		if n.Children == nil {
			n.Children = make(map[byte]*TreeNode)
		}
		n.Children[next] = child
	}
	child.insert(cidr, info)
}
