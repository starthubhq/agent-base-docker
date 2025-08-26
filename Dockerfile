FROM mcr.microsoft.com/playwright:v1.43.1-jammy

# Set environment variables
ENV DISPLAY=:1 \
    VNC_RESOLUTION=1280x800 \
    VNC_COL_DEPTH=24 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
  apt-get install -y gnupg && \
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 && \
  apt-get update

# Install system dependencies
RUN apt-get update && apt-get install -y \
    x11vnc \
    xvfb \
    fluxbox \
    x11-utils \
    net-tools \
    wget \
    unzip \
    python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install noVNC and Websockify
RUN mkdir -p /opt/novnc /opt/websockify && \
    wget -q -O /tmp/novnc.zip https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-1.4.0/* /opt/novnc/ && \
    wget -q -O /tmp/websockify.zip https://github.com/novnc/websockify/archive/refs/tags/v0.10.0.zip && \
    unzip /tmp/websockify.zip -d /tmp && \
    mv /tmp/websockify-0.10.0/* /opt/websockify/ && \
    mkdir -p /opt/novnc/utils && \
    ln -s /opt/websockify /opt/novnc/utils/websockify && \
    rm -rf /tmp/*

# Prepare VNC password
RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd secret /root/.vnc/passwd

# Create working directory
WORKDIR /app

# Install Playwright browsers
RUN npx playwright install chromium

# Copy app source
COPY . .

# Expose VNC and WebSocket ports
EXPOSE 5900 6080

# Start everything
CMD bash -c "\
  Xvfb :1 -screen 0 ${VNC_RESOLUTION}x${VNC_COL_DEPTH} & \
  until xdpyinfo -display :1 > /dev/null 2>&1; do echo 'Waiting for Xvfb...'; sleep 0.5; done && \
  fluxbox & \
  x11vnc -rfbport 5900 -display :1 -forever -shared -nopw -listen 0.0.0.0 & \
  /opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080"
