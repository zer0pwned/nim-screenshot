mode = ScriptMode.Verbose

when defined(macosx):
  switch("passL", "-framework CoreGraphics -framework CoreFoundation")
