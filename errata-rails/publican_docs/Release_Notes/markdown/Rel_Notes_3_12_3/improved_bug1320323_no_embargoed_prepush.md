### Do not pre-push embargoed errata

On request of the Product Security Team, the Errata Tool pre-push feature (introduced
in Errata Tool 3.12.2) has been restricted so that errata will not be pre-pushed if their
embargo date has not yet passed or if they contain fixes for embargoed bugs.

Although pre-pushed errata are not exposed to customers in the normal case, adding this
restriction gives additional confidence that embargoed errata won't be exposed earlier
than intended.
