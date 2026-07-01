#import "PythonBridgeModule.h"
#import "PythonBridge.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTLog.h>

static NSString* bundlePath() {
  return NSBundle.mainBundle.bundlePath;
}

static NSString* stdlibPath() {
  return [bundlePath() stringByAppendingPathComponent:@"lib/python3.13"];
}

static PyObject* objcToPython(id obj) {
  if (!obj || obj == [NSNull null]) {
    Py_RETURN_NONE;
  } else if ([obj isKindOfClass:[NSString class]]) {
    return PyUnicode_FromString([(NSString*)obj UTF8String]);
  } else if ([obj isKindOfClass:[NSNumber class]]) {
    return PyLong_FromLong([(NSNumber*)obj longValue]);
  } else if ([obj isKindOfClass:[NSArray class]]) {
    NSArray* arr = (NSArray*)obj;
    PyObject* pyList = PyList_New([arr count]);
    for (NSUInteger i = 0; i < [arr count]; i++) {
      PyList_SetItem(pyList, i, objcToPython(arr[i]));
    }
    return pyList;
  }
  Py_RETURN_NONE;
}

@implementation PythonBridgeModule

RCT_EXPORT_MODULE(RNPythonBridge)

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      // Set up log path in app's Caches directory (always writable)
      NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
      NSString* cacheDir = [paths firstObject];
      NSString* logPath = [cacheDir stringByAppendingPathComponent:@"python_bridge.log"];
      PythonBridge_setLogPath([logPath UTF8String]);

      bool ok = rnpythonbridge::PythonBridge::getInstance().initialize(
        [bundlePath() UTF8String],
        [stdlibPath() UTF8String]
      );
      if (!ok) {
        RCTLogError(@"PythonBridge init failed: %s", PythonBridge_getLastError());
      } else {
        RCTLog(@"PythonBridge: initialized successfully");
      }
    });
  }
  return self;
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, callPython: (NSString*)moduleName :(NSString*)functionName :(id)arg)
{
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* pyObj = objcToPython(arg);
  PyObject* pyArgs = PyTuple_Pack(1, pyObj);
  Py_DECREF(pyObj);
  std::string result = rnpythonbridge::PythonBridge::getInstance().callPythonFunction(
    [moduleName UTF8String], [functionName UTF8String], pyArgs
  );
  Py_DECREF(pyArgs);
  PyGILState_Release(gstate);
  const char* lastError = PythonBridge_getLastError();
  if (lastError && lastError[0]) {
    RCTLogError(@"PythonBridge error: %s", lastError);
  }
  return [NSString stringWithUTF8String:result.c_str()];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, callPythonArgs: (NSString*)moduleName :(NSString*)functionName :(NSArray*)args)
{
  PyGILState_STATE gstate = PyGILState_Ensure();
  PyObject* pyArgs = PyTuple_New([args count]);
  for (NSUInteger i = 0; i < [args count]; i++) {
    PyObject* pyObj = objcToPython(args[i]);
    PyTuple_SetItem(pyArgs, i, pyObj);
  }
  std::string result = rnpythonbridge::PythonBridge::getInstance().callPythonFunction(
    [moduleName UTF8String], [functionName UTF8String], pyArgs
  );
  Py_DECREF(pyArgs);
  PyGILState_Release(gstate);
  const char* lastError = PythonBridge_getLastError();
  if (lastError && lastError[0]) {
    RCTLogError(@"PythonBridge error: %s", lastError);
  }
  return [NSString stringWithUTF8String:result.c_str()];
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, getLog)
{
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* logPath = [[paths firstObject] stringByAppendingPathComponent:@"python_bridge.log"];
  NSString* logContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
  return logContent ?: @"(no log)";
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, getError)
{
  const char* err = PythonBridge_getLastError();
  return err && err[0] ? [NSString stringWithUTF8String:err] : @"(no error)";
}

@end
