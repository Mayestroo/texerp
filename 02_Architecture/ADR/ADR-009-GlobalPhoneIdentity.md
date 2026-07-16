# ADR-009: Global Phone Identity for MVP

**Status:** ACCEPTED
**Date:** 2026-07-16

TexERP identifies each MVP User by one globally unique phone number and associates that User with exactly one Tenant. This keeps phone-and-PIN login unambiguous without adding a tenant slug or tenant-selection step; supporting one person across multiple tenants requires an explicit membership model in a later version.
