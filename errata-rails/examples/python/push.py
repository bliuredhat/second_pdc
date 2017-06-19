#!/usr/bin/env python
# This script may be used to trigger and monitor advisory pushes.
#
# In the default usage, it performs live pushes with default options
# for every advisory ID given on the command-line.
#
# $ python push.py 18216 18416 18669 18677
# Triggering push for advisories: [18216, 18416, 18669, 18677]
# Monitoring push status ...
#
# erratum 18416 rhn_live: WAITING_ON_PUB
#
#   2014-09-19 16:43:21 +1000 Running pre push tasks
#   2014-09-19 16:43:21 +1000 Running pre push task set_live_id
#   2014-09-19 16:43:21 +1000 Running task set_live_id
#   2014-09-19 16:43:22 +1000 Changed RHBA-2014:18416 to public name: RHBA-2014:1190
#   2014-09-19 16:43:22 +1000 Running pre push task set_update_date
#   2014-09-19 16:43:22 +1000 Running task set_update_date
#   2014-09-19 16:43:22 +1000 Updated Update date
#   2014-09-19 16:43:22 +1000 Running pre push task check_jira
#   2014-09-19 16:43:22 +1000 Running task check_jira
#   2014-09-19 16:43:22 +1000 Running pre push task set_in_push
#   2014-09-19 16:43:22 +1000 Running task set_in_push
#   2014-09-19 16:43:22 +1000 Changing state to IN_PUSH by Devel User (errata-test@redhat.com)
#   2014-09-19 16:43:22 +1000 Advisory now IN_PUSH
#   2014-09-19 16:43:22 +1000 Running pre push task set_issue_date
#   2014-09-19 16:43:22 +1000 Running task set_issue_date
#   2014-09-19 16:43:22 +1000 Updated Issue date
#   2014-09-19 16:43:22 +1000 Pub task created, task id: 42867
#   2014-09-19 16:43:22 +1000 Link to the pub task: http://pub.qa.engineering.redhat.com/pub/task/42867
#   2014-09-19 16:43:22 +1000 Waiting on pub to finish.
#
#
# erratum 18416 ftp: WAITING_ON_PUB
# (... etc, until the pushes complete:)
#
# Finished:
#   erratum 18416 rhn_live: FAILED
#   erratum 18416 ftp: COMPLETE
#   erratum 18669 rhn_live: COMPLETE
#   erratum 18669 ftp: COMPLETE
#   erratum 18677 rhn_live: FAILED
#   erratum 18677 ftp: COMPLETE
#   erratum 18677 cdn: COMPLETE
#

import requests
from requests_kerberos import HTTPKerberosAuth
from requests_kerberos import OPTIONAL
from optparse import OptionParser
import sys
from time import sleep
import json
import itertools

class Pusher:
    def verbose_print(self, message):
        if self.verbose:
            sys.stdout.write(message)
            sys.stdout.flush()

    def extract_error(self, req):
        text = req.text
        http_line = "HTTP {r.status_code} {r.reason}".format(r=req)

        if len(text) == 0:
            return http_line

        try:
            object = json.loads(text)
            if 'error' in object:
                return object['error']
            elif 'errors' in object:
                errors = object['errors']
                return "\n".join( ["%s:\n  %s" % (k, "\n  ".join(errors[k])) for k in errors.keys()] )
            raise KeyError('no error or errors key')
        except StandardError:
            return "%s\n(the error body returned by errata tool could not be parsed!)\n%s" % (http_line, text)

    def parse_json(self, text, url):
        try:
            return json.loads(text)
        except (ValueError, TypeError):
            raise RuntimeError("%s did not return valid JSON!\n%s" % (url, text))

    def http_request(self, method, maybe_relative_url, data=None):

        url = self.url + maybe_relative_url
        if '://' in maybe_relative_url:
            url = maybe_relative_url

        self.verbose_print("%s %s :" % (method, url))

        r = requests.request(method, url, auth=HTTPKerberosAuth(mutual_authentication=OPTIONAL), verify=not self.insecure,
                             headers={"Accept": 'application/json', 'Content-Type': 'application/json'},
                             data=data)

        self.verbose_print(" %s\n" % r.status_code)

        if r.status_code >= 400:
            raise RuntimeError("Error while requesting %s:\n%s" % (url, self.extract_error(r)))

        return self.parse_json(r.text, url)

    def GET(self, url):
        return self.http_request('GET', url)

    def POST(self, url, data=None):
        if data != None:
            data = json.dumps(data)
        return self.http_request('POST', url, data)

    def push_category(self):
        if self.live:
            return 'live'
        return 'stage'

    def start_push(self, erratum):
        url = "api/v1/erratum/%s/push" % erratum
        pushdata = []
        if len(self.targets) > 0:
            pushdata = [{"target":x} for x in self.targets]
        else:
            url = url + "?defaults=" + self.push_category()
        return self.POST(url, pushdata)

    def dump_push_info(self, last, info):
        id = info['id']
        target = info['target']['name']
        errata_id = info['errata']['id']
        status = info['status']
        log = info['log']

        lastlog = None
        lastlog_len = 0
        laststatus = None
        if last.has_key('log'):
            lastlog = last['log']
            lastlog_len = len(lastlog)
            laststatus = last['status']

        if lastlog != log or laststatus != status:
            print "\nerratum %s %s: %s" % (errata_id, target, status)
            logprint = log[lastlog_len:]
            if len(logprint) != 0:
                print "  %s\n" % ("\n  ".join(logprint.split("\n")))

    # generator will keep iterating until push is in a terminal state
    def monitor_push(self, push_url):
        last_info = {}
        while True:
            info = self.GET(push_url)

            self.dump_push_info(last_info, info)

            if info['status'] in ['COMPLETE', 'FAILED']:
                yield(info)
                return

            last_info = info
            yield(info)

    def run(self):
        print "Triggering push for advisories: %s" % self.errata_ids
        push_urls = itertools.chain(*[[p['url'] for p in self.start_push(id)] for id in self.errata_ids])

        print "Monitoring push status ..."

        monitors = [self.monitor_push(url) for url in push_urls]

        # Each iteration of all_monitors will poll pushes until they're all completed.
        all_monitors = itertools.izip_longest(*monitors)
        latest_by_id = {}
        for x in all_monitors:
            for push_job in filter(None,x):
                latest_by_id[push_job['id']] = push_job
            sys.stdout.write('.')
            sys.stdout.flush()
            sleep(15)

        print "\nFinished:"
        for k,v in latest_by_id.iteritems():
            print "  erratum %s %s: %s" % (v['errata']['id'], v['target']['name'], v['status'])

def main(args):
    parser = OptionParser("""usage: %prog [options] advisory_id [advisory_id ...]
Trigger one or more advisory pushes and wait for completion.

This script will perform pushes on one or more advisories and monitor
their progress, blocking until the pushes complete.
""")

    pusher = Pusher()
    parser.add_option("--url", dest="url", default="https://errata-devel.app.eng.bos.redhat.com/",
                      help="Base URL of Errata Tool")
    parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=False,
                      help="Print info about every HTTP request made")
    parser.add_option("-k", "--insecure", action="store_true", dest="insecure", default=False,
                      help="Don't verify HTTPS connection")
    parser.add_option("--target", action="append", dest="targets", default=[],
                      help="Specify one or more push target(s), e.g. rhn_live, cdn.")
    parser.add_option("--live", action="store", dest="live", default=True,
                      help="Push to default live targets. (default)")
    parser.add_option("--stage", action="store", dest="stage", default=False,
                      help="Push to default stage targets.")

    (options, args) = parser.parse_args(args)

    args.pop(0)

    for attr in ['insecure', 'verbose', 'live', 'stage', 'targets', 'url']:
        setattr(pusher, attr, getattr(options, attr))

    if not pusher.url.endswith('/'):
        pusher.url += '/'

    # remaining arguments should be advisory IDs
    pusher.errata_ids = [int(x) for x in args]

    pusher.run()

if __name__ == '__main__':
    main(sys.argv)
