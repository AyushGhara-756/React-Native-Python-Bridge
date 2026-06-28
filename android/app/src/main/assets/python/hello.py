def hello_world(name):
    return f"Hello World FROM Python {name}"

def another_func(val):
    return f"Got: {val}"

def no_arg_func():
    return "This function takes no arguments"

def add(a, b,c):
    return str(a + b+c)

def double_it(x):
    return str(x * 2)

def sum_list(items):
    return str(sum(items))

def process_grid(grid):
    total = sum(sum(row) for row in grid)
    return str(total)

def describe(data):
    if isinstance(data, list):
        return f"List with {len(data)} items"
    return f"Got: {data}"