### Respect variant push target settings for docker

Previously, Errata Tool ignored the variant push target settings for docker
targets (cdn_docker and cdn_docker_stage), and used only the product and
product version push target settings.

This has been changed. Errata Tool now respects the variant push target
settings for docker targets. For product versions that were configured to
support docker targets, the variant push target settings for docker will
match those for CDN or CDN Stage.
