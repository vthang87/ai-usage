.PHONY: project open test install dmg

project:
	xcodegen generate

open: project
	open AIUsage.xcodeproj

test:
	swiftc -o /tmp/ai-usage-parser-tests -parse-as-library \
		Shared/*.swift \
		Scripts/ParserTestRunner.swift
	/tmp/ai-usage-parser-tests

install:
	./install.sh

dmg:
	./dmg.sh
