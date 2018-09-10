{% from "hello_web/map.jinja" import hello_web with context %}

hello_web:
  pkg.installed:
    - name: {{ hello_web.package }}
  service.running:
    - name: {{ hello_web.service }}
    - enable: True
    - reload: True
  file.managed:
    - name: {{ hello_web.docroot }}/index.html
    - source: salt://hello_web/files/index.html
