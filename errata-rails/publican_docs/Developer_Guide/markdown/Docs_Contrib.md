Requirements
============

Markdown
--------

The source files for the Errata Tool documentation are written in Markdown.
Markdown is a text markup format that can be translated into HTML or in this
case DocBook XML.

To contribute a basic understanding of Markdown syntax is needed.
Read more about Markdown at the [official site](http://daringfireball.net/projects/markdown/) or
[Wikipedia](http://en.wikipedia.org/wiki/Markdown).

Text Editor
-----------

Markdown files are plain text, so you should have a decent text editor handy to
edit them, preferably one that can do syntax highlighting for markdown files.

If using RHEL or Fedora a good editor to start with is gedit.


Git
---

To get the source files, clone the Errata Tool git repo. You
need to have git installed on your workstation. If you don't have it, use `sudo yum install git` to install git.


Gerrit
------

Errata Tool uses Gerrit for code review and merging updates into the main
branches.

Using Gerrit requires that a ssh public key is set up in Gerrit. There are
some instructions on how to do that in the [Gerrit User Guide](https://docs.engineering.redhat.com/x/YgQjAQ).

Once a repo is checked out ensure that the commit hook is configured. The hook
will automatically add the change id to commit messages and remove the need
for you to do so manually.

If you don't have an account in Gerrit, you can alternatively push commits to
a clone of the Errata Tool repo that we can pull from. Gerrit makes this
process more convenient and allows the commit to be reviewed and commented on
by others prior to being merged.


Procedure
=========

Getting started
---------------

Firstly, make a local clone the Errata Tool git repo. The git repo
will be created by default as a subdirectory of the directory you are currently in.

For example, to clone the git repo in `~/dev/errata-rails` do the
the following.

````Bash
cd ~/dev
git clone git+ssh://code.engineering.redhat.com/errata-rails.git
cd errata-rails
````

Please configure the commit hook to automatically add a change id to your
commit message. This is described
[here](https://docs.engineering.redhat.com/display/HTD/Gerrit+User+Guide#GerritUserGuide-Recommendedworkflowtocreatecodereviews)

Create a local version of the develop branch and set it to track the remote
develop branch as follows:

````Bash
git checkout -b develop origin/develop --track origin/develop
````

File locations
--------------

All the Errata Tool documentation source files are located in the `publican_docs`
directory. There are three books, each in their own folder under `publican_docs`.
View them as follows:

````Bash
$ cd publican_docs
$ ls
Developer_Guide  Release_Notes  User_Guide
````

Each book has a similar directory structure.

````
└── Book_Name
    ├── Main.erb
    ├── markdown
    │   ├── images -> ../en-US/images
    │   ├── [Markdown_File].md
    │   └── ...
    ├── en-US
    │   ├── Author_Group.xml
    │   ├── Book_Info.xml
    │   ├── images
    │   │   ├── [image_file]
    │   │   └── ...
    │   ├── Main.ent
    │   └── Preface.xml
    └── publican.cfg
````

Markdown files
--------------

The `*.md` files in the markdown directory are where the content is authored.
Look in those files to see what they look like.

A top level heading in a markdown file will become a chapter when
the book is built.

The markdown files are converted into DocBook XML when the book is built and
then assembled. The order in which they are assembled is defined
in the `Main.erb` file.

Main.erb
--------

This file defines the overall book structure. It is a small file and consists
mainly of `include` statements that outline the order of the book's parts, chapters
and sections.

There are a few helper methods used in Main.erb to improve maintainability and
cut down on XML boilerplate. (They are defined in
`lib/docbook_erb/helpers.rb`).

*   `book`

    A wrapper that surrounds the whole book. It has no arguments and it takes
    a block terminated by the `<% end %>` delimiter.

*   `part`

    A wrapper that surrounds a book 'part'. It takes some arguments that
    define the part's number, title, and description. The part is also
    terminated by the `<% end %>` delimiter.

*   `include_generated`

    Used to include the contents of another file. In this context these files are
    generated from the markdown files in the markdown directory. The
    include is done prior to Publican running, so the included content
    does not need to be a valid XML document.

*   `xi_include`

    Used to include an XML file such that the include is processed in XML by
    Publican, therefore the included file must be a valid XML document. In
    this case we use xi_include for including non-generated XML files such as
    `Book_Info.xml`.

The helper methods other than `book` take an options hash that can be used to indicate
whether the part or include is 'draft'. If it is 'draft' then it will only be
included when building the documentation in draft mode.

This hash allows the same Main.erb file to be used to build a production version of
a book or a 'draft' version which may contain placeholder content that we
don't want to be included in the production book.

When the book is built Main.erb is converted into Main.xml in the en-US
directory.

As an example, here is the Main.erb for the Errata Tool Developer Guide.

<!-- not really JSP but there's no ERB syntax highlighting :( -->

````JSP
<% book do %>
  <%= xi_include "Book_Info.xml" %>

  <% part("I", "Contributing to Documentation", "How to contribute to the Errata Tool documentation") do %>
    <%= include_generated "Docs_Contrib.xml" %>
  <% end %>

  <% part("II", "System Integration Guide", "For developers who want to interact with Errata Tool") do %>
    <%= include_generated "JSON_API.xml" %>
    <%= include_generated "XMLRPC_API.xml", :draft => true %>
    <%= include_generated "Teiid.xml", :draft => true %>
    <%= include_generated "Qpid.xml", :draft => true %>
  <% end %>

  <% part("III", "Errata Tool Developer Guide", "For developers working on Errata Tool (or its documentation)") do %>
    <%= include_generated "Introduction.xml" %>
    <%= include_generated "Tools_Overview.xml" %>
    <%= include_generated "Workflows_Processes.xml" %>
    <%= include_generated "Environment_Setup.xml" %>
  <% end %>

  <% part("IV", "System Administration Guide", "Deployment and system administration guide for Eng-Ops", :draft=>true) do %>
    <%= include_generated "Sysadmin_Intro.xml", :draft=>true %>
  <% end %>
<% end %>
````

Hopefully the way that the helpers are used is fairly self explanatory, but if
you have any questions about it please ask on
[errata-dev-list@redhat.com](mailto:errata-dev-list@redhat.com).

In general you won't need to touch Main.erb unless you are adding a new
chapter or section to the book, or changing the book's structure or order.

Other files
-----------

The other XML files in the `en-US` directory and the `publican.cfg` file are
required to build the book, but in general they should be left as is unless
you know what you are doing.


Adding your content
===================

Amending an existing chapter or section
---------------------------------------

To amend or add to an existing section of the Errata Tool documentation, first
find which markdown file contains the section to be amended.

````Bash
# First make sure your local develop is up to date
git checkout develop
git fetch origin
git merge origin/develop

# Create a branch for your changes so that we aren't committing
# in the develop branch
git checkout -b 'some_local_branch_name' # create a branch
````

Edit the file or files as required. Once finished make a commit and push it to
Gerrit for review. This can be done as follows:


````Bash
# Prepare commit
git diff # check changes
git add path/to/File_You_Updated.md # stage the changes
git status # review files added
git diff --staged # confirm changes

# Do commit
git commit # use text editor to write a commit message describing your change

# Push it to Gerrit
git push origin HEAD:refs/for/develop # create Gerrit change set
````

If there are any screenshots or other images then you would need to also `git
add` those prior to committing.

In the case where you have already done the above and you notice some
corrections are required, or some changes were requested via Gerrit, then do
the following.

````Bash
# Prepare commit (as before)

# Do commit --amend (ie, don't make a new commit)
git commit --amend # use text editor to amend commit message if required

# Push it to Gerrit
git push origin HEAD:refs/for/develop # create new patch for existing Gerrit change set
````

If you do it that way (and the Change-Id is present in the commit message)
then Gerrit will know that the new patch is for the existing change set.

Again, if you would like some help with the above, please email
[errata-dev-list@redhat.com](mailto:errata-dev-list@redhat.com) or ask on
`#erratadev` on IRC.

Adding a brand new chapter or section
-------------------------------------

Basically the method is identical to the method described above in the section
on amending content, except you might create brand new markdown files as
required, and then edit the corresponding Main.erb to include the files.

Reviewing the result
====================

There are two approaches to checking that your contributed markdown builds
correctly and looks as you intended.

Viewing a preview build of the book
-----------------------------------

If you push a commit up to Gerrit the books will be automatically built by
Jenkins. The generated HTML can be found by clicking 'Build Artifacts' on the
main page of the Jenkins build. This way you or a reviewer can check
that the build succeeds and that the new content looks the way it was intended
to look.

Building the book yourself
--------------------------

Note that is possible to build the book yourself locally (either on your
workstation or on a suitable VM) if you have the required ruby, publican and
pandoc dependencies installed. Please contact
[errata-dev-list@redhat.com](mailto:errata-dev-list@redhat.com) for advice if
you want to do that, or refer to the
[Setting up a development VM](https://docs.engineering.redhat.com/x/ipH-AQ)
page in Confluence.

### Build commands

Once your environment is set up, there are a few commands you can use to build
and view a book.

You can see a list of tasks related to building the books by running `rake -T
publican`. (Take a look in `lib/task/publican.rake` to see where the tasks are
defined).

*   `rake publican:build BOOK=Book_Name`

    This will build the html-single version of the book and show it to you in
    Firefox.

*   `rake publican:build_all BOOK=Book_Name`

    This will build all versions of the book.

*   `rake publican:clean BOOK=Book_Name`

    This removes all temporary files generated by Pandoc or publican for a
    book.

In the above, replace Book_Name with the directory name of the book you are
working on, such as User\_Guide, Developer\_Guide or Release\_Notes. BOOK is
just an environment variable, so you can also just set it if you are going to
be working on a particular book, then `rake publican:build` will operate on
the book specified by the environment variable.

````Bash
export BOOK=Book_Name
````

To turn on 'draft mode' which will include items in Main.erb that specify
`draft=>true`, use the DRAFT environment variable. For example:

*   `rake publican:build BOOK=Book_Name DRAFT=1`

    Build including draft mode items.

Similarly you can set an environment variable to enable draft mode more
permanently.

````Bash
export DRAFT=1
````

Setting DRAFT to 0 will turn it off if it is already set, eg:
````Bash
export DRAFT=0
````
