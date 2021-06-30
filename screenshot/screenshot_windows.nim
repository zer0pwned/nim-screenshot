#[
  https://www.apriorit.com/dev-blog/193-multi-monitor-screenshot
]#
import os
import winim
import nimPNG
import ./common

type 
  getMonitorBoundsContext = object
    index: int
    rect: RECT
    count: int

  # point* = object
  #   x*: int
  #   y*: int

  # rectangle* = object 
  #   min*: point
  #   max*: point 

  # WindowsCaptureException* = object of ValueError

proc countupMonitorCallback(hMonitor: HMONITOR, hdcMonitor: HDC, 
                          lprcMonitor: LPRECT, dwData: LPARAM): WINBOOL {.stdcall.} =
  let countAddr = cast[ptr int](dwData)
  countAddr[] = countAddr[] + 1
  return TRUE

proc getMonitorRealSize(hMonitor: HMONITOR): PRECT=
  var info: MONITORINFOEXW
  info.struct1.cbSize = sizeof(MONITORINFOEXW).DWORD

  var success = GetMonitorInfo(hMonitor, cast[LPMONITORINFO](info.addr))
  if success == 0:
    return nil

  var devMode: DEVMODEW
  devMode.dmSize = sizeof(DEVMODEW).WORD
  success = EnumDisplaySettings(info.szDevice[0].unsafeAddr, ENUM_CURRENT_SETTINGS, devMode.addr)
  if success == 0:
    return nil

  var ret: RECT
  ret.left = devMode.union1.struct2.dmPosition.x
  ret.top = devMode.union1.struct2.dmPosition.y
  ret.right = devMode.union1.struct2.dmPosition.x + devMode.dmPelsWidth
  ret.bottom = devMode.union1.struct2.dmPosition.y + devMode.dmPelsHeight
  return ret.addr

proc getMonitorBoundsCallback(hMonitor: HMONITOR, hdcMonitor: HDC, 
                              lprcMonitor: LPRECT, dwData: LPARAM): WINBOOL {.stdcall.} =
  let contextAddr = cast[ptr getMonitorBoundsContext](dwData)
  if contextAddr[].count != contextAddr[].index:
    contextAddr[].count = contextAddr[].count + 1
    ## Not desired one, keep enumrating
    return TRUE

  let realSize = getMonitorRealSize(hMonitor)
  if realSize !=  nil :
    contextAddr[].rect = realSize[]
  else:
    contextAddr[].rect = lprcMonitor[]

  ## stop enumrating
  return FALSE

proc getDisplayBoundsImplWindows*(displayIndex: int): rectangle = 
  var 
    hdc: HDC
    context: getMonitorBoundsContext
    lpfnEnum: MONITORENUMPROC = getMonitorBoundsCallback
  context.index = displayIndex
  context.count = 0
  discard EnumDisplayMonitors(hdc, nil, lpfnEnum, cast[LPARAM](context.addr))

  result.min.x = context.rect.left
  result.min.y = context.rect.top
  result.max.x = context.rect.right
  result.max.y = context.rect.bottom

proc numActiveDisplaysImplWindows*(): int = 
  var 
    count: int
    hdc: HDC
    lpfnEnum: MONITORENUMPROC = countupMonitorCallback

  let success = EnumDisplayMonitors(hdc, nil, lpfnEnum, cast[LPARAM](count.addr))
  if success == 0.int32:
    raiseOSError(osLastError())
  
  return count

proc captureImplWindows*(x, y, width, height: int): PNG[seq[byte]] = 
  if width <= 0 or height <= 0 :
    raise newException(WindowsCaptureException, "width or height should be > 0")

  var buffer = newSeq[byte](width * height * 4)
  let hwnd = GetDesktopWindow()
  let hdc = GetDC(hwnd)
  if hdc == ERROR_INVALID_HANDLE:
    raise newException(WindowsCaptureException, "unable to get display context of current desktop")
  defer: discard ReleaseDC(hwnd, hdc)

  let memory = CreateCompatibleDC(hdc)
  if memory == ERROR_INVALID_HANDLE:
    raise newException(WindowsCaptureException, "unable to create memory device context")
  defer: discard DeleteDC(memory)

  let bitmap = CreateCompatibleBitmap(hdc, width.int32, height.int32)
  if bitmap == ERROR_INVALID_HANDLE:
    raise newException(WindowsCaptureException, "unable to create bitmap")
  defer: discard DeleteObject(bitmap)

  var header: BITMAPINFO
  header.bmiHeader.biSize = sizeof(BITMAPINFO).DWORD
  header.bmiHeader.biPlanes = 1.WORD
  header.bmiHeader.biBitCount = 32
  header.bmiHeader.biWidth = width.LONG
  ## need to be negetive otherwise will be flipped
  header.bmiHeader.biHeight = -height.LONG
  header.bmiHeader.biCompression = BI_RGB
  header.bmiHeader.biSizeImage = (width * height * 4).DWORD

  let old = SelectObject(memory, bitmap)
  if old == ERROR_INVALID_HANDLE:
    raise newException(WindowsCaptureException, "unable to selects bitmap into the device context")

  var success = BitBlt(memory, 0, 0, width.int32, height.int32, hdc, x.int32, y.int32, SRCCOPY)
  if success == 0:
    raise newException(WindowsCaptureException, "failed to transfer color data into memory")

  success = GetDIBits(hdc, bitmap, 0, height.UINT, 
                      cast[ptr pointer](buffer[0].unsafeaddr), 
                      header.addr, 
                      DIB_RGB_COLORS)
  if success == 0:
    raise newException(WindowsCaptureException, "unable to retrieve the bitmap")

  var i = 0
  for iy in 0..<height:
    var j = i
    for ix in 0..<width:
      swap buffer[j], buffer[j+2]
      buffer[j+3] = 255
      j += 4
      i += 4

  result = encodePNG32(buffer, width, height)  

proc captureScreenImplWindows*(displayIndex: int): PNG[seq[byte]] =
  let rect = getDisplayBoundsImplWindows(displayIndex)
  let height = rect.max.y - rect.min.y
  let width = rect.max.x - rect.min.x
  result = captureImplWindows(rect.min.x, rect.min.y, width, height)

when isMainModule:
  import times
  import streams

  let nDisplays = numActiveDisplaysImplWindows().int
  var 
    height, width: int
  
  for i in 0..<nDisplays:
    let rect = getDisplayBoundsImplWindows(i) 
    if (rect.max.y - rect.min.y) > height:
      height = rect.max.y - rect.min.y
    width += (rect.max.x - rect.min.x)

  var time = cpuTime()
  let buffer = captureImplWindows(0, 0, width, height)
  var s = newFileStream("screenshot_all.png", fmWrite)
  buffer.writeChunks s
  s.close()
  echo "Time taken: ", cpuTime() - time

  for i in 0..<nDisplays:
    var time = cpuTime()
    let buffer = captureScreenImplWindows(i)
    var s = newFileStream("screenshot_" & $i & ".png", fmWrite)
    buffer.writeChunks s
    s.close()
    echo "Time taken: ", cpuTime() - time
