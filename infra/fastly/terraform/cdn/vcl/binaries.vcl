sub vcl_recv {
  # configure purges to require api authentication:
  # https://docs.fastly.com/en/guides/authenticating-api-purge-requests
  #
  if (req.method == "FASTLYPURGE") {
      set req.http.Fastly-Purge-Requires-Auth = "1";
  }

  # Strip client credentials so they never reach the origins; S3 rejects
  # non-AWS Authorization headers (e.g. registry Bearer tokens) with a 400.
  # Private buckets are re-signed by the auth subs in vcl_miss/vcl_pass.
  # cri-o/skopeo/podman pass it along and we need to strip it
  unset req.http.Authorization;

  # Prevent edge from caching stale content served from shield
  # https://developer.fastly.com/learning/concepts/stale/#shielding-considerations
  if (fastly.ff.visits_this_service != 0) {
    set req.max_stale_while_revalidate = 0s;
  }

%{~ if contains([for bucket in bucket_configs : bucket.name], "prod-registry-k8s-io-us-east-2") ~}
  # Redirect the root path to the registry.k8s.io project page
  if (req.url.path == "/") {
    error 618;
  }
  # Allow blob paths, 404 everything else.
  # Some clients percent-encode the digest separator.
  if (regsub(req.url.path, {"%3[Aa]"}, ":") !~ "^/containers/images/sha256:[a-f0-9]{64}$") {
    error 619;
  }
  # Capture rid, then strip the query string so it doesn't fragment the cache.
  # Only on the edge: the shield receives the stripped URL and would clobber
  # the header forwarded from the edge with an empty value.
  if (fastly.ff.visits_this_service == 0) {
    set req.http.X-Request-Id-Param = subfield(req.url.qs, "rid", "&");
    set req.url = req.url.path;
  }
%{ else ~}
  # Serve index.html for the root path
  if (req.url.path == "/") {
    set req.url = "/index.html";
  }
%{ endif ~}

%{~ if length([for bucket in bucket_configs : bucket.name if bucket.release_bucket]) > 0 ~}
  # Rewrite /vX.Y.Z* paths to /release/vX.Y.Z* for the origin
  if (req.url.path ~ "^/v[0-9]+\.[0-9]+\.[0-9]+") {
    set req.url = "/release" req.url;
  }
%{ endif ~}

  #FASTLY recv

%{~ if length([for bucket in bucket_configs : bucket.name if bucket.release_bucket]) > 0 ~}
  # Set the default backend to release bucket
  set req.backend = F_k8s_release;
  set req.http.X-Backend-Name = "k8s_release";
%{ endif ~}
  
%{~ if length(setintersection([for bucket in bucket_configs : bucket.name], ["k8s-release-dev","k8s-staging-kops"])) == 2 ~}
  # Route /ci/kops/* requests to the k8s-staging-kops backend
  if (req.url.path ~ "^/ci/kops/") {
    # We want to send the request to the root of the bucket
    set req.url = regsub(req.url, "^/ci/kops", "");
    set req.backend = F_k8s_staging_kops;
    set req.http.X-Backend-Name = "k8s_staging_kops";
  # Route /ci/* requests to the k8s-release-dev backend
  } else if (req.url.path ~ "^/ci/") {
    set req.backend = F_k8s_release_dev;
    set req.http.X-Backend-Name = "k8s_release_dev";
  }
%{ endif ~}

  # don't bother doing a cache lookup for a request type that isn't cacheable
  if (req.method != "HEAD" && req.method != "GET" && req.method != "FASTLYPURGE") {
    return(pass);
  }
  return(lookup);
}

sub vcl_fetch {
  # handle 5XX (or any other unwanted status code)
  if (beresp.status >= 500 && beresp.status < 600) {
    /* deliver stale if the object is available */
    if (stale.exists) {
      return(deliver_stale);
    }

    if (req.restarts < 1 && (req.request == "GET" || req.request == "HEAD")) {
      restart;
    }

    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    # else go to vcl_error to deliver a synthetic
    error beresp.status;
  }

  if (beresp.status >= 400 && beresp.status < 500) {
    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    set beresp.stale_if_error = 0s;
    set beresp.stale_while_revalidate = 0s;
    unset beresp.http.Expires;
    set beresp.http.Cache-Control = "private, no-store";
    return(deliver);
  }

  if (beresp.http.Surrogate-Control !~ "(stale-while-revalidate|stale-if-error)") {
    set beresp.stale_if_error = 31536000s; # 1 year
    set beresp.stale_while_revalidate = 3600s; # 1 hour
  }

%{~ if contains([for bucket in bucket_configs : bucket.name], "k8s-staging-kops") ~}
  # Never cache txt files served from the kops backend
  if (req.backend == F_k8s_staging_kops && req.url.ext == "txt") {
    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    return (pass);
  }
%{ endif ~}

  #FASTLY fetch
  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.method == "GET" || req.method == "HEAD")) {
    restart;
  }

  if (req.restarts > 0) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }


  # If we set Surrogate-Key in GCS, capture it and send it to Fastly.
  # FYI, we use S3 to access the bucket so the header is x-amz-meta instead of x-goog-meta
  # https://www.fastly.com/documentation/guides/full-site-delivery/purging/working-with-surrogate-keys/
  if (beresp.http.x-amz-meta-surrogate-key) {
    set beresp.http.Surrogate-Key = beresp.http.x-amz-meta-surrogate-key;
  }
  if (beresp.http.x-amz-meta-surrogate-control) {
    set beresp.http.Surrogate-Control = beresp.http.x-amz-meta-surrogate-control;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return(pass);
  }
  # Strip the Google Cache headers as they are useless for private buckets
  unset beresp.http.Cache-Control;
  unset beresp.http.Expires;

  # Set the final headers sent to the edge PoPs and clients.
  set beresp.ttl = 24h;
  set beresp.http.Cache-Control = "public, max-age=${cache_ttl}";

  # We have various text files with incorrect Content-Type headers set because GCS
  # doesn't know how to handle them
  if (req.url.ext ~ "^(sha256|sha512|cert)$" || req.url.path ~ "/(SHA256SUMS|SHA512SUMS)$") {
    set beresp.http.Content-Type = "text/plain; charset=UTF-8";
  }

  return(deliver);
}

sub vcl_hit {
  #FASTLY hit

  # If the object we have isn't cacheable, then just serve it directly
  # without going through any of the caching mechanisms.
  if (!obj.cacheable) {
      return(pass);
  }

  return(deliver);
}

sub vcl_deliver {

  if (resp.http.cache-control:max-age) {
    unset resp.http.expires;
  }

  # Unset AWS-compatible headers
  unset resp.http.x-amz-checksum-crc32c;
  unset resp.http.x-amz-meta-goog-reserved-file-mtime;
  unset resp.http.x-amz-meta-x-goog-reserved-source-generation;
  unset resp.http.x-amz-meta-surrogate-key;
  unset resp.http.x-amz-meta-surrogate-control;
  unset resp.http.x-amz-id-2;
  unset resp.http.x-amz-request-id;
  unset resp.http.x-amz-replication-status;
  unset resp.http.x-amz-server-side-encryption;
  unset resp.http.x-amz-version-id;
  unset resp.http.Etag;

  # Unset Google headers
  unset resp.http.x-goog-custom-time;
  unset resp.http.x-goog-generation;
  unset resp.http.x-goog-hash;
  unset resp.http.x-goog-meta-goog-reserved-file-mtime;
  unset resp.http.x-goog-meta-sha256;
  unset resp.http.x-goog-metageneration;
  unset resp.http.x-goog-storage-class;
  unset resp.http.x-goog-stored-content-encoding;
  unset resp.http.x-goog-stored-content-length;
  unset resp.http.x-goog-expiration;
  unset resp.http.x-guploader-uploadid;

%{~ if contains([for bucket in bucket_configs : bucket.name], "prod-registry-k8s-io-us-east-2") ~}
  # Echo the rid query parameter back as X-Request-Id
  if (req.http.X-Request-Id-Param ~ "^[A-Za-z0-9._-]{1,64}$") {
    set resp.http.X-Request-Id = req.http.X-Request-Id-Param;
  }
%{ endif ~}

  #FASTLY deliver

  if (!req.http.Fastly-Debug) {
    unset resp.http.Server;
    unset resp.http.Via;
    unset resp.http.X-Powered-By;
    unset resp.http.X-Served-By;
    unset resp.http.X-Cache;
    unset resp.http.X-Cache-Hits;
    unset resp.http.X-Timer;
  }

  return(deliver);
}

sub vcl_miss {
  if(req.backend.is_origin) {
%{ if length([for bucket in bucket_configs : bucket.name if bucket.release_bucket]) > 0 ~}
    if (req.http.X-Backend-Name == "k8s_release") {
      call ${auth_sub_prefix}_k8s_release;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-staging-kops") ~}
    if (req.http.X-Backend-Name == "k8s_staging_kops") {
      call ${auth_sub_prefix}_k8s_staging_kops;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-release-dev") ~}
    if (req.http.X-Backend-Name == "k8s_release_dev") {
      call ${auth_sub_prefix}_k8s_release_dev;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-artifacts-prod") ~}
    if (req.http.X-Backend-Name == "k8s_artifacts_prod") {
      call ${auth_sub_prefix}_k8s_artifacts_prod;
    }
%{ endif ~}
  }
  #FASTLY miss
  return(fetch);
}

sub vcl_error {
  #FASTLY error

%{~ if contains([for bucket in bucket_configs : bucket.name], "prod-registry-k8s-io-us-east-2") ~}
  if (obj.status == 618) {
    set obj.status = 301;
    set obj.response = "Moved Permanently";
    set obj.http.Location = "https://github.com/kubernetes/registry.k8s.io";
    set obj.http.Content-Type = "text/plain; charset=UTF-8";
    synthetic {"Redirecting to https://github.com/kubernetes/registry.k8s.io"};
    return (deliver);
  }

  if (obj.status == 619) {
    set obj.status = 404;
    set obj.response = "Not Found";
    set obj.http.Content-Type = "text/plain";
    set obj.http.Cache-Control = "max-age=300";
    synthetic {"Not Found
"};
    return (deliver);
  }
%{ endif ~}

  /* handle 503s */
  if (obj.status >= 500 && obj.status < 600) {
    /* deliver stale object if it is available */
    if (stale.exists) {
      return(deliver_stale);
    }
    /* otherwise, return a synthetic */

    # Handle our "error" conditions which are really just ways to set synthetic
    # responses.
    if (obj.status == 603) {
        set obj.status = 403;
        set obj.response = "SSL is required";
        set obj.http.Content-Type = "text/plain; charset=UTF-8";
        synthetic {"SSL is required."};
        return (deliver);
    }

    if (obj.status == 604) {
        set obj.status = 403;
        set obj.response = "SNI is required";
        set obj.http.Content-Type = "text/plain; charset=UTF-8";
        synthetic {"SNI is required."};
        return (deliver);
    }
  }


}

sub vcl_pass {
  if(req.backend.is_origin) {
%{ if length([for bucket in bucket_configs : bucket.name if bucket.release_bucket]) > 0 ~}
    if (req.http.X-Backend-Name == "k8s_release") {
      call ${auth_sub_prefix}_k8s_release;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-staging-kops") ~}
    if (req.http.X-Backend-Name == "k8s_staging_kops") {
      call ${auth_sub_prefix}_k8s_staging_kops;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-release-dev") ~}
    if (req.http.X-Backend-Name == "k8s_release_dev") {
      call ${auth_sub_prefix}_k8s_release_dev;
    }
%{ endif ~}
%{ if contains([for bucket in bucket_configs : bucket.name], "k8s-artifacts-prod") ~}
    if (req.http.X-Backend-Name == "k8s_artifacts_prod") {
      call ${auth_sub_prefix}_k8s_artifacts_prod;
    }
%{ endif ~}
  }
  #FASTLY pass
}

sub vcl_log {
  #FASTLY log

%{~ if contains([for bucket in bucket_configs : bucket.name], "prod-registry-k8s-io-us-east-2") ~}
  # Emit the rid so it's visible in log tailing.
  # Only on the edge, otherwise shielded requests are logged twice.
  if (fastly.ff.visits_this_service == 0 && req.http.X-Request-Id-Param ~ "^[A-Za-z0-9._-]{1,64}$") {
    log {"syslog "} req.service_id {" dd-oss-k8s :: rid="} req.http.X-Request-Id-Param {" url="} req.url.path {" status="} resp.status;
  }
%{ endif ~}
}
