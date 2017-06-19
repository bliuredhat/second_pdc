### Create new packages if required for CDN repository mapping

Previously, the CDN repository package mapping feature (used for Docker
CDN repositories) required packages to exist in Errata Tool. This could
cause problems if the package did not exist in CYP.

Now, if a mapping is created for a package name that does not exist, the
package will be automatically created, with default QE responsibility.
