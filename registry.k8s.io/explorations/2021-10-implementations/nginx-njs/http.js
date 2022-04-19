

// The http response method

function fetch_upstream_host(r) {
  var reg = "k8s.gcr.io"
  if (r.remoteAddress === process.env.MATCH_IP) {
    reg = "registry-1.docker.io"
  }
  r.error(`registry: ${reg}`)
  return reg
}
