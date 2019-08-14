#!/usr/bin/env python3

import os, sys
import google.auth
import google.cloud.storage
import google.oauth2.credentials

if len(sys.argv) != 3:
  print("syntax: %s <src> <dest>" % (sys.argv[0]))
  sys.exit(1)

storage_client = google.cloud.storage.Client()

# Build buckets, stripping gs:// prefix
src_bucket = sys.argv[1]
if src_bucket.startswith("gs://"):
  src_bucket = src_bucket[5:]
src_bucket = storage_client.get_bucket(src_bucket)

dest_bucket = sys.argv[2]
if dest_bucket.startswith("gs://"):
  dest_bucket = dest_bucket[5:]
dest_bucket = storage_client.get_bucket(dest_bucket)

# Build map of all blobs in both buckets
src_blobs = {}
for blob in storage_client.list_blobs(src_bucket):
  src_blobs[blob.name] = blob

dest_blobs = {}
for blob in storage_client.list_blobs(dest_bucket):
  dest_blobs[blob.name] = blob

# Copy blobs from src to dest, if the blobs don't exist in dest
# If the blob does exist in dest, but the md5 does not match,
# we don't overwrite it (this is for disaster recovery);
# we will exit with an error
num_copies = 0
num_matches = 0

mismatches = []
for k, src_blob in src_blobs.items():
  src_md5 = src_blob.md5_hash
  dest_blob = dest_blobs.get(k)
  if dest_blob:
    if dest_blob.md5_hash == src_md5:
      num_matches+=1
      continue
    else:
      # Don't erase our backup!
      mismatches.append(k)
      print("md5 mismatch on %s, won't copy" % (k))
      continue
  print("copying %s" % (k))
  src_bucket.copy_blob(src_blob, dest_bucket)
  num_copies+=1

# If we had any md5 mismatches, exit with an error report
if len(mismatches) != 0:
  print("mismatched md5 sums.... something has gone very wrong")
  for k in mismatches:
    print("  %s" % (k))
  sys.exit(1)

# Dump vanity stats
print("copied %d files, %d files had the same hash" % (num_copies, num_matches))
