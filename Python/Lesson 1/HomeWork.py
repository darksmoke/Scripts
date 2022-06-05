def filter_string(text, latter):
    n = ''
    for i in text:
        if i == latter:
            continue
        n = n + i
        return n
#    print(i * 2, end='')


text = 'If I look forward I am win'
print(filter_string(text, 'i'))  # 'f  look forward  am wn'
print(filter_string(text, 'O'))  # 'If I lk frward I am win'