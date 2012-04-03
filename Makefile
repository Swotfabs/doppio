SOURCES = $(wildcard test/*.java)
DISASMS = $(SOURCES:.java=.disasm)
RUNOUTS = $(SOURCES:.java=.runout)
CLASSES = $(SOURCES:.java=.class)
RESULTS = $(SOURCES:.java=.result)
DEMO_SRCS = $(wildcard test/special/*.java)
DEMO_CLASSES = $(DEMO_SRCS:.java=.class)
# the order here is important: must match the order of includes
#   in the browser frontend html.
BROWSER_SRCS = third_party/underscore-min.js \
	third_party/gLong.js \
	browser/util.coffee \
	browser/node.coffee \
	src/util.coffee \
	src/types.coffee \
	src/opcodes.coffee \
	src/attributes.coffee \
	src/constant_pool.coffee \
	src/disassembler.coffee \
	src/methods.coffee \
	src/class_file.coffee \
	src/runtime.coffee \
	src/jvm.coffee \
	third_party/jquery.console.js \
	browser/untar.coffee \
	browser/frontend.coffee

# they don't survive uglifyjs and are already minified, so include them
# separately. also, this allows us to put them at the end of the document to
# reduce load time.
ACE_SRCS = third_party/ace/build/src/ace.js \
	third_party/ace/build/src/mode-java.js

test: $(RESULTS)
	cat $(RESULTS)
	@rm -f $(RESULTS)

java: $(CLASSES) $(DISASMS) $(RUNOUTS)

test/%.result: test/%.class test/%.disasm test/%.runout
	tools/run_one_test.rb test/$* >test/$*.result

test/%.disasm: test/%.class
	javap -c -verbose -private test/$* >test/$*.disasm

test/%.class: test/%.java
	javac test/$*.java

# some tests may throw exceptions. The '-' flag tells make to carry on anyway.
test/%.runout: test/%.class
	-java test/$* &>test/$*.runout

clean:
	@rm -f *.class $(DISASMS) $(RUNOUTS) $(RESULTS)
	@rm -rf build/* browser/mini-rt.jar $(DEMO_CLASSES)

release: build/index.html build/compressed.js browser/mini-rt.tar build/ace.js $(DEMO_CLASSES)
	git submodule update --init --recursive
	mkdir -p build/browser
	rsync third_party/bootstrap/css/bootstrap.min.css build/bootstrap.min.css
	rsync -a test/special build/test/
	rsync -a browser/mini-rt.tar build/browser/mini-rt.tar

test/special/%.class: test/special/%.java
	javac build/test/special/*.java

build/index.html: browser/doppio.html
	cpp -P -DRELEASE browser/doppio.html build/index.html

build/compressed.js: $(BROWSER_SRCS)
	for src in $(BROWSER_SRCS); do \
		if [ "$${src##*.}" == "coffee" ]; then \
			cat $${src} | gsed -r "s/^ *(debug|trace).*$$//" | coffee --stdio --print; \
		else \
			cat $${src}; \
		fi; \
		echo ";"; \
	done | uglifyjs --define RELEASE --no-mangle --unsafe > build/compressed.js

build/ace.js: $(ACE_SRCS)
	cat $(ACE_SRCS) > build/ace.js

browser/mini-rt.tar: tools/preload
	tools/make-rt.sh

.SECONDARY: $(CLASSES) $(DISASMS) $(RUNOUTS) $(DEMO_CLASSES)