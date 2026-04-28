# IMPORTANT

In order to avoid "dangling" NS delegations, it is really important that any NS
records *not* be included in the "base" files.  These files also serve as
canary configs, and any NS record in them becomes another level of delegation,
which can be attacked or hijacked.

E.g. if `example.com._0_base.yaml` includes an NS record for `foo`, that
creates a `foo.example.com` zone.  We use the same config for
`canary.example.com` which means it ALSO creates a `foo.canary.example.com`
delegation, which we do not claim.

All NS records must go in non-canaried files.
