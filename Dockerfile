# Built with arch: amd64 flavor: lxde image: ubuntu:20.04
#
################################################################################
# base system
################################################################################

FROM ubuntu:20.04 as system

RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list;


# built-in packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt update \
    && apt install -y --no-install-recommends software-properties-common curl apache2-utils git \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        supervisor nginx sudo net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri zip unzip\
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# install debs error if combine together
RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        xvfb x11vnc \
        vim-tiny firefox ttf-ubuntu-font-family ttf-wqy-zenhei  \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN apt update \
    && apt install -y gpg-agent \
    && curl -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && (dpkg -i ./google-chrome-stable_current_amd64.deb || apt-get install -fy) \
    && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add \
    && rm google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# add firefox
RUN apt-get update && apt-get install -y firefox \
    && rm -rf /var/lib/apt/lists/*

RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# add Sublime
RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        dirmngr gnupg apt-transport-https ca-certificates software-properties-common \
    && curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add - \
    && add-apt-repository "deb https://download.sublimetext.com/ apt/stable/" \
    && apt install sublime-text \
    #&& rm sublimehq-pub.gpg \ # can't find the files somehow.
    && rm -rf /var/lib/apt/lists/*

# Additional packages require ~600MB
# libreoffice  pinta language-pack-zh-hant language-pack-gnome-zh-hant firefox-locale-zh-hant libreoffice-l10n-zh-tw

# tini to fix subreap
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
RUN chmod +x /bin/tini

# python library
COPY rootfs/usr/local/lib/web/backend/requirements.txt /tmp/
RUN apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python3-pip python3-dev build-essential \
    #&& apt-get install pip \
	&& pip3 install setuptools wheel && pip3 install -r /tmp/requirements.txt \
    && ln -s /usr/bin/python3 /usr/local/bin/python \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt


################################################################################
# builder
################################################################################
FROM ubuntu:20.04 as builder


RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list;


RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg patch

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install -y nodejs

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# build frontend
COPY web /src/web
RUN cd /src/web \
    && yarn \
    && yarn build
RUN sed -i 's#app/locale/#novnc/app/locale/#' /src/web/dist/static/novnc/app/ui.js

# install JRE
RUN apt update \
    && apt install -y default-jre

################################################################################
# merge
################################################################################
FROM system
LABEL maintainer="andy.tu@immunai.com"

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/
COPY rootfs /
RUN ln -sf /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify && \
	chmod +x /usr/local/lib/web/frontend/static/websockify/run

##### Add QuPath ######
RUN mkdir -p /home/ubuntu/Applications
ADD https://github.com/qupath/qupath/releases/download/v0.4.3/QuPath-0.4.3-Linux.tar.xz /home/ubuntu/Applications/
RUN cd /home/ubuntu/Applications && tar -xf QuPath-0.4.3-Linux.tar.xz

# add stardist extension
RUN mkdir -p /root/QuPath/v0.4/extensions
ADD https://github.com/qupath/qupath-extension-stardist/releases/download/v0.4.0/qupath-extension-stardist-0.4.0.jar /root/QuPath/v0.4/extensions/
##### End QuPath application #####

##### Add FIJI #####
ADD https://downloads.imagej.net/fiji/latest/fiji-linux64.zip /home/ubuntu/Applications/
RUN cd /home/ubuntu/Applications/ && unzip fiji-linux64.zip

WORKDIR /root

# Make QuPath desktop launcher
RUN mkdir -p ~/.local/share/applications
RUN mkdir -p ~/.config/autostart
RUN mkdir -p ~/Desktop
RUN chmod a+x /home/ubuntu/Applications/QuPath/bin/QuPath
RUN echo "[Desktop Entry]\n\
Type=Application\n\
Path=/home/ubuntu\n\
Exec=/home/ubuntu/Applications/QuPath/bin/QuPath\n\
Icon=/home/ubuntu/Applications/QuPath/lib/QuPath.png" >> ~/.local/share/applications/QuPath.desktop
RUN cp ~/.local/share/applications/QuPath.desktop ~/.config/autostart/.
RUN cp ~/.local/share/applications/QuPath.desktop ~/Desktop/.
RUN chmod a+x ~/Desktop/QuPath.desktop
# RUN chmod a+x ~/.config/autostart/QuPath.desktop

# Make FIJI desktop launcher
RUN chmod a+x /home/ubuntu/Applications/Fiji.app
RUN /home/ubuntu/Applications/Fiji.app/ImageJ-linux64
RUN cp /home/ubuntu/Applications/Fiji.app/ImageJ2.desktop ~/Desktop/.
# running the file will get the executable to automatically run and make a desktop launcher
# this gave some non-ciritical error messages and warning, but it's nothing that would stop the building. we'll go with 
# it for now.

##### Add Miniconda #####

ENV PATH="${PATH}:/root/miniconda3/bin"
ARG PATH="${PATH}:/root/miniconda3/bin"

RUN mkdir -p ~/miniconda3 \
    && wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh \
    && bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3 \
    && rm -rf ~/miniconda3/miniconda.sh \
    # && ~/miniconda3/bin/conda init bash \
    # && ~/miniconda3/bin/conda init zsh \
    # && echo "conda init" >> ~/.bashrc \
    # && echo "conda init" >> ~/.zshrc \
    # && /bin/bash -c "source ~/.bashrc" \
    && conda install mamba -n base -c conda-forge 

##### Add Mamba #####
#RUN echo "conda activate base" >> ~/.bashrc \
#    && echo "conda activate base" >> ~/.zshrc \
#    && /bin/bash -c "source ~/.bashrc" && conda install mamba -n base -c conda-forge

##### Add Napari #####
RUN conda create -y -n napari-env -c conda-forge python=3.9 \
    && mamba install -y -n napari-env -c conda-forge napari

EXPOSE 80
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash \
    RESOLUTION=2560x1440
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:6080/api/health

ENTRYPOINT ["/startup.sh"]
