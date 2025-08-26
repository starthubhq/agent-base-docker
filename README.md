docker run --rm -it \
  -p 6080:6080 \
  -p 5900:5900 \
  ghcr.io/starthubhq/agent-base-docker:0.0.1

http://localhost:6080/vnc.html?host=localhost&port=6080