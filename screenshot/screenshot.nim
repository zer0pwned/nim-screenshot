when defined(macosx):
  import screenshot_darwin

when defined(windows):
  import screenshot_windows

template numActiveDisplays*(): untyped =
  var number: int
  when defined(macosx):
    number = numActiveDisplaysImplDarwin().int
  elif defined(windows):
    number = numActiveDisplaysImplWindows()
  else:
    raise newException(UnimplementedException, "current platform is not supported")
  number

template capture*(x, y, width, height): untyped =
  var picture: PNG[seq[byte]]
  when defined(macosx):
    picture = captureImplDarwin(x, y, width, height)
  elif defined(windows):
    picture = captureImplWindows(x, y, width, height)
  else:
    raise newException(UnimplementedException, "current platform is not supported")
  picture

template getDisplayBounds*(displayIndex): untyped =
  var bound: rectangle
  when defined(macosx):
    bound = getDisplayBoundsImplDarwin(displayIndex)
  elif defined(windows):
    bound = getDisplayBoundsImplWindows(displayIndex)
  else:
    raise newException(UnimplementedException, "current platform is not supported")
  bound

template captureScreen*(displayIndex): untyped =
  var picture: PNG[seq[byte]]
  when defined(macosx):
    picture = captureScreenImplDarwin(displayIndex)
  elif defined(windows):
    picture = captureScreenImplWindows(displayIndex)
  else:
    raise newException(UnimplementedException, "current platform is not supported")
  picture
