OUTPUTS :=
DEPTS :=


DEPTS += package/graylog/engine/GeoLite2-City.mmdb
package/graylog/engine/GeoLite2-City.mmdb: 
	curl -sSL "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz" \
	| tar --extract --gzip \
		--directory="$(dir $@)" \
		--strip-components=1 \
		--exclude=*.txt


GRAYLOG_PLUGIN_VERSION := 2.4.6
BUILTIN_PLUGINS = \
	package/graylog/engine/plugin/graylog-plugin-aws-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-beats-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-cef-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-collector-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-map-widget-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-netflow-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-pipeline-processor-$(GRAYLOG_PLUGIN_VERSION).jar \
	package/graylog/engine/plugin/graylog-plugin-threatintel-$(GRAYLOG_PLUGIN_VERSION).jar
DEPTS += $(BUILTIN_PLUGINS)
$(BUILTIN_PLUGINS):
	docker run \
		--rm \
		-v '$(shell pwd)/$(dir $@):$(shell pwd)/$(dir $@)' \
		graylog/graylog:2.4 \
		cp ./plugin/$(notdir $@) $(shell pwd)/$@


SSO_PLUGIN_VERSION = 2.4.2
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
