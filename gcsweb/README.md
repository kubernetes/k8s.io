`gcsweb` is a tiny web frontend to [GCS](https://cloud.google.com/storage/docs/) browsing that DOES NOT REQUIRE A GOOGLE LOGIN.

**Problem**:

`kubernetes` releases can be either downloaded using direct API links to specific
files. However, to browse all available files at
https://console.cloud.google.com/storage/browser/kubernetes-release/release/
or with `gsutil` people need Google login.

**Solution**:

Run a public web app that uses authenticated requests on backend to extract
information about directory structure and present it to the users with direct
links specific files via traditional access method.
