type
  point* = object
    x*: int
    y*: int

  rectangle* = object 
    min*: point
    max*: point 

  MacCaptureException* = object of ValueError
  WindowsCaptureException* = object of ValueError
  LinuxCaptureException* = object of ValueError
  UnimplementedException* = object of CatchableError