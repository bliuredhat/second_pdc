### New web UI for multi-product mapping

A new web UI for managing multi-product mappings has been added. This UI
provides general CRUD features for mappings and their subscriptions.

Previously adding a new mapping was done manually via ticket queue request.
Making this process self-service will reduce the time and effort required to
manage multi-product mappings in Errata Tool.

[![New mapping](images/3.12.5/new_mapping.png)](images/3.12.5/new_mapping.png)

[![Creating a mapping](images/3.12.5/add_mapping.png)](images/3.12.5/add_mapping.png)

There are four fields required in the creation form.

  * Mapping Type : RHN channel, CDN repository
  * Package      : The name of package
  * Origin Channel/Cdn Repo
  * Destination Channel/Cdn Repo

Once a mapping has been created, subscribers, (users who receive notifications
about advisories using the mapping), may be added using the details page.

[![Adding subscribers](images/3.12.5/add_subscriber.png)](images/3.12.5/add_subscriber.png)
