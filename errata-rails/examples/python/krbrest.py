#!/usr/bin/python
import pycurl
import sys
try:
    from cStringIO import StringIO
except ImportError:
    from StringIO import StringIO

if __name__ == "__main__":
    feed_url = sys.argv[1]

    c = pycurl.Curl()
    c.setopt(c.USERPWD, ':')
    c.setopt(c.HTTPAUTH, c.HTTPAUTH_GSSNEGOTIATE)
    c.setopt(c.SSL_VERIFYPEER, 0)
    c.setopt(c.URL, feed_url)
    buffer = StringIO()
    c.setopt(pycurl.WRITEFUNCTION, buffer.write)
    c.perform()
    print buffer.getvalue()
