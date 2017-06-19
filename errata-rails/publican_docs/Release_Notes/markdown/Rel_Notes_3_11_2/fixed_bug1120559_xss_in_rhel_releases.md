### Fixed cross-site scripting vulnerabilities

In some places user data was unsafely rendered as HTML without proper
escaping. This made it possible for a user to enter data that would cause
arbitrary javascript to be executed. Identified vulnerabilities have been
fixed by properly escaping unsafe data when rendering HTML.

For more information on the prevention of cross-site scripting, please see the [XSS
Prevention Cheat Sheet](https://www.owasp.org/index.php/XSS_(Cross_Site_Scripting)_Prevention_Cheat_Sheet)
and the [Ruby on Rails Security Guide](http://guides.rubyonrails.org/security.html#cross-site-scripting-xss)
