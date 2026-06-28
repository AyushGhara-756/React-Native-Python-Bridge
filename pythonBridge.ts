import { Platform, NativeModules } from 'react-native';

const bridge = NativeModules.RNPythonBridge;

type CallResult = { value: any; error: null } | { value: null; error: string };

export function callPython(module: string, fn: string, arg: any): CallResult {
  try {
    if (Platform.OS === 'ios') {
      return { value: bridge.callPython(module, fn, arg), error: null };
    }
    return {
      value: bridge.callPython(module, fn, Array.isArray(arg) ? arg : [arg]),
      error: null
    };
  } catch (e) {
    return { value: null, error: String(e) };
  }
}

export function callPythonArgs(module: string, fn: string, args: any[]): CallResult {
  try {
    return { value: bridge.callPythonArgs(module, fn, args), error: null };
  } catch (e) {
    return { value: null, error: String(e) };
  }
}
