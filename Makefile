OUTPUTS :=
DEPTS :=


DEPTS += package/core/graylog/GeoLite2-City.mmdb
package/core/graylog/GeoLite2-City.mmdb: 
	curl -sSL "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz" \
	| tar --extract --gzip \
		--directory="$(dir $@)" \
		--strip-components=1 \
		--exclude=*.txt


AWS_PLUGIN_VERSION = 2.4.5
DEPTS += package/core/graylog/plugin/graylog-plugin-aws-$(AWS_PLUGIN_VERSION).jar
package/core/graylog/plugin/graylog-plugin-aws-$(AWS_PLUGIN_VERSION).jar:
	curl -sSL "https://github.com/Graylog2/graylog-plugin-aws/releases/download/$(AWS_PLUGIN_VERSION)/$(notdir $@)" \
	-o "$@"


SSO_PLUGIN_VERSION = 2.4.2
DEPTS += package/core/graylog/plugin/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar
package/core/graylog/plugin/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar:
	curl -sSL "https://github.com/Graylog2/graylog-plugin-auth-sso/releases/download/$(SSO_PLUGIN_VERSION)/graylog-plugin-auth-sso-$(SSO_PLUGIN_VERSION).jar" \
	-o "$@"

EXPORTER_PLUGIN_VERSION = 2.4.0-beta.3
DEPTS += package/core/graylog/plugin/metrics-reporter-prometheus-$(EXPORTER_PLUGIN_VERSION).jar
package/core/graylog/plugin/metrics-reporter-prometheus-$(EXPORTER_PLUGIN_VERSION).jar:
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
