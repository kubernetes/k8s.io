# VCL snippet to authenticate Fastly requests to S3.
# Generated per-bucket auth subroutines.
#
# https://www.fastly.com/documentation/solutions/examples/using-s3-compatible-buckets-as-private-origins/

%{ for bucket in bucket_configs ~}
sub set_aws_auth_header_${ bucket.release_bucket ? "k8s_release" : replace(bucket.name, "-", "_") } {
%{ if bucket.public ~}
# ${bucket.name} is public, no request signing needed
%{ else ~}

declare local var.awsAccessKey STRING;
declare local var.awsSecretKey STRING;
declare local var.awsBucket STRING;
declare local var.awsRegion STRING;
declare local var.canonicalHeaders STRING;
declare local var.signedHeaders STRING;
declare local var.canonicalRequest STRING;
declare local var.canonicalQuery STRING;
declare local var.stringToSign STRING;
declare local var.dateStamp STRING;
declare local var.signature STRING;
declare local var.scope STRING;

set var.awsAccessKey = "${access_key}";
set var.awsSecretKey = "${secret_key}";
set var.awsBucket = "${bucket.name}";
set var.awsRegion = "${region}";

set bereq.http.x-amz-content-sha256 = digest.hash_sha256("");
set bereq.http.x-amz-date = strftime({"%Y%m%dT%H%M%SZ"}, now);
set bereq.http.host = var.awsBucket ".s3." var.awsRegion ".amazonaws.com";
set bereq.url = querystring.remove(bereq.url);
# Preserve '+' in paths (e.g. ci builds such as v1.36.0-alpha.1+abc)
set bereq.url = regsuball(bereq.url.path, "[+]", "__FASTLY_PLUS__");
set bereq.url = regsuball(urlencode(urldecode(bereq.url)), {"%2F"}, "/");
set bereq.url = regsuball(bereq.url, "__FASTLY_PLUS__", "%2B");
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

set var.scope = var.dateStamp "/" var.awsRegion "/s3/aws4_request";

set var.stringToSign = "" +
    "AWS4-HMAC-SHA256" + LF +
    bereq.http.x-amz-date + LF +
    var.scope + LF +
    regsub(digest.hash_sha256(var.canonicalRequest),"^0x", "")
  ;

set var.signature = digest.awsv4_hmac(
    var.awsSecretKey,
    var.dateStamp,
    var.awsRegion,
    "s3",
    var.stringToSign
  );

set bereq.http.Authorization = "AWS4-HMAC-SHA256 " +
    "Credential=" + var.awsAccessKey + "/" + var.scope + ", " +
    "SignedHeaders=" + var.signedHeaders + ", " +
    "Signature=" + regsub(var.signature,"^0x", "")
  ;
unset bereq.http.Accept;
unset bereq.http.Accept-Language;
unset bereq.http.User-Agent;
unset bereq.http.Fastly-Client-IP;
%{ endif ~}
}

%{ endfor ~}
