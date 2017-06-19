### Fix missing TPS stream field in variant JSON data

Information for an individual variant can be accessed in JSON format at:

    /product_versions/$product_version_id/variants/$variant_id.json

Previously this did not include the TPS stream attribute. This has been fixed
in Errata Tool 3.10.3.
