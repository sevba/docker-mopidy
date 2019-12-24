FROM debian:buster-slim

RUN apt-get update

######################################
########### Supervisor setup #########
RUN apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor

######################################
########### Mopidy setup #############

RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        dumb-init \
        gcc \
        gnupg \
        gstreamer1.0-alsa \
        gstreamer1.0-plugins-bad \
        python-crypto \
 && curl -L https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && curl -L https://apt.mopidy.com/mopidy.list -o /etc/apt/sources.list.d/mopidy.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mopidy \
        mopidy-soundcloud \
        mopidy-spotify \
 && curl -L https://bootstrap.pypa.io/get-pip.py | python - \
 && pip install -U six pyasn1 requests[security] cryptography \
 && pip install \
        Mopidy-Iris \
        Mopidy-Moped \
        Mopidy-GMusic \
        Mopidy-Pandora \
        Mopidy-YouTube \
        pyopenssl \
        youtube-dl \
 && mkdir -p /var/lib/mopidy/.config \
 && ln -s /config /var/lib/mopidy/.config/mopidy \
    # Clean-up
 && apt-get purge --auto-remove -y \
        curl \
        gcc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

 # Start helper script.
COPY entrypoint.sh /entrypoint.sh

# Default configuration.
COPY mopidy.conf /config/mopidy.conf

# Copy the pulse-client configuratrion.
COPY pulse-client.conf /etc/pulse/client.conf

# TODO: supervisor
#COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
#COPY my_first_process my_first_process
#COPY my_second_process my_second_process

# Allows any user to run mopidy, but runs by default as a randomly generated UID/GID.
ENV HOME=/var/lib/mopidy
RUN set -ex \
 && usermod -G audio,sudo mopidy \
 && chown mopidy:audio -R $HOME /entrypoint.sh \
 && chmod go+rwx -R $HOME /entrypoint.sh

######################################
########### Snapcast setup ###########
# Taken from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
ARG SNAPCASTVERSION=0.11.1

RUN apt-get update && apt-get install wget -y
RUN wget 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION'_amd64.deb'

RUN dpkg -i --force-all 'snapserver_'$SNAPCASTVERSION'_amd64.deb'
RUN apt-get -f install -y

RUN mkdir -p /root/.config/snapcast/

EXPOSE 1704


# Runs as mopidy user by default.
USER mopidy

VOLUME ["/var/lib/mopidy/local", "/var/lib/mopidy/media"]

EXPOSE 6600 6680 5555/udp

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]
COPY launch.sh launch.sh
CMD ["./launch.sh"]

# TODO: use supervisord to manage both mopidy as well as snapcast server
# CMD ["/usr/bin/supervisord"]