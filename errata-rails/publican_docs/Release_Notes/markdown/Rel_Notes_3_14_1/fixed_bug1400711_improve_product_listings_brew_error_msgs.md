### Improve messages about Brew problems on Product Listings

Previously, on the Product Listings page, any troubles encountered
while trying to communicate with Brew could result in an
exception which presented too little or too much information,
depending on the ET environment -- production or non-production,
respectively.

Now, a summary of the problem appears instead, and appears
on the usual page in place of the product listing data.
This lets the user know what is happening, without getting
in the way of re-tries or other activities.

