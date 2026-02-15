# VCL snippet to authenticate Fastly requests to GCS.
# Generated per-bucket auth subroutines.
#
# https://developer.fastly.com/solutions/examples/google-cloud-storage-origin-private/

%{ for bucket in bucket_configs ~}
sub set_google_auth_header_${ bucket.release_bucket ? "k8s_release" : replace(bucket.name, "-", "_") } {

declare local var.googleAccessKey STRING;
declare local var.googleSecretKey STRING;
declare local var.googleBucket STRING;
declare local var.googleRegion STRING;
declare local var.canonicalHeaders STRING;
declare local var.signedHeaders STRING;
declare local var.canonicalRequest STRING;
declare local var.canonicalQuery STRING;
declare local var.stringToSign STRING;
declare local var.dateStamp STRING;
declare local var.signature STRING;
declare local var.scope STRING;

set var.googleAccessKey = "${access_key}";
set var.googleSecretKey = "${secret_key}";
set var.googleBucket = "${bucket.name}";
set var.googleRegion = "auto";

set bereq.http.x-amz-content-sha256 = digest.hash_sha256("");
set bereq.http.x-amz-date = strftime({"%Y%m%dT%H%M%SZ"}, now);
set bereq.http.host = var.googleBucket ".storage.googleapis.com";
set bereq.url = querystring.remove(bereq.url);
# Preserve '+' in paths (e.g. semver build metadata v1.36.0-alpha.1+abc)
# Use [+] character class — VCL double-quoted strings strip backslashes,
# so "\+" becomes bare + (a PCRE quantifier that matches nothing standalone).
set bereq.url = regsuball(urlencode(urldecode(regsuball(bereq.url.path, "[+]", "%2B"))), {"%2F"}, "/");
set var.dateStamp = strftime({"%Y%m%d"}, now);
set var.canonicalHeaders = ""
    "host:" + bereq.http.host + LF +
    "x-amz-content-sha256:" + bereq.http.x-amz-content-sha256 + LF +
    "x-amz-date:" + bereq.http.x-amz-date + LF
  ;
set var.canonicalQuery = "";
set var.signedHeaders = "host;x-amz-content-sha256;x-amz-date";
set var.canonicalRequest = "" +
    "GET" + LF +
    bereq.url.path + LF +
    var.canonicalQuery + LF +
    var.canonicalHeaders + LF +
    var.signedHeaders + LF +
    digest.hash_sha256("")
  ;

set var.scope = var.dateStamp "/" var.googleRegion "/s3/aws4_request";

set var.stringToSign = "" +
    "AWS4-HMAC-SHA256" + LF +
    bereq.http.x-amz-date + LF +
    var.scope + LF +
    regsub(digest.hash_sha256(var.canonicalRequest),"^0x", "")
  ;

set var.signature = digest.awsv4_hmac(
    var.googleSecretKey,
    var.dateStamp,
    var.googleRegion,
    "s3",
    var.stringToSign
  );

set bereq.http.Authorization = "AWS4-HMAC-SHA256 " +
    "Credential=" + var.googleAccessKey + "/" + var.scope + ", " +
    "SignedHeaders=" + var.signedHeaders + ", " +
    "Signature=" + regsub(var.signature,"^0x", "")
  ;
unset bereq.http.Accept;
unset bereq.http.Accept-Language;
unset bereq.http.User-Agent;
unset bereq.http.Fastly-Client-IP;
}

%{ endfor ~}
