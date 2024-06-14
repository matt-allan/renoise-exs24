XRNX := com.matta.exs24.xrnx
SOURCES := $(wildcard *.lua) 
TESTS := $(wildcard *_test.lua)

$(XRNX): $(SOURCES) LICENSE.md manifest.xml
	zip -vr $@ $^

.PHONY: clean
clean:
	rm $(XRNX)