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


#FASTLY recv

  # don't bother doing a cache lookup for a request type that isn't cacheable
  if (req.method !~ "(GET|HEAD|FASTLYPURGE)") {
    return(pass);
  }

  return(lookup);
}

sub vcl_fetch {

  /* handle 5XX (or any other unwanted status code) */
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
    /* else go to vcl_error to deliver a synthetic */
  error beresp.status;
  }

  if (beresp.http.Surrogate-Control !~ "(stale-while-revalidate|stale-if-error)") {
    set beresp.stale_if_error = 31536000s; // 1 year
    set beresp.stale_while_revalidate = 60s; // 1 minute
  }

#FASTLY fetch
  if (req.restarts > 0) {
    set beresp.http.Fastly-Restarts = req.restarts;
  }

  if (beresp.http.Set-Cookie) {
    set req.http.Fastly-Cachetype = "SETCOOKIE";
    return(pass);
  }

if (beresp.http.Cache-Control ~ "private") {
    set req.http.Fastly-Cachetype = "PRIVATE";
    return(pass);
  }

  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~ "(s-maxage|max-age)") {
    # keep the ttl here
  } else {
    # apply the default ttl
    set beresp.ttl = 3600s;
  }

  return(deliver);
}

sub vcl_deliver {
#FASTLY deliver

  if (req.http.X-Monitoring == "true") {
    set resp.http.X-Monitoring = req.http.X-Monitoring;
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
    if (resp.status >= 500 && resp.status < 600) {
        if (stale.exists) {
            restart;
        }
    }
}

sub vcl_miss {
#FASTLY miss
  return(fetch);
}

sub vcl_error {
#FASTLY error
}

sub vcl_pass {
#FASTLY pass
}
