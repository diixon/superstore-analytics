def divide(a, b):
    return a / b

try:
    divion = divide(10,0)
    print(divion)
except Exception as e:
    print('Something wrong')
    print(f'Error Details: {e}')

print("Program continues after the try/except block.")