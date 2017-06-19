FROM errata_ruby22:latest

RUN rm -rf /home/dev/.gem /home/dev/.bash_profile /home/dev/.bundle
RUN echo "export PATH=\$HOME/bin:\$PATH" > ~/.bash_profile

ADD run-test /run-test

ENTRYPOINT ["/run-test"]
CMD ["main"]
