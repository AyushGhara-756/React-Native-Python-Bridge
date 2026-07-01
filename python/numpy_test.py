def diagnostics(_unused=None):
    import numpy as np
    a = np.array([1, 2, 3])
    s = np.sum(a)
    m = np.mean(a)
    return f"numpy {np.__version__}: sum={s} mean={m}"

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
