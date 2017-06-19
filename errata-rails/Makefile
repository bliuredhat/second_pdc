# Note:
# * $(DESTDIR), $(VER_REL) and $(RUBY_PATH) are passed in via
#   `make install` in the spec file
# * $(VERSION) is passed in via `make create-archive` in
#   deploy.rake

all: errata-rails

errata-rails:

install:
	mkdir -p $(DESTDIR)/var/www/errata_rails
	mkdir -p $(DESTDIR)/var/www/errata_rails/.bundle
	mkdir -p $(DESTDIR)/var/www/errata_rails/public/assets
	mkdir -p $(DESTDIR)/var/www/errata_rails/public/ovalcache
	mkdir -p $(DESTDIR)/var/www/errata_rails/bin
	mkdir -p $(DESTDIR)/var/www/errata_rails/log
	mkdir -p $(DESTDIR)/var/www/errata_rails/ovalcache
	mkdir -p $(DESTDIR)/var/www/errata_rails/tmp/sessions
	mkdir -p $(DESTDIR)/var/www/errata_rails/tmp/cache
	mkdir -p $(DESTDIR)/var/www/errata_rails/tmp/pids
	mkdir -p $(DESTDIR)/var/www/errata_rails/tmp/sockets
	cp Makefile $(DESTDIR)/var/www/errata_rails
	cp Rakefile $(DESTDIR)/var/www/errata_rails
	cp config.ru $(DESTDIR)/var/www/errata_rails
	cp ChangeLog $(DESTDIR)/var/www/errata_rails
	cp README $(DESTDIR)/var/www/errata_rails
	cp -R app/ $(DESTDIR)/var/www/errata_rails
	cp -R bin/ $(DESTDIR)/var/www/errata_rails
	cp -R config/ $(DESTDIR)/var/www/errata_rails
	cp -R db/ $(DESTDIR)/var/www/errata_rails
	cp -R doc/ $(DESTDIR)/var/www/errata_rails
	cp -R lib/ $(DESTDIR)/var/www/errata_rails
	cp -R public/ $(DESTDIR)/var/www/errata_rails
	cp -R script/ $(DESTDIR)/var/www/errata_rails
	cp -R test/ $(DESTDIR)/var/www/errata_rails
	cp -R vendor/ $(DESTDIR)/var/www/errata_rails
	cp -R examples/ $(DESTDIR)/var/www/errata_rails
	ln -s /var/www/errata_rails/public/images $(DESTDIR)/var/www/errata_rails/public/assets
	ln -s /var/www/errata_rails/public/javascripts $(DESTDIR)/var/www/errata_rails/public/assets
	ln -s /var/www/errata_rails/public/stylesheets $(DESTDIR)/var/www/errata_rails/public/assets
	echo $(VER_REL) > $(DESTDIR)/var/www/errata_rails/public/installed-version.txt
	cp Gemfile                 $(DESTDIR)/var/www/errata_rails
	cp Gemfile.lock            $(DESTDIR)/var/www/errata_rails
	cp .bundle/config          $(DESTDIR)/var/www/errata_rails/.bundle/
	cp errata-rails.spec       $(DESTDIR)/var/www/errata_rails
ifdef RUBY_PATH
	for f in $$(grep -ril "^#!\s*/usr/bin/ruby\|^#!\s*/usr/local/bin/ruby" \
					$(DESTDIR)/var/www/errata_rails/ ); do \
		sed -i "s|/usr.*/bin/ruby|$(RUBY_PATH)|g" $$f; \
		echo "$$f: $$(head -1 $$f)"; \
	done
endif

create-archive:
	@rm -rf /tmp/errata-rails-$(VERSION) /tmp/errata-rails-$(VERSION).tar.gz
	@mkdir /tmp/errata-rails-$(VERSION)
	@cp -R * /tmp/errata-rails-$(VERSION)
	@cd /tmp; tar czSpf errata-rails-$(VERSION).tar.gz errata-rails-$(VERSION)
	@rm -rf /tmp/errata-rails-$(VERSION)
	@cp /tmp/errata-rails-$(VERSION).tar.gz .
	@rm -f /tmp/errata-rails-$(VERSION).tar.gz
	@echo " "
	@echo "The final archive is errata-rails-$(VERSION).tar.gz"
