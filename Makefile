RIAK_TAG		= $(shell hg identify -t)

.PHONY: rel stagedevrel deps

all: deps compile

compile:
	./rebar compile
	make -C apps/qilr/java_src
	make -C apps/raptor/java_src
deps:
	./rebar get-deps

clean:
	./rebar clean
	make -C apps/qilr/java_src clean
	make -C apps/raptor/java_src clean

distclean: clean devclean relclean ballclean
	./rebar delete-deps

test:
	./rebar skip_deps=true eunit

##
## Release targets
##
rel: deps
	make -C apps/qilr/java_src
	make -C apps/raptor/java_src
	./rebar compile generate

rellink:
	$(foreach app,$(wildcard apps/*), rm -rf rel/riaksearch/lib/$(shell basename $(app))* && ln -sf $(abspath $(app)) rel/riaksearch/lib;)
	$(foreach dep,$(wildcard deps/*), rm -rf rel/riaksearch/lib/$(shell basename $(dep))* && ln -sf $(abspath $(dep)) rel/riaksearch/lib;)

relclean:
	rm -rf rel/riak

##
## Developer targets
##
stagedevrel: dev1 dev2 dev3
	$(foreach dev,$^,\
	  $(foreach app,$(wildcard apps/*), rm -rf dev/$(dev)/lib/$(shell basename $(app))-* && ln -sf $(abspath $(app)) dev/$(dev)/lib;)\
	  $(foreach dep,$(wildcard deps/*), rm -rf dev/$(dev)/lib/$(shell basename $(dep))-* && ln -sf $(abspath $(dep)) dev/$(dev)/lib;))

devrel: dev1 dev2 dev3

dev1 dev2 dev3:
	mkdir -p dev
	(cd rel && ../rebar generate target_dir=../dev/$@ overlay_vars=vars/$@_vars.config)

devclean: clean
	rm -rf dev

stage : rel
	$(foreach app,$(wildcard apps/*), rm -rf rel/riak/lib/$(shell basename $(app))-* && ln -sf $(abspath $(app)) rel/riak/lib;)
	$(foreach dep,$(wildcard deps/*), rm -rf rel/riak/lib/$(shell basename $(dep))-* && ln -sf $(abspath $(dep)) rel/riak/lib;)


##
## Doc targets
##
docs:
	./rebar skip_deps=true doc
	@cp -R apps/luke/doc doc/luke
	@cp -R apps/riak_core/doc doc/riak_core
	@cp -R apps/riak_kv/doc doc/riak_kv

orgs: orgs-doc orgs-README

orgs-doc:
	@emacs -l orgbatch.el -batch --eval="(riak-export-doc-dir \"doc\" 'html)"

orgs-README:
	@emacs -l orgbatch.el -batch --eval="(riak-export-doc-file \"README.org\" 'ascii)"
	@mv README.txt README

dialyzer: compile
	@dialyzer -Wno_return -c apps/riak/ebin

# Release tarball creation
# Generates a tarball that includes all the deps sources so no checkouts are necessary

distdir:
	$(if $(findstring tip,$(RIAK_TAG)),$(error "You can't generate a release tarball from tip"))
	mkdir distdir
	hg clone -u $(RIAK_TAG) . distdir/riak-clone
	cd distdir/riak-clone; \
	hg archive ../$(RIAK_TAG); \
	mkdir ../$(RIAK_TAG)/deps; \
	make deps; \
	for dep in deps/*; do cd $${dep} && hg archive ../../../$(RIAK_TAG)/$${dep}; cd ../..; done

dist $(RIAK_TAG).tar.gz: distdir
	cd distdir; \
	tar czf ../$(RIAK_TAG).tar.gz $(RIAK_TAG)

ballclean:
	rm -rf $(RIAK_TAG).tar.gz distdir
