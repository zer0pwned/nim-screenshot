nim-screenshot 
==============

[![](https://img.shields.io/github/license/zer0pwned/nim-screenshot)](https://github.com/zer0pwned/nim-screenshot/blob/main/LICENSE)

* Nim library to capture desktop screen.
* Support Windows, Mac for now. PRs welcome for other platforms.
* Support multiple monitors.
* Heavily inspired by [go-screenshot](https://github.com/kbinani/screenshot).
* I generally use headless version Linux so I'm not really motivated to
  implement X11-based screenshot on Linux. There is an
  [example](https://github.com/nim-lang/x11/blob/master/examples/xshmex.nim)
  from NIM X11 package demonstrated how to make screenshot. Will consider to
  migrate it into our package in the future. 

Example 
=======

```nim
## Take screenshots for all monitors and merge into one png file
import screenshot
import streams
import nimPNG
let nDisplays = numActiveDisplays().int
var 
  height, width: int

for i in 0..<nDisplays:
  let rect = getDisplayBounds(i) 
  if (rect.max.y - rect.min.y) > height:
    height = rect.max.y - rect.min.y
  width += (rect.max.x - rect.min.x)

let buffer = capture(0, 0, width, height)
var s = newFileStream("screenshot_all.png", fmWrite)
buffer.writeChunks s
s.close()

## Take screenshot for each monitor
for i in 0..<nDisplays:
  let buffer = captureScreen(i)
  var s = newFileStream("screenshot_" & $i & ".png", fmWrite)
  buffer.writeChunks s
  s.close()
```

Notes
=====

* To use this library on Mac, you should enable two frameworks during
  compilation. For instance, pass `-framework CoreGraphics -framework
  CoreFoundation` for your clang linker. See `screenshot.nims` as reference.
* The raw RGB data we retrieved from operating system normally is reversed, so
  we have to perform byte swap when finalizing the PNG data. But this procedure
  can be slow at debug mode. My Macbook Pro generally takes 3 seconds for one
  PNG file but once you enable the release mode, it can be really fast. (On
  Windows, the debug mode is not that slow though.)
* You need allow your program to have screen recording privilege if your Mac has
  privacy control enabled. 