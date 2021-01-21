# Cloud One Smart Check Installer Scripts

- [Cloud One Smart Check Installer Scripts](#cloud-one-smart-check-installer-scripts)
  - [Objective](#objective)
  - [Prerequisites](#prerequisites)
  - [Files](#files)

## Objective

This folder does contain some scripts to ease a Smart Check deployment in different environments. The deployment scripts are all capable of doing the initially required password change.

Please use `deploy-dns.sh` when the load balancer in the target environment uses a public DNS name (e.g. in AWS).

Use `deploy-ip.sh` if you only have an IP from the load balancer (e.g. in Azure).

The scripts `deploy-ng.sh` and `deploy-cpw.sh` do belong together. The first one deploys Smart Check as service of type `NodePort`. You will then need to create a publicly available service endpoint for Smart Check yourself. Do this for example by creating an ingress or setting up a proxy. Afterwards, the script `deploy-cpw.sh` can be used to do the password change. (e.g. in GCP)

All scripts require to have the following environment variables set:

Key | Value
--- | -----
`DSSC_NAMESPACE` | e.g. `smartcheck`
`DSSC_USERNAME` | e.g. `admin`
`DSSC_PASSWORD`| e.g. `trendmicro`
`DSSC_REGUSER` | e.g. `admin`
`DSSC_REGPASSWORD` | e.g. `trendmicro`
`DSSC_AC` | `<SMART CHECK ACTIVATION CODE>`

The script `deploy-cpw.sh` requires the additional variable `DSSC_HOST` to be set to the IP of the load balancer.

## Prerequisites

- Smart Check license
- Optional: Multi Cloud Shell

## Files

