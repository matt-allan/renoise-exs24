XRNX := com.matta.exs24.xrnx
SOURCES := $(wildcard *.lua) 
TESTS := $(wildcard *_test.lua)

$(XRNX): $(SOURCES) LICENSE.md manifest.xml
	zip -vr $@ $^

.PHONY: clean
clean:
	rm $(XRNX)

# This probably only works on my machine
.PHONY: dev-install
dev-install: $(XRNX)
	mkdir -p ${HOME}/Library/Preferences/Renoise/V3.4.4/Scripts/Tools/$(XRNX)
	unzip -o $(XRNX) -d ${HOME}/Library/Preferences/Renoise/V3.4.4/Scripts/Tools/$(XRNX)
