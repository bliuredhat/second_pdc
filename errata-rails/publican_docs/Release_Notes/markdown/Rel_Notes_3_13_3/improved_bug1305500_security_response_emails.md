### Remove some email notifications for security-response

Errata Tool no longer sends emails to security-response@redhat.com when a
security advisory reaches PUSH_READY state, or when a Product Security
approval request is made. The Product Security team have a dashboard
application to manage these notifications, and the redundant emails were
cluttering their RT queue.
