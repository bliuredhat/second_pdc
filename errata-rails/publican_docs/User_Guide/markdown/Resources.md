Other Resources
===============

For Developers
--------------

*   **[How To File a New Advisory](filing-an-advisory-filing-an-advisory.html)**

    The best resource for developers is the 'Filing an Advisory' chapter of
    this documentation. It will walk you through filing a new advisory, adding
    builds, checking the RPMDiff results and moving the advisory to QE.  It was
    created by Radek Biba (rbiba).

For QE
------

*   **[Errata Workflow Wiki](https://wiki.test.redhat.com/ErrataWorkflow)**

    The *Errata Workflow Wiki* was also created by Radek Biba (rbiba). It is
    contains useful descriptions of Errata Tool concepts and processes. It is
    targeted at QE users, but it may also be useful to other types of users.

For Technical Writers
---------------------

*   **[Errata Howto](https://home.corp.redhat.com/wiki/erratahowto)**

    The *Errata Howto* is maintained by ECS. In contains information on how
    advisory content such as "Topic" and "Problem Description" should be written.

*   **[Errata Lore](https://engineering.redhat.com/docs/en-US/Policy/70.ecs/html/Errata_Lore/)**

    A compendium of Errata Tool terms and tips maintained by Engineering
    Content Services.

General Information and Resources
---------------------------------

*   **[Red Hat Engineer Accreditation Course Material](https://mojo.redhat.com/docs/DOC-69796)**

    The RHU course slide deck is available
    [here](https://mojo.redhat.com/servlet/JiveServlet/download/69796-9-57763/ENG111_Errata_Tool_and_Workflow_v2.1.pdf)
    and covers Errata Tool concepts. It includes useful diagrams showing the errata
    states and approval paths. (Note: the content is a couple of years old so some of
    the screenshots are out of date).

*   **[Errata on the Customer Portal](https://access.redhat.com/errata/)**

    This is where customers see errata once they make it through the Errata Tool
    workflow and are published.

*   **[Errata Tool Wiki](https://docs.engineering.redhat.com/display/HTD/Errata+Tool)**

    Contains schedules and other planning information about Errata Tool
    releases, as well as contact details and documentation for developers.

*   **[Errata Dev Mailing List](http://post-office.corp.redhat.com/mailman/listinfo/errata-dev-list)**

    Subscribe to errata-dev-list for discussion on Errata Tool development and
    upcoming features. You can also access the list archives via the url above.

*   **\#errata on IRC**

    Join the `#errata` IRC channel to discuss Errata Tool issues, contact an
    administrator or generally ask for help.

For Engineering Tools Developers
--------------------------------

*   **[Errata Tool Wiki](https://docs.engineering.redhat.com/display/HTD/Errata+Tool)**

    This is the primary wiki (in Confluence) for the Errata Tool development
    team. It is maintained by the developers and other team members. It
    includes information about team contact details, scheduling information,
    stakeholder lists and some documentation on processes.

*   **[Errata Tool Trac Wiki](https://engineering.redhat.com/trac/Errata_System/wiki/)**

    (Now deprecated in favor of the new Confluence page. All the content will
    be eventually migrated over to Confluence).

    It contains a collection of guides and how-tos, mostly with a
    technical focus. There is some information on interacting with Errata Tool
    via the Message Bus and XML-RPC.

*   **[Errata Tool API Docs](https://errata.devel.redhat.com/rdoc/)**

    These docs are generated automatically from the Errata Tool source code and
    show information about the Errata Tool classes and methods. The main useful
    part of these docs is the documentation of the XML-RPC API methods. The XML-RPC
    service classes are ErrataService, SecureService, PubService and TpsService.
    They are linked to from the
    [README](https://errata.devel.redhat.com/rdoc/doc/README_FOR_APP.html).

    Note that the XML-RPC API will in future be deprecated in favour of the
    HTTP/JSON API. See the [HTTP API](https://errata.devel.redhat.com/developer-guide/api-http-api.html)
    section in the [Developer Guide](https://errata.devel.redhat.com/developer-guide/)
    for documentation on the HTTP API.

*   **[Errata Tool Git Repo](https://code.engineering.redhat.com/gerrit/gitweb?p=errata-rails.git;a=summary)**

    You can browse the Errata Tool code via the above url, or you can git clone it
    in the usual way.
