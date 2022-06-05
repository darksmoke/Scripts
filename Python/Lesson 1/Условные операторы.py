if условие 1:
# код, который будет выполнен,
# если условие 1 истинно
elif условие 2:
# код, который будет выполнен,
# если условие 1 ложно, но условие 2 истинно
elif условие 3:
# код, который будет выполнен,
# если условия 1 и 2 ложны, но условие 3 истинно
else:
# код, который будет выполнен
# в ином случае


def abs(number):
    return number if number >= 0 else -number
# Общий паттерн выглядит так: <expression on true> if <predicate> else <expression on false>.

# Было:
def get_type_of_sentence(sentence):
    last_char = sentence[-1]
    if last_char == '?':
        return 'question'
    return 'normal'

# Стало:
def get_type_of_sentence(sentence):
    last_char = sentence[-1]
    return 'question' if last_char == '?' else 'normal'

print(get_type_of_sentence('Hodor'))   # => normal
print(get_type_of_sentence('Hodor?'))  # => question


# Чтобы узнать, «истинно» ли некое значение или «ложно», можно воспользоваться функцией bool(). Достаточно передать этой функции значение любого типа!
print(bool(0))    # => False
print(bool(10))   # => True
print(bool(''))   # => False
print(bool('a'))  # => True