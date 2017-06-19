### Improve MULTI tag to contain three states

The enabled/disabled states were no longer adequately representing the
desired multiple product options for advisories.

It's been improved. The MULTI tag contains three states: Unset, ON and OFF.

The meaning of each state is as follows:

- Unset - Default value. While unset, no MULTI label is displayed on errata list
or summary page, and 'Supports Multiple Product?' field is displayed on the
errata edit page.

- ON - ET will automatically set this ON when saving builds if relevant multi
product mappings are found and currently being Unset. MULTI-ON label and the
field are now displayed.

- OFF - Set when user manually unsets 'Supports Multiple Product?'. So this
state can only be entered from ON, but not Unset. 'Supports Multiple
Product?' field shows on the errata edit page, MULTI-OFF label shows.

'Supports Multiple Product?' field only shows when user has proper access on
errata edit page.
