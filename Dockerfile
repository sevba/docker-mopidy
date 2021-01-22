FROM debian:buster-slim

######################################
########### Mopidy setup ###########

COPY Pipfile Pipfile.lock /

RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        gnupg \
        python3-distutils \
 && curl -L https://bootstrap.pypa.io/get-pip.py | python3 - \
 && pip install pip pipenv \
 && curl -L https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && curl -L https://apt.mopidy.com/mopidy.list -o /etc/apt/sources.list.d/mopidy.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mopidy \
        mopidy-soundcloud \
        mopidy-spotify \
 && pipenv install --system --deploy \
 && apt-get purge --auto-remove -y \
        gcc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

##  Copy fallback configuration.
COPY mopidy.conf /etc/default/mopidy.conf

#  Copy default configuration.
COPY mopidy.conf /etc/mopidy/mopidy.conf

## Copy the pulse-client configuratrion.
#COPY pulse-client.conf /etc/pulse/client.conf

EXPOSE 6600 6680 5555/udp

######################################
########### Snapcast setup ###########
# https://docs.docker.com/config/containers/multi-service_container/

# Taken and adapted from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
ARG SNAPCASTVERSION=0.23.0
ARG SNAPCASTDEP_SUFFIX=-1

# Download snapcast package
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libavahi-client3 \
        libavahi-common3 \
        libsoxr0 \
 && curl -LO 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb' \
 && dpkg -i --force-all 'snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb' \
 && apt -f install -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# Create config directory
RUN mkdir -p /root/.config/snapcast/

## Expose TCP port used to stream audio data to snapclient instances
EXPOSE 1704

#######################################
############ Supervisor setup #########

# https://docs.docker.com/config/containers/multi-service_container/

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor \
 && mkdir -p /var/log/supervisor \
 && apt clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# copy configuration
COPY supervisord.conf /etc/supervisord.conf

#
## makepkg user and workdir
#ARG user=mopidy
#RUN useradd -m $user \
# && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
#USER $user
#WORKDIR /home/$user
#

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
