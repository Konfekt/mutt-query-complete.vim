" Rc fallback, reached when neither neomutt nor mutt is on PATH.
" Ok: the matched query_command string is kept, arguments included.
" Bad: the command is cleared and both error sentences are reported.
"
"   HOME=<dir with only ~/.muttrc> MQ_MODE=ok|bad MQ_EXPECT=<command> MQ_OUT=<file> \
"     PATH=<dir without mutt or neomutt> \
"     /usr/bin/vim -u NONE -N -n -i NONE -Es -S test/rc-fallback.vim

let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
execute 'set runtimepath+=' . fnameescape(s:root)
let s:failures = []
let s:caught = ''

if executable('mutt') || executable('neomutt')
  call add(s:failures, 'mail client is on PATH')
endif

try
  execute 'source' fnameescape(s:root . '/plugin/muttquery.vim')
  enew
  set filetype=mail
catch
  let s:caught = v:exception
endtry

let s:cmd = get(g:, 'muttquery_command', 'UNSET')
if $MQ_MODE ==# 'ok'
  if s:cmd !=# $MQ_EXPECT
    call add(s:failures, 'cmd=' . string(s:cmd))
  endif
  if s:caught =~# 'no valid'
    call add(s:failures, 'unexpected error: ' . s:caught)
  endif
elseif $MQ_MODE ==# 'bad'
  if s:cmd !=# ''
    call add(s:failures, 'cmd=' . string(s:cmd))
  endif
  if stridx(s:caught, 'The command ' . $MQ_EXPECT . ' is no valid executable. Please set $query_command in ~/.muttrc or g:muttquery_command in ~/.vimrc to a valid executable!') < 0
    call add(s:failures, 'missing error text: ' . s:caught)
  endif
else
  call add(s:failures, 'MQ_MODE must be ok or bad')
endif

if !empty(s:failures)
  call writefile(s:failures, $MQ_OUT)
  cquit!
endif
call writefile(['PASS'], $MQ_OUT)
qa!
