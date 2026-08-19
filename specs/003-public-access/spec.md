# 003 - Public access

**Status:** done

## Problem

The dashboard and the model endpoint need to be reachable by someone who is not
on the machine, on a host with no public IP and no inbound ports.

## Success criteria

1. Valid HTTPS, no certificate management on the origin.
2. No inbound ports opened, no public IP required.
3. Dashboard and API protected by different mechanisms suited to their consumers.

## Out of scope

Multi-user access control, audit logging, rate limiting beyond the API key.
