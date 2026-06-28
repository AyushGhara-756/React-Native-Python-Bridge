#import "HelloWorldModule.h"
#import "HelloWorld.h"

@implementation HelloWorldModule

RCT_EXPORT_MODULE(RNPythonBridgeHelloWorld)

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, getMessage)
{
  return @(rnpythonbridge::getMessage());
}

@end
