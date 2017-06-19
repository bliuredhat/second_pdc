#!/usr/bin/python

import qpid.messaging
from os import environ
from textwrap import dedent

class ErrataListener:

    def message_handler(self, msg):
        self.say("Properties: {0}. Content: {1}".format(msg.properties,
            msg.content))

    def __init__(self, routing_keys=['errata.#'], logger=None):
        self.host = 'qpid.engineering.redhat.com'
        self.url = 'amqps://' + self.host
        self.port = 5671
        self.transport = 'ssl'
        self.exchange = 'eso.topic'
        self.mechanism = 'GSSAPI'
        self.queue = 'tmp.{0}.{1}.{2}'.format(environ['USER'],
            'redhat', qpid.messaging.uuid4())
        self.routing_keys = routing_keys
        self.logger = logger

    def say(self, message):
        if self.logger: self.logger.info(message)
        else: print(message)

    def listen(self):
        self.say(self.host)
        self.say(self.receive_opts())

        self.say("Connecting...")
        conn = qpid.messaging.Connection.establish(url=self.url,
            port=self.port, sasl_mechanisms=self.mechanism,
            transport=self.transport)
        session = conn.session()
        receiver = session.receiver(self.receive_opts())

        self.say("Listening...")
        try:
            while True:
                msg = receiver.fetch()
                self.message_handler(msg)
                session.acknowledge(msg)

        except KeyboardInterrupt:
            pass

        self.say("\nDisconnecting...")
        receiver.close()
        session.close()
        conn.close()

    def receive_opts(self):
        bindings = ["{{ exchange: '{0}', key: '{1}' }}".format(self.exchange,
            routing_key) for routing_key in self.routing_keys]
        return dedent("""\
            {queue}; {{
                create: receiver,
                node: {{
                    type: queue,
                    durable: False,
                    x-declare: {{
                        exclusive: True,
                        auto-delete: True,
                        arguments: {{ 'qpid.policy_type': ring }}}},
                    x-bindings: [ {bindings} ] }}}}\
        """).format(queue=self.queue, bindings=', '.join(bindings))
