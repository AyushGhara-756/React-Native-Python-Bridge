def diagnostics(_unused=None):
    import numpy as np
    import traceback
    a = np.array([1, 2, 3])
    s = np.sum(a)
    m = np.mean(a)
    p = ""
    try:
        import pandas as pd
        df = pd.DataFrame({"x": [1, 2, 3], "y": [4, 5, 6]})
        p = f" pandas {pd.__version__}: {df.shape}"
    except Exception:
        tb = traceback.format_exc()
        lines = tb.split("\n")
        p = f" pandas err: {' '.join(lines[-10:])}"
    return f"numpy {np.__version__}: sum={s} mean={m} | {p}"

def array_sum(arr):
    try:
        import numpy as np
        a = np.array(arr)
        return str(np.sum(a))
    except Exception as e:
        return f"numpy error: {e}"

def matrix_multiply(a, b):
    import numpy as np
    m1 = np.array(a)
    m2 = np.array(b)
    return str(np.dot(m1, m2))

def stats(data):
    import numpy as np
    a = np.array(data)
    return {
        "mean": float(np.mean(a)),
        "std": float(np.std(a)),
        "min": float(np.min(a)),
        "max": float(np.max(a)),
    }
