sub vcl_recv {
  # configure purges to require api authentication:
  # https://docs.fastly.com/en/guides/authenticating-api-purge-requests
  #
  if (req.method == "FASTLYPURGE") {
      set req.http.Fastly-Purge-Requires-Auth = "1";
  }

  # Prevent edge from caching stale content served from shield
  # https://developer.fastly.com/learning/concepts/stale/#shielding-considerations
  if (fastly.ff.visits_this_service != 0) {
    set req.max_stale_while_revalidate = 0s;
  }

  # Rewrite /vX.Y.Z* paths to /release/vX.Y.Z* for the origin
  if (req.url.path ~ "^/v[0-9]+\.[0-9]+\.[0-9]+") {
    set req.url = "/release" req.url;
  }

  #FASTLY recv

  # Set the default backend to release bucket
  set req.backend = F_k8s_release;
  set req.http.X-Backend-Name = "k8s_release";
  
  # Route /ci/* requests to the k8s-release-dev backend
  if (req.url.path ~ "^/ci/") {
    set req.backend = F_k8s_release_dev;
    set req.http.X-Backend-Name = "k8s_release_dev";
  }

  # Route /kops/* requests to the k8s-staging-kops backend
  if (req.url.path ~ "^/kops/") {
    set req.backend = F_k8s_staging_kops;
    set req.http.X-Backend-Name = "k8s_staging_kops";
  }

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

  if (beresp.http.Surrogate-Control !~ "(stale-while-revalidate|stale-if-error)") {
    set beresp.stale_if_error = 31536000s; # 1 year
    set beresp.stale_while_revalidate = 3600s; # 1 hour
  }

  # Ensure HTML and JSON files are not cached at the edge
  if (req.url.ext ~ "(html|json)\z") {
    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    return (pass);
  }

  # Never cache txt files served from the CI or kops backend
  if (req.backend == F_k8s_release_dev && req.url.ext == "txt") {
    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    return (pass);
  }
  if (req.backend == F_k8s_staging_kops && req.url.ext == "txt") {
    set beresp.cacheable = false;
    set beresp.ttl = 0s;
    return (pass);
  }

  #FASTLY fetch
  if ((beresp.status == 500 || beresp.status == 503) && req.restarts < 1 && (req.method == "GET" || req.method == "HEAD")) {
    restart;
  }

  if (req.restarts > 0) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return(pass);
  }
  # Strip the Google Cache headers as they are useless for private buckets
  unset beresp.http.Cache-Control;
  unset beresp.http.Expires;

  # Set the final headers sent to the edge PoPs and Clients
  set beresp.ttl = 24h;
  set beresp.http.Cache-Control = "public, max-age=86400";

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

  # Unset Google headers
  unset resp.http.x-goog-custom-time;
  unset resp.http.x-goog-generation;
  unset resp.http.x-goog-hash;
  unset resp.http.x-goog-meta-goog-reserved-file-mtime;
  unset resp.http.x-goog-metageneration;
  unset resp.http.x-goog-storage-class;
  unset resp.http.x-goog-stored-content-encoding;
  unset resp.http.x-goog-stored-content-length;
  unset resp.http.x-goog-expiration;
  unset resp.http.x-guploader-uploadid;
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
    if (req.http.X-Backend-Name == "k8s_release_dev") {
      call set_google_auth_header_k8s_release_dev;
    } else if (req.http.X-Backend-Name == "k8s_staging_kops") {
      call set_google_auth_header_k8s_staging_kops;
    } else {
      call set_google_auth_header_k8s_release;
    }
  }
  #FASTLY miss
  return(fetch);
}

sub vcl_error {
  #FASTLY error

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
    if (req.http.X-Backend-Name == "k8s_release_dev") {
      call set_google_auth_header_k8s_release_dev;
    } else if (req.http.X-Backend-Name == "k8s_staging_kops") {
      call set_google_auth_header_k8s_staging_kops;
    } else {
      call set_google_auth_header_k8s_release;
    }
  }
  #FASTLY pass
}
