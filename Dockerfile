FROM archlinux:latest

##  Copy fallback configuration.
COPY mopidy.conf /etc/default/mopidy.conf

#  Copy default configuration.
RUN mkdir /etc/mopidy
COPY mopidy.conf /etc/mopidy/mopidy.conf

# Copy helper script.
COPY entrypoint.sh /entrypoint.sh

# Update package db
RUN pacman -Sy

# Install AUR manager
#RUN pacman -S --noconfirm git \
# && git clone https://aur.archlinux.org/yay-git.git \
# && cd yay-git \
# && makepkg -si \
# && cd .. \
# && rm -rf yay-git

# Instal mopidy
RUN pacman -S --noconfirm mopidy

# Install extensions
# TODO: maybe needs pip?
RUN pacman -S --noconfirm which python-pipenv

COPY Pipfile Pipfile.lock /
RUN set -ex \
 && pipenv install --system --deploy

# Copy the pulse-client configuratrion.
COPY pulse-client.conf /etc/pulse/client.conf

# I cant explain why, but to me it seems
# I have less pause in streams if I
# also install these. However image size
# also grows by about 80MB
#RUN apk add --no-cache \
#  gst-plugins-base0.10 \
#  gst-plugins-good0.10 \
#  gst-plugins-ugly0.10 \
#  py-gst0.10

#VOLUME ["/etc/mopidy", "/var/lib/mopidy"]

EXPOSE 6600 6680 5555/udp

ENTRYPOINT ["/entrypoint.sh"]

######################################
########### Snapcast setup ###########
# Taken and adapted from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
#ARG SNAPCASTVERSION=0.23.0
#ARG SNAPCASTDEP_SUFFIX=-1
#
## Download snapcast package
#RUN curl -LO 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb'
#
## Install snapcast package
#RUN dpkg -i --force-all 'snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb'
#RUN apt-get -f install -y
#
## Create config directory
#RUN mkdir -p /root/.config/snapcast/
#
## Expose TCP port used to stream audio data to snapclient instances
#EXPOSE 1704

#######################################
############ Supervisor setup #########
#
## https://docs.docker.com/config/containers/multi-service_container/
#
#RUN apt-get install -y supervisor \
# && mkdir -p /var/log/supervisor \
# && apt-get purge --auto-remove -y curl gcc \
# && apt-get clean \
# && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache
#
## Run as mopidy user by default.
##USER mopidy
#
## Copy launch script (will later be replaced with supervisord)
#COPY launch.sh launch.sh
#CMD ["./launch.sh"]
#
## TODO: use supervisord to manage both mopidy as well as snapcast server
## CMD ["/usr/bin/supervisord"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
