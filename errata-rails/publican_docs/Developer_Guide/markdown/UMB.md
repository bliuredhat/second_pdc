UMB Messaging
==============

### Authentication & Authorization

#### Broker
> [UMB Environments](https://mojo.redhat.com/docs/DOC-1048438#jive_content_id_Broker)

#### Certificates authentication

> The broker is now secured with mutual SSL authentication, and anything that
connects to the broker must have a client certificate

> [How To: Request a Messaging Client Certificate from RHCS](https://mojo.redhat.com/docs/DOC-1072086)

#### Authorization
> [Authorization](https://mojo.redhat.com/docs/DOC-1072549#jive_content_id_Authorization)

### Errata Tool Topic Hierarchy

* VirtualTopic.eng.errata
	* eng.errata.activity.created
	* eng.errata.bugs.changed
	* eng.errata.builds.changed
	* eng.errata.activity.docs_approval
	* eng.errata.activity.product
	* eng.errata.activity.release
	* eng.errata.activity.embargo_date
	* eng.errata.activity.signing
	* eng.errata.activity.status

### Message Content

Note: Currently there is no access control for consuming on UMB topics, so we want to support
to publish the message with “material information” redacted for embargoed advisories. ( e.g.:
the fields marked **bold** and _italic_ )

#### errata.activity.created

##### Header

* subject: errata.activity.created (string)
* **_who_**: string
* when: string
* errata_id : int
* type: string
* **_release_**: string
* **_synopsis_**: string

##### Body

* **_who_**: string
* when: string
* errata_id: int
* type: string
* **_release_**: string
* **_synopsis_**: string

##### Examples

````
Subject: errata.activity.created
Header: {
    "subject"=>"errata.activity.created",
    "who"=>"qa@redhat.com",
    "when"=>"2017-01-18 08:49:26 UTC",
    "errata_id"=>23115,
    "type"=>"RHBA",
    "release"=>"ASYNC",
    "synopsis"=>"test 1"
}
Body: {
    "who"=>"qa@redhat.com",
    "when"=>"2017-01-18 08:49:26 UTC",
    "errata_id"=>23115,
    "type"=>"RHBA",
    "release"=>"ASYNC",
    "synopsis"=>"test 1"
}
````

#### errata.bugs.changed

##### Header

* subject: errata.bugs.changed (string)
* **_who_**: string
* when: string
* errata_id: int

##### Body

* **_who_**: string
* when: string
* errata_id: int
* added:  array ([Issue])
* dropped:  array ([Issue])

##### Issue

* id: bugId / issueKey (string)
* type: “RHBZ” / “JBossJIRA”  (string)

##### Examples

````
Subject: errata.bugs.changed
Header: {
    "subject"=>"errata.bugs.changed",
    "when"=>"2017-01-18 08:55:56 UTC",
    "errata_id"=>23111,
    "who"=>"errata-test@redhat.com"
}
Body: {
    "who"=>"errata-test@redhat.com",
    "errata_id"=>23111,
    "when"=>"2017-01-18 08:55:56 UTC"
    "dropped"=> [
        {"id":499035,"type":"RHBZ"}
     ],
    "added"=> [
        {"id":440624,"type":"RHBZ"}
     ]
}
````

#### errata.builds.changed

##### Header

* subject: errata.builds.changed (string)
* **_who_**: string
* when: string
* errata_id: int

##### Body

* **_who_**: string
* when: string
* errata_id: int
* **_added_**: brew build array ([string])
* **_removed_**: brew build array ([string])

##### Examples

````
Subject: errata.builds.changed
Header: {
    "subject"=>"errata.builds.changed",
    "who"=>"qa-errata-list@redhat.com",
    "when"=>"2017-01-18 09:01:07 UTC",
    "errata_id"=>10808
}
Body: {
    "who"=>"qa-errata-list@redhat.com",
    "when"=>"2017-01-18 09:01:07 UTC",
    "errata_id"=>10808,
    "dropped"=>[],
    "added"=>["coreutils-8.15-6.1.el7"]
}
````

#### errata.activity.*

##### Header

* subject: errata.activity.* (string)
* **_who_**: string
* when: string
* errata_id: int
* **_errata_status_**: string
* **_synopsis_**: string
* **_from_**: string
* **_to_**: string
* **_fulladvisory_**: string

##### Body

* **_who_**: string
* when: string
* errata_id: int
* **_errata_status_**: string
* **_synopsis_**: string
* **_from_**: string
* **_to_**: string
* **_fulladvisory_**: string

##### Examples

````
Subject: errata.activity.status
Header: {
    "subject"=>"errata.activity.status",
    "who"=>"qa-errata-list@redhat.com",
    "when"=>"2015-03-12 00:00:00 UTC",
    "errata_id"=>16409,
    "errata_status"=>"NEW_FILES",
    "from"=>"QE",
    "to"=>"NEW_FILES",
    "fulladvisory"=>"RHBA-2014:16398-01",
    "synopsis"=>"Updated packages for spice-client-msi"
}
Body: {
    "who"=>"qa-errata-list@redhat.com",
    "when"=>"2015-03-12 00:00:00 UTC",
    "errata_id"=>16409,
    "errata_status"=>"NEW_FILES",
    "from"=>"QE",
    "to"=>"NEW_FILES",
    "fulladvisory"=>"RHBA-2014:16398-01",
    "synopsis"=>"Updated packages for spice-client-msi",
}
````

For the redacted information, the value of the attributes will be marked as "REDACTED". e.g:

````
{
    "subject":"errata.activity.foo",
    "who":"REDACTED",
    "errata_id":16409,
    "errata_status":"REDACTED",
    "from":"REDACTED",
    "to":"REDACTED",
    "when":"2017-01-19 03:19:52 UTC",
    "synopsis":"REDACTED",
    "fulladvisory":"REDACTED"
}
````
