import { useEffect, useState } from 'react';
import { SafeAreaView, StyleSheet, Text } from 'react-native';
import { callPython, callPythonArgs } from './pythonBridge';

function App() {
  const [pyMessage, setPyMessage] = useState('');
  const [nativeLog, setNativeLog] = useState('');
  const [nativeError, setNativeError] = useState('');
  const [numpyResult, setNumpyResult] = useState('');

  useEffect(() => {
    const r1 = callPython("hello", "hello_world", "ROAM");
    setPyMessage(r1.error ? 'Python error: ' + r1.error : r1.value);

    const r2 = callPython("hello", "process_grid", [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ]);
    setNativeLog(r2.error ? 'Log error: ' + r2.error : r2.value);

    const r3 = callPythonArgs("hello", "add", [10, 20, 30]);
    setNativeError(r3.error ? 'Error: ' + r3.error : r3.value);

    const r4 = callPython("numpy_test", "diagnostics", []);
    setNumpyResult(r4.error ? 'Numpy error: ' + r4.error : r4.value);
  }, []);

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.label}>Result:</Text>
      <Text style={styles.text}>{pyMessage}</Text>
      <Text style={styles.error}>{nativeError}</Text>
      <Text style={styles.log}>{nativeLog}</Text>
      <Text style={styles.label}>Numpy:</Text>
      <Text style={styles.text}>{numpyResult}</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  label: {
    fontSize: 14,
    color: '#666',
    marginTop: 20,
  },
  text: {
    fontSize: 24,
  },
  error: {
    fontSize: 12,
    color: 'red',
    marginTop: 10,
  },
  log: {
    fontSize: 10,
    color: '#333',
    marginTop: 10,
  },
});

export default App;