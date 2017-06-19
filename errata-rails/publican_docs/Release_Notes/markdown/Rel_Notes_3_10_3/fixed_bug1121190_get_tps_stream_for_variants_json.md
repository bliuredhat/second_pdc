### Fix TPS stream not correctly calculated when accessing a variant as JSON

Information on the variants for a particular product version can be accessed in
JSON format at the following URL:

    /product_versions/$product_version_id/variants.json

In earlier versions of Errata Tool, the TPS stream field in this data was
missing or incorrect. This has been fixed in Errata Tool 3.10.3.

Additionally the format of the JSON has been improved and made consistent with
the format for a single variant.

The new format is illustrated in the following example:

```` Javascript
[
  {
    "id": 780,
    "name": "5Server-5.6.LL",
    "description": "Red Hat Enterprise Linux LL (v. 5.6 server)",
    "cpe": "cpe:/o:redhat:rhel_eus:5.6",
    "tps_stream": "RHEL-5.6-LL-Server",
    "product": { "id": 16, "short_name": "RHEL" },
    "product_version": { "id": 312, "name": "RHEL-5.6.LL" },
    "rhel_variant": { "id": 780, "name": "5Server-5.6.LL" },
    "rhel_release": { "id": 39, "name": "RHEL-5.6.LLZ" }
  },
  ...
]
````

<important>

The new format is significantly different to the old format, so if you have a
script that uses this data it will need to be updated.

See [the bug](https://bugzilla.redhat.com/show_bug.cgi?id=1121190) for more
information. Please add a comment there if this is likely to cause a problem
for you.

</important>
