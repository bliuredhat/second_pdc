### Reduced vulnerability to cross-site scripting (XSS) attacks

In a number of places Errata Tool was not properly escaping user modifiable
content. This allowed a potential attacker to inject malicious javascript
which could be executed in Errata Tool users' browsers.

This has been rectified in Errata Tool 3.10.4 by properly escaping all user
modifiable content when rendering it as HTML.
