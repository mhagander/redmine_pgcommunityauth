FROM debian:bookworm

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" >/etc/apt/sources.list.d/bookworm-backports.list

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y
RUN apt-get install -y redmine redmine-sqlite

ENV REDMINE_ROOT=/usr/share/redmine
RUN mkdir -p "$REDMINE_ROOT/plugins/redmine_pgcommunityauth/"
COPY ./ "$REDMINE_ROOT/plugins/redmine_pgcommunityauth/"
ADD docker-resources/Gemfile.local /usr/share/redmine/

WORKDIR "$REDMINE_ROOT"
EXPOSE 9292

USER www-data
ENV RACK_HANDLER=webrick
ENV RAILS_ENV=production

RUN "$REDMINE_ROOT/plugins/redmine_pgcommunityauth/docker-resources/prepare.sh"

CMD /usr/bin/rackup -d -E development -o 0.0.0.0
