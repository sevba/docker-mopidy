FROM archlinux:latest

##  Copy fallback configuration.
COPY mopidy.conf /etc/default/mopidy.conf

#  Copy default configuration.
RUN mkdir /etc/mopidy
COPY mopidy.conf /etc/mopidy/mopidy.conf

# Update package db
RUN pacman -Sy

######################################
########### AUR manager setup ###########
RUN pacman -S --needed --noconfirm sudo

# makepkg user and workdir
ARG user=mopidy
RUN useradd -m $user \
 && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
USER $user
WORKDIR /home/$user

# Install yay
RUN sudo pacman -Syu --needed --noconfirm base-devel git \
 && git clone https://aur.archlinux.org/yay.git \
 && cd yay \
 && makepkg -sri --needed --noconfirm \
 && cd \
 && rm -rf .cache yay \
 && sudo pacman -Scc

######################################
########### Mopidy setup ###########
# Instal mopidy
RUN sudo pacman -S --noconfirm mopidy

# Install extensions
# TODO: maybe needs pip?
RUN sudo pacman -S --noconfirm which python-pipenv

COPY Pipfile Pipfile.lock /
RUN set -ex \
 && pipenv install --system --deploy

## Copy the pulse-client configuratrion.
#COPY pulse-client.conf /etc/pulse/client.conf

EXPOSE 6600 6680 5555/udp

######################################
########### Snapcast setup ###########

RUN yay -S --noconfirm snapcast \
 && sudo pacman -Scc
## Expose TCP port used to stream audio data to snapclient instances
EXPOSE 1704

#######################################
############ Supervisor setup #########

# install supervisor
RUN sudo pacman -S --noconfirm supervisor
# copy configuration
COPY supervisord.conf /etc/supervisord.conf

CMD ["/usr/bin/supervisord"]

HEALTHCHECK --interval=5s --timeout=2s --retries=20 \
    CMD curl --connect-timeout 5 --silent --show-error --fail http://localhost:6680/ || exit 1
