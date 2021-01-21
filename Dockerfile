FROM python:3.7-slim-buster

# update pkg registry
RUN set -ex \
 && apt-get update \
 && apt-get install -y \
     gnupg \
     curl \
     apt-utils \
 && curl -L https://apt.mopidy.com/mopidy.gpg | apt-key add - \
 && curl -L https://apt.mopidy.com/mopidy.list -o /etc/apt/sources.list.d/mopidy.list \
 && apt-get update

######################################
########### Mopidy setup #############

# add things to PATH
ENV PATH="/root/.local/bin:${PATH}"
ENV PATH="/var/lib/mopidy/.local/bin:${PATH}"
RUN set -ex \
    # Official Mopidy install for Debian/Ubuntu along with some extensions
    # (see https://docs.mopidy.com/en/latest/installation/debian/ )
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        pkg-config \
        sudo \
        dumb-init \
        gcc \
        gnupg \
        python3-gi \
        python3-gi-cairo \
        gir1.2-gtk-3.0 \
        python3-gst-1.0 \
        gstreamer1.0-alsa \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-python3-plugin-loader \
        python-crypto \
        libavahi-common3 \
        libavahi-client3 \
        python3-setuptools \
        python3-crypto \
        python3-distutils \
 && curl -L https://bootstrap.pypa.io/get-pip.py | python3 - \
 && pip install pipenv \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mopidy \
        mopidy-soundcloud \
        mopidy-spotify

# NOTE: Spotify and Soundcloud extensions don't install correctly
#       when using the pip installation method..


RUN set -ex \
 && echo "mopidy ALL = (ALL)  NOPASSWD: /var/lib/mopidy/.local/lib/python3.7/site-packages/mopidy_iris/system.sh" >> /etc/sudoers \
 #&& echo "mopidy ALL=NOPASSWD: /usr/local/lib/python3.7/dist-packages/mopidy_iris/system.sh" >> /etc/sudoers \
 && mkdir -p /var/lib/mopidy/.config \
 && ln -s /config /var/lib/mopidy/.config/mopidy

RUN set -ex \
 && apt-get install -y \
    libcairo2-dev \
    libjpeg-dev \
    libgif-dev \
    libffi-dev \
    libgirepository1.0-dev \
    libpango1.0-dev \
    libglib2.0-dev \
    pkg-config \
    gcc \
    python3-dev \
    libgirepository1.0-dev
 #&& apt-get autoremove -y \
 #   libffi-dev \
 #   libgirepository1.0-dev \
 #   libpango1.0-dev \
 #   libglib2.0-dev \
 #   libjpeg-dev \
 #   libgif-dev

COPY Pipfile Pipfile.lock /

RUN set -ex \
 && pipenv install --system --deploy

# Start helper script.
COPY entrypoint.sh /entrypoint.sh

# Default configuration.
COPY mopidy.conf /config/mopidy.conf

# Copy the pulse-client configuratrion.
COPY pulse-client.conf /etc/pulse/client.conf

# Allows any user to run mopidy, but runs by default as a randomly generated UID/GID.
ENV HOME=/var/lib/mopidy
RUN set -ex \
 && usermod -G audio,sudo mopidy \
 && chown mopidy:audio -R $HOME /entrypoint.sh \
 && chmod go+rwx -R $HOME /entrypoint.sh

# Switch to mopidy user for installing extensions
USER mopidy

RUN set -ex \
 && pip install \
      pip \
      six \
      pyasn1 \
      requests[security] \
      cryptography \
      pyopenssl \
      gobject \
      PyGObject

# Basic check,
RUN /usr/bin/dumb-init /entrypoint.sh /usr/bin/mopidy --version

# Switch back to root for installation
USER root

# Expose MDP and Web ports
EXPOSE 6600 6680 5555/udp

######################################
########### Snapcast setup ###########
# Taken and adapted from: https://github.com/nolte/docker-snapcast/blob/master/DockerfileServerX86
ARG SNAPCASTVERSION=0.23.0
ARG SNAPCASTDEP_SUFFIX=-1

# Download snapcast package
RUN curl -LO 'https://github.com/badaix/snapcast/releases/download/v'$SNAPCASTVERSION'/snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb'

# Install snapcast package
RUN dpkg -i --force-all 'snapserver_'$SNAPCASTVERSION$SNAPCASTDEP_SUFFIX'_amd64.deb'
RUN apt-get -f install -y

# Create config directory
RUN mkdir -p /root/.config/snapcast/

# Expose TCP port used to stream audio data to snapclient instances
EXPOSE 1704

######################################
########### Supervisor setup #########

# https://docs.docker.com/config/containers/multi-service_container/

RUN apt-get install -y supervisor \
&& mkdir -p /var/log/supervisor

# Clean-up
RUN apt-get purge --auto-remove -y curl gcc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache

# Run as mopidy user by default.
USER mopidy

# Create volumes for
#   - local: Metadata stored by Mopidy
#   - media: Local media files
# These should be mounted from outside
#VOLUME ["/var/lib/mopidy/local", "/var/lib/mopidy/media"]

# dont know yet what this does
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint.sh"]

# Copy launch script (will later be replaced with supervisord)
COPY launch.sh launch.sh
CMD ["./launch.sh"]

# TODO: use supervisord to manage both mopidy as well as snapcast server
# CMD ["/usr/bin/supervisord"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
