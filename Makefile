OUTPUTS :=
DEPTS :=


DEPTS += package/graylog/engine/GeoLite2-City.mmdb
package/graylog/engine/GeoLite2-City.mmdb: 
	curl -sSL "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz" \
	| tar --extract --gzip \
		--directory="$(dir $@)" \
		--strip-components=1 \
		--exclude=*.txt


GRAYLOG_PLUGIN_VERSION := 3.0.0
BUILTIN_PLUGINS = aws collector threatintel
PLUGINS_FULL_TARGETS := $(addprefix package/graylog/engine/plugin/graylog-plugin-,$(addsuffix -$(GRAYLOG_PLUGIN_VERSION).jar,$(BUILTIN_PLUGINS)))

DEPTS += $(PLUGINS_FULL_TARGETS)
$(PLUGINS_FULL_TARGETS):
	docker cp $(shell docker container run --rm --detach graylog/graylog:3.0.0 sleep 10):/usr/share/graylog/plugin/$(notdir $@) $@

SSO_PLUGIN_VERSION = 3.0.0
DEPTS += package/graylog/engine/plugin/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar
package/graylog/engine/plugin/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar:
	curl -sSL "https://github.com/Graylog2/graylog-plugin-auth-sso/releases/download/$(SSO_PLUGIN_VERSION)/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar" \
	-o "$@"

EXPORTER_PLUGIN_VERSION = 2.4.0-beta.3
DEPTS += package/graylog/engine/plugin/metrics-reporter-prometheus-$(EXPORTER_PLUGIN_VERSION).jar
package/graylog/engine/plugin/metrics-reporter-prometheus-$(EXPORTER_PLUGIN_VERSION).jar:
	curl -sSL "https://github.com/graylog-labs/graylog-plugin-metrics-reporter/releases/download/$(EXPORTER_PLUGIN_VERSION)/metrics-reporter-prometheus-$(EXPORTER_PLUGIN_VERSION).jar" \
	-o "$@"

.PHONY: package clean purge

package: installer.run
OUTPUTS += installer.run
installer.run: $(DEPTS)
	makeself \
		--tar-extra "--exclude=.gitkeep" \
		"./package/" "$(notdir $@)" "Deploy Graylog with ElasticSearch based on Docker on a CentOS 7+ machine" ./bootstrap.sh

clean:
	rm -f $(OUTPUTS)

purge:
	rm -rf $(OUTPUTS) $(DEPTS)
