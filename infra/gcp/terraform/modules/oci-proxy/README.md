# oci-proxy common module

This module contains ~all of the config for oci-proxy / oci-proxy-staging.

Staging is expected to continuously lead production rollouts and changes
will be vetted in staging before manually rolling out to production.

The only differences between staging and production are inputs variables
to this module, such as domain and IP address.
