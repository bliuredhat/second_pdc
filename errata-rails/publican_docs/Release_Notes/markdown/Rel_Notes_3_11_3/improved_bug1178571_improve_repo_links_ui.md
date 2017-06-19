### Redesigned UI for managing channel and CDN repository links

The RHN Channels/CDN Repositories table in the product version page used to
display the RHN Channels/CDN Repositories that 'owned by' a variant, and then
provided the linked RHN Channels/CDN Repositories as additional information.
This can be misleading to maintainers of the channels and repos because the
content is being pushed based on the linked RHN Channel/CDN Repository not
the variant which owns it.

Therefore, the UI has been redesigned to make RHN Channels/CDN Repositories links
more obvious. The new UI only shows the RHN Channels/CDN Repositories that are linked
to a variant which means missing or incorrect links can be easily spotted by the
user when troubleshooting channel and repo configuration problems.

[![New UI](images/3.11.3/new-ui.png)](images/3.11.3/new-ui.png)

Previously, a shared 'create RHN Channel/CDN Repository' form was used to
create link which could be very confusing. The new UI improves this by providing
a simple one text box form with auto complete facility to create link.

[![Attach Repo](images/3.11.3/attach_repo.png)](images/3.11.3/attach_repo.png)

With the new UI, it is now possible to unlink multiple RHN Channels/CDN Repositories
in a single request.

[![Detach Repo](images/3.11.3/detach_repos.png)](images/3.11.3/detach_repos.png)

Additionally, the 'Link' and 'Unlink' terms have been replaced with 'Attach' and 'Detach'
to better reflect the new design.
