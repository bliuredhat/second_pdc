About Errata Tool
=================

Overview
--------

The Errata Tool is a process management tool that ensures the release
readiness of advisories by monitoring and enforcing company requirements and
policies defined by the Quality Engineering and Release Engineering groups for
shipping products to customers. It ensures that processes, such as the
Content Definition Workflow (CDW), and tests, such as RPMDiff and TPS, are
followed and completed before Red Hat content is pushed for release to
customers via RHN and/or CDN.

The Errata Tool has primarily been utilised for ASYNC and other minor release
streams, tracking Y-stream, Z-stream, Long Life (LL), Extended Update Support
(EUS) and Advanced Mission Critical Update Support (AUS) releases for RHEL and
RHEL-related RPM-based content.
(Non-RPM-based content has historically been released via text-only advisories,
but this is likely to change during 2016).

Errata Lifecycle
----------------

An advisory moves through several stages, known as `states` along the way to
being shipped. The states are `NEW_FILES`, `QE`, `REL_PREP`, `PUSH_READY`,
`IN_PUSH`, `SHIPPED_LIVE` and `DROPPED_NO_SHIP`. The following is an overview
of a typical advisory's lifecycle.

A new advisory is created in NEW\_FILES, typically by a developer. The package
and release is specified as well as the initial text content. Bugs are added,
either automatically, based on CDW flags and Approved Component Lists for
Y-stream advisories, or manually for other release types. Brew builds are
then added to the advisory. Once all builds are added (and RPMDiff tests are
passing or waived), the advisory can be moved to QE.

Testing (automated and manual) is done by QE in this state. If QE is satisfied
that the advisory meets all requirements then the advisory can move to
REL\_PREP. In the case where further changes to the advisory are required, the
advisory will be moved back to NEW\_FILES. The advisory's text content is
also reviewed, and must receive approval from ECS during this stage.

During the REL\_PREP stage, Rel Eng will complete any requirements needed to
publish the packages. This includes signing and pushing to RHN/CDN stage if
appropriate.

Additionally, security advisories (RHSA) must be approved by
the Product Security Team before the advisory may move on from REL\_PREP.
The approval must be requested from the advisory summary page.
(If an approval is urgently required, please also request it via email
to <secalert@redhat.com>.)

When the REL\_PREP requirements are complete, the advisory is moved to
PUSH\_READY where it will be picked up automatically for publishing. While
the publishing process is underway the advisory goes to IN\_PUSH, then
finally SHIPPED\_LIVE when the process is complete.

If, for any reason, an advisory will not be published, its state is set to
DROPPED\_NO\_SHIP.

<!---
(A rough draft outline for possible future users guide content...)

# Errata Lifecycle

## Advisory States

### NEW\_FILES State

### QE State

### REL\_PREP State

### PUSH\_READY State

### SHIPPED\_LIVE State

### DROPPED\_NO\_SHIP State

## State Transitions & Blockers

## Documentation Approval Workflow


# Using Errata Tool

## Creating an Advisory

## Using Filters

## Adding/Removing Bugs

## Adding/Removing Builds

## RPMDiff

## TPS Jobs

## ABIDiff

## Docs

## Pushing an Advisory


# Managing Products & Releases


# Managing Channels & Variants


# Interactions With Other Systems

-->
