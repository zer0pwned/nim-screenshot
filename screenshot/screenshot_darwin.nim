import nimPNG
import ./common

type 
  CGError = enum 
    kCGErrorSuccess = 0.int32
    kCGErrorFailure = 1000.int32
    kCGErrorIllegalArgument = 1001.int32
    kCGErrorInvalidConnection = 1002.int32
    kCGErrorInvalidContext = 1003.int32
    kCGErrorCannotComplete = 1004.int32
    kCGErrorNotImplemented = 1006.int32
    kCGErrorRangeCheck = 1007.int32
    kCGErrorTypeCheck = 1008.int32
    kCGErrorInvalidOperation = 1010.int32
    kCGErrorNoneAvailable = 1011.int32
  
  CGImageAlphaInfo = enum
    kCGImageAlphaNone = 0.int32
    kCGImageAlphaPremultipliedLast
    kCGImageAlphaPremultipliedFirst
    kCGImageAlphaLast
    kCGImageAlphaFirst
    kCGImageAlphaNoneSkipLast
    kCGImageAlphaNoneSkipFirst
    kCGImageAlphaOnly

  CGDirectDisplayID = uint32

  CGPoint {.header: "<CoreGraphics/CGGeometry.h>", importc: "CGPoint", nodecl.} = object
    x:  cfloat
    y:  cfloat

  CGSize {.header: "<CoreGraphics/CGGeometry.h>", importc: "CGSize", nodecl.} = object
    height: cfloat
    width:  cfloat

  CGRect {.header: "<CoreGraphics/CGGeometry.h>", importc: "CGRect", nodecl.} = object
    origin: CGPoint
    size:   CGSize

  CGContextRef {.header: "<CoreGraphics/CGContext.h>", importc: "CGContextRef", nodecl.} = object
  CGColorSpaceRef {.header: "<CoreGraphics/CGColorSpace.h>", importc: "CGColorSpaceRef", nodecl.} = object
  CGImageRef {.header: "<CoreGraphics/CGImage.h>", importc: "CGImageRef", nodecl.} = object

proc CGGetActiveDisplayList(a1: uint32, a2: pointer, a3: ptr uint32):CGError
                          {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}

proc CGMainDisplayID(): CGDirectDisplayID
                          {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}

proc CGDisplayBounds(a1: CGDirectDisplayID): CGRect
                          {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}

proc CGPointMake(a1, a2: cfloat): CGPoint
                          {.importc, header: "<CoreGraphics/CGGeometry.h>".}

proc CGRectMake(a1, a2, a3, a4: cfloat): CGRect
                          {.importc, header: "<CoreGraphics/CGGeometry.h>".}

proc CGBitmapContextCreate(a1: pointer, a2, a3, a4, a5: csize_t, a6: CGColorSpaceRef, a7: uint32): CGContextRef
                          {.importc, header: "<CoreGraphics/CGBitmapContext.h>".}

proc CGImageRelease(a1: CGImageRef) {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}
proc CGColorSpaceRelease(a1: CGColorSpaceRef) {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}
proc CGColorSpaceCreateDeviceRGB():CGColorSpaceRef {.importc, header: "<CoreGraphics/CGColorSpace.h>".}
proc CGRectIntersection(a1, a2: CGRect): CGRect {.importc, header: "<CoreGraphics/CGGeometry.h>".}
proc CGRectIsNull(a1: CGRect): bool {.importc, header: "<CoreGraphics/CGGeometry.h>".}
proc CGDisplayCreateImage(a1: CGDirectDisplayID): CGImageRef {.importc, header: "<CoreGraphics/CGDirectDisplay.h>".}
proc CGContextDrawImage(a1: CGContextRef, a2: CGRect, a3: CGImageRef) {.importc, header: "<CoreGraphics/CGContext.h>".}

proc numActiveDisplaysImplDarwin*(): uint32 =
  var count: uint32
  let success = CGGetActiveDisplayList(0, nil, count.addr)
  if success != kCGErrorSuccess:
    debugEcho "failed to execute CGGetActiveDisplayList, return value: " & $success
    return 0
  return count

proc getDisplayID(displayIndex: int): CGDirectDisplayID = 
  let main = CGMainDisplayID()
  if displayIndex == 0:
    return main

  let n = numActiveDisplaysImplDarwin()
  var ids = newSeq[CGDirectDisplayID](n)
  let success = CGGetActiveDisplayList(n, ids[0].unsafeAddr, nil)
  if success != kCGErrorSuccess:
    debugEcho "failed to execute CGGetActiveDisplayList, return value: " & $success
    return 0.CGDirectDisplayID

  var potential = 0
  for index, id in ids[0 .. ^1]:
    if id == main:
      continue
    potential = potential + 1
    if potential == displayIndex:
      return id

  return 0.CGDirectDisplayID

proc getCoreGraphicsCoordinateOfDisplay(id: CGDirectDisplayID): CGRect = 
  let main = CGDisplayBounds(CGMainDisplayID())
  let r = CGDisplayBounds(id)
  result.origin.x = r.origin.x
  result.origin.y = -r.origin.y - r.size.height + main.size.height
  result.size.width = r.size.width
  result.size.height = r.size.height

proc getCoreGraphicsCoordinateFromWindowsCoordinate(p: CGPoint, mainDisplayBounds: CGRect): CGPoint =
  result.x = p.x
  result.y = mainDisplayBounds.size.height - p.y

proc createColorSpace(): CGColorSpaceRef =
  result = CGColorSpaceCreateDeviceRGB()

proc createBitmapContext(width, height: int, data: pointer, bytesPerRow: int): CGContextRef =
  let colorSpace = createColorSpace()
  defer: CGColorSpaceRelease(colorSpace)

  return CGBitmapContextCreate(data, # data
                              width.csize_t,
                              height.csize_t,
                              8, 
                              bytesPerRow.csize_t, # bytesPerRow.csize_t,
                              colorSpace,
                              kCGImageAlphaNoneSkipFirst.ord)

proc activeDisplayList(): seq[CGDirectDisplayID] = 
  let count = numActiveDisplaysImplDarwin()
  result = newSeq[CGDirectDisplayID](count)
  if count > 0:
    let success = CGGetActiveDisplayList(count, result[0].unsafeAddr, nil)
    if success != kCGErrorSuccess:
      debugEcho "failed to execute CGGetActiveDisplayList, return value: " & $success
      return newSeq[CGDirectDisplayID](0)
    else:
      return result
  
  return result

proc captureImplDarwin*(x, y, width, height: int): PNG[seq[byte]] = 
  if width <= 0 or height <= 0 :
    raise newException(MacCaptureException, "width or height should be > 0")

  ## separated buffer as we are actually making the bitmap with sRGB
  var buffer = newSeq[byte](width * height * 4)
  let cgMainDisplayBounds = getCoreGraphicsCoordinateOfDisplay(CGMainDisplayID())
  let winBottomLeft = CGPointMake(x.cfloat, (y+height).cfloat)
  let cgBottomLeft = getCoreGraphicsCoordinateFromWindowsCoordinate(winBottomLeft, cgMainDisplayBounds)
  let cgCaptureBounds = CGRectMake(cgBottomLeft.x, cgBottomLeft.y, width.cfloat, height.cfloat)

  let ids = activeDisplayList()

  let colorSpace = createColorSpace()
  if isNil(cast[pointer](colorSpace)):
    raise newException(MacCaptureException, "cannot create colorspace")
  defer: CGColorSpaceRelease(colorSpace)

  let ctx = createBitmapContext(width, height, buffer[0].unsafeAddr, 4 * width)
  if isNil(cast[pointer](ctx)):
    raise newException(MacCaptureException, "cannot create bitmap context")

  for index, id in ids[0 .. ^1]:
    let cgBounds = getCoreGraphicsCoordinateOfDisplay(id)
    var cgIntersect = CGRectIntersection(cgBounds, cgCaptureBounds)
    if CGRectIsNull(cgIntersect):
      continue

    if (cgIntersect.size.width <= 0) or (cgIntersect.size.height <= 0):
      continue

    ## CGDisplayCreateImageForRect potentially fail in case width/height is odd number
    if cgIntersect.size.width.int mod 2 != 0 :
      cgIntersect.size.width = (cgIntersect.size.width.int + 1).cfloat
    if cgIntersect.size.height.int mod 2 != 0 :
      cgIntersect.size.height = (cgIntersect.size.height.int + 1).cfloat

    let captured = CGDisplayCreateImage(id)
    if isNil(cast[pointer](captured)):
      raise newException(MacCaptureException, "cannot capture display")
    defer: CGImageRelease(captured)

    let cgDrawRect = CGRectMake(cgIntersect.origin.x-cgCaptureBounds.origin.x, 
                                cgIntersect.origin.y-cgCaptureBounds.origin.y,
                                cgIntersect.size.width, 
                                cgIntersect.size.height)
    CGContextDrawImage(ctx, cgDrawRect, captured)

  let stride = 4 * width
  var i = 0
  for iy in 0..<height:
    var j = i
    for ix in 0..<width:
      buffer[j] = buffer[j+1]
      buffer[j+1] = buffer[j+2]
      buffer[j+2] = buffer[j+3]
      buffer[j+3] = 255
      j += 4
    i += stride

  result = encodePNG32(buffer, width, height)  

proc getDisplayBoundsImplDarwin*(displayIndex: int): rectangle = 
  let id = getDisplayId(displayIndex)
  if id == 0.CGDirectDisplayID:
    raise newException(MacCaptureException, "screen id not exists")
  let main = CGMainDisplayID()
  let bounds = getCoreGraphicsCoordinateOfDisplay(id)
  
  result.min.x = bounds.origin.x.int
  if main == id:
    result.min.y = 0
  else:
    let mainBounds = getCoreGraphicsCoordinateOfDisplay(main)
    let mainHeight = mainBounds.size.height
    result.min.y = (mainHeight - (bounds.origin.y + bounds.size.height)).int

  result.max.x = result.min.x + bounds.size.width.int
  result.max.y = result.min.y + bounds.size.height.int

proc captureScreenImplDarwin*(displayIndex: int): PNG[seq[byte]] =
  let id = getDisplayID(displayIndex)
  if id == 0.CGDirectDisplayID:
    raise newException(MacCaptureException, "screen id not exists")
  let bounds = getCoreGraphicsCoordinateOfDisplay(id)
  let height = bounds.size.height.int
  let width  = bounds.size.width.int
  var buffer = newSeq[byte](height * width * 4)

  let colorSpace = CGColorSpaceCreateDeviceRGB()
  if isNil(cast[pointer](colorSpace)):
    raise newException(MacCaptureException, "cannot create colorspace")
  defer: CGColorSpaceRelease(colorSpace)

  let ctx = createBitmapContext(width, height, buffer[0].unsafeAddr, 4 * width)
  if isNil(cast[pointer](ctx)):
    raise newException(MacCaptureException, "cannot create bitmap context")

  let captured = CGDisplayCreateImage(id)
  if isNil(cast[pointer](captured)):
    raise newException(MacCaptureException, "cannot capture display")
  defer: CGImageRelease(captured)

  let cgDrawRect = CGRectMake(0.cfloat, 0.cfloat, width.cfloat, height.cfloat)
  CGContextDrawImage(ctx, cgDrawRect, captured)
  let stride = 4 * width
  var i = 0
  for iy in 0..<height:
    var j = i
    for ix in 0..<width:
      # enable release mode to make this faster.
      buffer[j] = buffer[j+1]
      buffer[j+1] = buffer[j+2]
      buffer[j+2] = buffer[j+3]
      buffer[j+3] = 255
      j += 4
    i += stride

  result = encodePNG32(buffer, width, height)  

proc captureAllScreensDarwin*(): seq[PNG[seq[byte]]] =
  let nDisplays = numActiveDisplaysImplDarwin().int
  for i in 0..<nDisplays:
    result &= captureScreenImplDarwin(i)

when isMainModule:
  import times
  import streams
  let nDisplays = numActiveDisplaysImplDarwin().int
  var 
    height, width: int
  
  for i in 0..<nDisplays:
    let rect = getDisplayBoundsImplDarwin(i) 
    if (rect.max.y - rect.min.y) > height:
      height = rect.max.y - rect.min.y
    width += (rect.max.x - rect.min.x)

  var time = cpuTime()
  let buffer = captureImplDarwin(0, 0, width, height)
  var s = newFileStream("screenshot.png", fmWrite)
  buffer.writeChunks s
  s.close()
  echo "Time taken: ", cpuTime() - time

  time = cpuTime()
  let screen = captureScreenImplDarwin(0)
  s = newFileStream("screenshot0.png", fmWrite)
  screen.writeChunks s
  s.close()
  echo "Time taken: ", cpuTime() - time
