#!/usr/bin/python

from errata_listener import ErrataListener
from datetime import datetime

class SimpleListener(ErrataListener):
    def message_handler(self, msg):
        self.say('--------------------------')
        self.say('Received: ' + str(datetime.now()))
        self.say('Subject: ' + str(msg.subject))
        self.say('Content: ' + str(msg.content))

if __name__ == '__main__':
    SimpleListener().listen()
