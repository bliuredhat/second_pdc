FROM errata_devbase:latest

USER '1000'
ADD ansible/ /tmp/ansible/
RUN cd /tmp/ansible/ && \
    PYTHONUNBUFFERED=1 ansible-playbook -c local dev-env.yml \
        --skip-tags='errata-init'

WORKDIR /code
CMD bash
