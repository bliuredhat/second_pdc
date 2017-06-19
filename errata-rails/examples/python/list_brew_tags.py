#!/usr/bin/python
#***********************************************************************
#
# Fetch a list of enabled product versions and list their brew tags
#
#***********************************************************************
import pycurl
import sys
import json

try:
    from cStringIO import StringIO
except ImportError:
    from StringIO import StringIO

BASE_URL = 'https://errata.devel.redhat.com'
PRODUCTS_URL = '/products.json'
PRODUCT_VERSIONS_URL = '/products/{0}/product_versions.json'
PRODUCT_VERSION_URL = '/products/{0}/product_versions/{1}.json'
DEBUG = False

def curl_request(feed_url):
    c = pycurl.Curl()
    c.setopt(c.USERPWD, ':')
    c.setopt(c.HTTPAUTH, c.HTTPAUTH_GSSNEGOTIATE)
    c.setopt(c.SSL_VERIFYPEER, 0)
    c.setopt(c.URL, feed_url)
    buffer = StringIO()
    c.setopt(pycurl.WRITEFUNCTION, buffer.write)
    c.perform()
    return buffer.getvalue()

def json_request(url):
    response = curl_request(BASE_URL + url)
    return json.loads(response)

# Get all products
products = json_request(PRODUCTS_URL)

# Exclude inactive products
active_products = [p for p in products if p['product']['isactive']]

for p in active_products:
    product = p['product']

    if DEBUG: print product

    # Get all product versions for this product, exclude disabled
    product_versions = json_request(PRODUCT_VERSIONS_URL.format(product['id']))
    enabled_product_versions = [p for p in product_versions if p['product_version']['enabled']]

    # Skip if there are no enabled product versions
    if len(enabled_product_versions) == 0: continue

    print("\n{short_name} - {name} - {id}".format(**product))

    for pv in enabled_product_versions:
        product_version = pv['product_version']

        if DEBUG: print product_version

        print(" - {name} {id}".format(**product_version))

        # (product_version contains some useful fields, but not the full list of brew_tags, hence we need another request)
        product_version_details = json_request(PRODUCT_VERSION_URL.format(product_version['product_id'], product_version['id']))

        if DEBUG: print product_version_details

        print("   - tags: {0}".format(', '.join(product_version_details['brew_tags'])))
        print("   - default_tag: {0}".format(product_version['default_brew_tag'] if product_version['default_brew_tag'] else '-'))
