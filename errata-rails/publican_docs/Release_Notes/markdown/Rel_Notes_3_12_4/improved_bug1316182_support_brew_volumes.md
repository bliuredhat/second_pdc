### Support non-production Brew volumes

Previously, Errata Tool only supported production brew volume.

Now Errata Tool has a configurable brew_top_dir variable which enables each
environment to set the mount point to its own brew root directory and also
stores volume name from Brew build data to database so that Brew RPM files
return the file_path prefixed with this mount point and volume name.

This allows the Errata Tool Staging environment to be used more effectively
with the Brew staging environment.

e.g)

* /mnt/redhat/brewroot/packages                   <-- default path
* /mnt/redhat/brewroot/vol/kernelarchive/packages <-- volume_name is given
* /mnt/brew/packages                              <-- brew_top_dir is changed
* /mnt/brew/vol/archive1/packages                 <-- both are given
