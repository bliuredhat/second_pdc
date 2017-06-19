### Move bugs to ON_QA when advisory moves to QE state for some products

Products may now be configured so that bugs do not get moved to ON_QA state
when added to an advisory, but move when the advisory transitions to QE
state.

This workflow variation is a better fit for the processes used by RHEV and
some other non-RHEL products. It allows developers in those products to avoid
costly delays related to bugs having their status changed too soon.

This flag is configurable through the UI. The option "Move bugs to ON_QA"
has two available choices, "When bugs are added to advisory" and "When
advisory moves to QE state".

[![Move bugs to ON_QA](images/3.11.4/move_bugs.png)](images/3.11.4/move_bugs.png)

This change sets the "When advisory moves to QE state" for the RHEV product.
All other products retain their existing behavior, but can be configured to
use the new option as required.
