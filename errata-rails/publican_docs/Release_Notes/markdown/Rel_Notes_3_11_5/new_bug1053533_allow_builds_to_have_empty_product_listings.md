### Allow builds without product listings

Previously, developers were unable to add builds without product listings to
any advisory. This could slow down the development process because developers
could not proceed further to other tasks until the product listings were
created by RCM.

This workflow has been improved by allowing developers to add builds without
product listings to any advisory. Note that the advisory will be unable to
proceed from NEW\_FILES to QE until all the product listings are present.
Additionally Errata Tool also provides a help message to the developers if
there are any missing product listings, and suggests what action needs to be
taken to retry fetching them.

The following screen shot shows builds without listings attached to a
NEW_FILES advisory.

[![No listings](images/3.11.5/nolistings.png)](images/3.11.5/nolistings.png)
