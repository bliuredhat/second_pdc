### API additions for non-RPM file support

*Support for non-RPM files in Errata Tool is a work in progress,
 currently provided as a Technical Preview.*

APIs have been added and extended to enable the usage of non-RPM files
in advisories.

The additions include:

* [a 'build' API](https://errata.devel.redhat.com/rdoc/Api/V1/BuildController.html)
  for fetching the available files and their types for a Brew build.
* [a new method](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumController.html#method-i-add_builds)
  on the erratum API for adding builds to an advisory while specifying the types of files to be added.
* [a 'filemeta' API](https://errata.devel.redhat.com/rdoc/Api/V1/ErratumFileMetaController.html)
  for fetching and updating additional metadata associated with non-RPM files.
