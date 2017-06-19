FROM docker-registry.usersys.redhat.com/errata_tool/rhel7:latest

RUN yum -y install \
    gcc \
    git \
    perl-App-cpanminus \
    perl-Archive-Tar \
    perl-Test-Simple \
    perl-Time-Piece \
    ruby \
    && yum clean all

#
# Install additional dependencies for the review-bot
#
RUN cpanm -v --notest \
  AnyEvent \
  Data::Alias \
  Gerrit::Client \
  Lingua::EN::CommonMistakes

#
# Deploy the bot under it's own user
#
RUN useradd -m review-bot

WORKDIR /home/review-bot
USER review-bot
ENV HOME /home/review-bot

RUN mkdir -p /home/review-bot/bin
RUN mkdir -p /home/review-bot/.ssh
RUN ["/bin/sh", "-c", "echo 'code.engineering.redhat.com,10.16.101.101 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA1famCORFkEX0L0uZsgfORdwJEP0y3JppUFvgOdLGnjll3vX+Dy8KPTknZGL/Q+hcaaFaIMIiSMHNa+z/285J3KpHc4AKlWtsTEpS7qJXem9Ddmuk0tml+Z2qYgbxJOpkaKeDexOxGLq0qp/s3bH63vu+NPXOZImN0pRrQXT/C3s+J0U9kwRjnQEyaV3rPx8d6OiMp8SnYjkqF4R1X1v40gHM44OFIgW/D0+hmxUuhS3qgn8TVecP6YdxxOYnoJm8994BpPNGh1cYg3cjvqtLKs1I9j5fEgUbunMdDhJA3OpqFpEeEVj9TfVu9Ur3zS1ytBjxhmKYew+tBxkxm5p8+w==' >> /home/review-bot/.ssh/known_hosts"]
RUN git config --global user.name review-bot
RUN git config --global user.email nobody@redhat.com
ADD startReviewBot.sh /home/review-bot/bin/

#
# Finally do the git checkout
#
RUN mkdir gerrit-review-bot
RUN git clone git://git.engineering.redhat.com/users/rmcgover/gerrit_bots

VOLUME ["/home/review-bot/gerrit-review-bot"]

ENTRYPOINT ["/home/review-bot/bin/startReviewBot.sh"]
