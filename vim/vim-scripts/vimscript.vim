"s前缀的表示局部变量，生效的范围是当前脚本，避免污染全局变量
"b:name 缓冲区的局部变量
"w:name 窗口的局部变量
"g:name 全局变量 （也用于函数中）
"v:name vim 预定义的变量
let s:count = 1 "使用let声明变量，使用unlet删除变量 unlet s:count ，
while s:count <  5
    echo "count is" s:count
    let s:count += 1
endwhile
unlet s:count
unlet! s:aa "如果变量不存在的时候使用unlet会报错，加!可以避免

if !exists('s:count') "检查变量是否存在
    echo "variables does not exists"
endif

if 1 "非零为真，零值为假
    echo "true"
endif
 
if "true" "这里期待的是数字，转换失败，所以为零值
    echo "true"
endif

if "123"
    echo "123 is true"
endif
let s:var = 123

if s:var > 10
    echo "echo s:var > 0"
elseif s:var < 8
    echo "echo s:var < 8"
else
    echo "hahh"
endif

unlet s:var

if v:version >=800
    echo "Your vim is latest"
else
    echo "Please upgrade your vim"
endif


function Min(num1,num2)
    if a:num1 < a:num2
        let smaller = a:num1
    else
        let smaller = a:num2
    endif
    return smaller
endfunction

function! Min(num1,num2,num3) " 重新定义一个存在的函数
    echo "This is a redefined function"
endfunction


function WordsCount() range
    let lnum = a:firstline
    let n = 0
    while lnum <= a:lastline
        let n = n + len(split(getline(lnum)))
        let lnum = lnum + 1
    endwhile
    echo "found " . n . " words"
endfunction

"可变参数

function Show(start, ...)
    echo "start is " . a:start
    let index = 1
    while index <= a:0 "a:0表示可变参数的个数
        echo "  Arg " . index . " is " . a:{index}
        let index = index + 1
    endwhile
    echo " "
endfunction


"列表
let alist = ['A','B','C']
call add(alist,'D')
echo alist + ['E','F','G']

call extend(alist,['E','F','G','H'])

"for member in alist
""    echo member
"endfor

"for a in range(3)
""    echo a
"endfor

let uk2nl = {'one': 'een', 'two': 'twee', 'three': 'drie'}

for key in keys(uk2nl)
    echo key
endfor

for key in sort(keys(uk2nl))
    echo key
endfor
echo uk2nl['one']
echo uk2nl.two













