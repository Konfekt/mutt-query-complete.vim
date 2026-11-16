scriptencoding utf-8
" Completion and query_command detection, driven by test/bin/mq-query.
"
"   MQ_OUT=<file> vim -u NONE -N -n -i NONE -Es -S test/complete.vim
"   MQ_OUT=<file> nvim -u NONE -i NONE --headless -n -S test/complete.vim

let s:root = fnamemodify(expand('<sfile>:p'), ':h:h')
let s:bin = s:root . '/test/bin'
let s:tmp = tempname()
call mkdir(s:tmp, 'p')
execute 'set runtimepath^=' . fnameescape(s:root)
set shell=/bin/sh
let $PATH = s:bin . ':' . $PATH
let $MQ_ARGS = s:tmp . '/args'
let $MQ_RESULTS = s:tmp . '/results'
let s:failures = []

function! s:results(lines) abort
  call writefile(a:lines, $MQ_RESULTS)
endfunction

function! s:args() abort
  return filereadable($MQ_ARGS) ? readfile($MQ_ARGS) : []
endfunction

" Run muttquery#SetMuttQueryCommand() and return the error it raised, if any.
function! s:detect() abort
  try
    call muttquery#SetMuttQueryCommand()
  catch
    return v:exception
  endtry
  return ''
endfunction

" Put {line} into a fresh buffer, cursor after its last character, and return
" the start column muttquery reports.
function! s:start(line, ...) abort
  enew!
  call setline(1, a:line)
  call cursor(1, a:0 ? a:1 : col('$'))
  return muttquery#CompleteQuery(1, '')
endfunction

function! s:case(name) abort
  let s:name = a:name
  call delete($MQ_ARGS)
  call s:results([])
endfunction

function! s:check(cond, msg) abort
  if !a:cond
    call add(s:failures, s:name . ': ' . a:msg)
  endif
endfunction

function! s:Run(name, func) abort
  call s:case(a:name)
  try
    call call(a:func, [])
  catch
    call add(s:failures, a:name . ': ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endfunction

function! s:TestEmptyCommandCompletesNothing() abort
  let g:muttquery_command = ''
  call s:check(muttquery#CompleteQuery(0, 'foo') ==# [], 'expected []')
endfunction

function! s:TestBasicEntry() abort
  let g:muttquery_command = 'mq-query %s'
  call s:results(["foo@bar.com\tFoo Bar\tsome info"])
  let items = muttquery#CompleteQuery(0, 'foo')
  call s:check(s:args() ==# ['foo'], 'args ' . string(s:args()))
  call s:check(len(items) == 1, 'items ' . string(items))
  call s:check(get(get(items, 0, {}), 'word', '') ==# '"Foo Bar" <foo@bar.com>', 'word ' . string(items))
  call s:check(get(get(items, 0, {}), 'menu', '') ==# '<foo@bar.com>', 'menu ' . string(items))
endfunction

function! s:TestQueryWithBlankIsOneArgument() abort
  let g:muttquery_command = 'mq-query %s'
  call muttquery#CompleteQuery(0, 'Foo Ba')
  call s:check(s:args() ==# ['Foo Ba'], 'args ' . string(s:args()))
endfunction

function! s:TestQuotedPlaceholder() abort
  for cmd in ['mq-query ''%s''', 'mq-query "%s"']
    let g:muttquery_command = cmd
    call muttquery#CompleteQuery(0, 'Foo Ba')
    call s:check(s:args() ==# ['Foo Ba'], cmd . ' args ' . string(s:args()))
    call muttquery#CompleteQuery(0, 'o''neil')
    call s:check(s:args() ==# ['o''neil'], cmd . ' quote args ' . string(s:args()))
  endfor
endfunction

function! s:TestQueryIsNotRunByShell() abort
  let g:muttquery_command = 'mq-query %s'
  let marker = s:tmp . '/pwned'
  call muttquery#CompleteQuery(0, 'x;touch ' . marker)
  call s:check(!filereadable(marker), 'query ran a shell command')
  call muttquery#CompleteQuery(0, '$(touch ' . marker . ')')
  call s:check(!filereadable(marker), 'query ran a command substitution')
endfunction

function! s:TestSpecialReplacementCharacters() abort
  let g:muttquery_command = 'mq-query %s'
  call muttquery#CompleteQuery(0, 'a&b\1~')
  call s:check(s:args() ==# ['a&b\1~'], 'args ' . string(s:args()))
endfunction

function! s:TestCommandWithoutPlaceholderGetsQueryAppended() abort
  let g:muttquery_command = 'mq-query --mutt'
  call muttquery#CompleteQuery(0, 'foo')
  call s:check(s:args() ==# ['--mutt', 'foo'], 'args ' . string(s:args()))
endfunction

function! s:TestEntryWithoutName() abort
  let g:muttquery_command = 'mq-query %s'
  call s:results(["foo@bar.com\t", 'baz@bar.com'])
  let items = muttquery#CompleteQuery(0, 'foo')
  call s:check(map(copy(items), 'v:val.word') ==# ['foo@bar.com'], 'items ' . string(items))
endfunction

function! s:TestNameWithQuote() abort
  let g:muttquery_command = 'mq-query %s'
  call s:results(["foo@bar.com\t" . 'Foo "Bar" Baz\'])
  let items = muttquery#CompleteQuery(0, 'foo')
  call s:check(get(get(items, 0, {}), 'word', '') ==# '"Foo \"Bar\" Baz\\" <foo@bar.com>', 'items ' . string(items))
endfunction

function! s:TestLongMultibyteName() abort
  let g:muttquery_command = 'mq-query %s'
  let name = repeat('ä', 40)
  call s:results(["foo@bar.com\t" . name])
  let abbr = get(get(muttquery#CompleteQuery(0, 'foo'), 0, {}), 'abbr', '')
  call s:check(abbr ==# repeat('ä', 31) . '...', 'abbr ' . string(abbr))
endfunction

function! s:TestStartInHeaderSkipsBlanks() abort
  call s:check(s:start('To:   foo') == 6, 'To start ' . s:start('To:   foo'))
  call s:check(s:start('Cc: a@b.c,  Foo Ba') == 12, 'Cc start ' . s:start('Cc: a@b.c,  Foo Ba'))
  call s:check(s:start('Bcc:foo') == 4, 'Bcc start ' . s:start('Bcc:foo'))
endfunction

function! s:TestStartInBody() abort
  call s:check(s:start('hello wor') == 6, 'body start ' . s:start('hello wor'))
endfunction

function! s:TestStartAtFirstColumn() abort
  call s:check(s:start('hello world', 1) < 0, 'start ' . s:start('hello world', 1))
endfunction

function! s:TestBlankCommandIsRejected() abort
  let g:muttquery_command = '   '
  let err = s:detect()
  call s:check(err =~# 'No mutt query_command found', 'error ' . string(err))
  call s:check(g:muttquery_command ==# '', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestValidCommandIsKept() abort
  let g:muttquery_command = 'mq-query --flag %s'
  let err = s:detect()
  call s:check(err ==# '', 'error ' . string(err))
  call s:check(g:muttquery_command ==# 'mq-query --flag %s', 'cmd ' . string(g:muttquery_command))
endfunction

" Detect query_command through a stand-in mutt that prints {output} for -Q.
function! s:detect_from_mutt(output) abort
  let dir = s:tmp . '/muttbin'
  call mkdir(dir, 'p')
  call writefile(['#!/bin/sh', 'cat "' . s:tmp . '/q"'], dir . '/mutt')
  call setfperm(dir . '/mutt', 'rwx------')
  call writefile(a:output, s:tmp . '/q')
  let path = $PATH
  let $PATH = dir . ':' . path
  unlet! g:muttquery_command
  try
    return s:detect()
  finally
    let $PATH = path
  endtry
endfunction

function! s:TestMuttQuery() abort
  call s:detect_from_mutt(['query_command="mq-query ''%s''"'])
  call s:check(g:muttquery_command ==# 'mq-query ''%s''', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestMuttQueryEscapedQuotes() abort
  call s:detect_from_mutt(['query_command="mq-query --x \"%s\" \\\\"'])
  call s:check(g:muttquery_command ==# 'mq-query --x "%s" \\', 'cmd ' . string(g:muttquery_command))
endfunction

" Detect query_command from a muttrc holding {lines}, without mutt on PATH.
function! s:detect_from_rc(lines) abort
  let home = s:tmp . '/home'
  call mkdir(home, 'p')
  call writefile(a:lines, home . '/.muttrc')
  let [path, homedir] = [$PATH, $HOME]
  let $PATH = s:bin
  let $HOME = home
  unlet! g:muttquery_command
  try
    return s:detect()
  finally
    let [$PATH, $HOME] = [path, homedir]
  endtry
endfunction

function! s:TestRcDoubleQuoted() abort
  call s:detect_from_rc(['set query_command = "mq-query ''%s''"'])
  call s:check(g:muttquery_command ==# 'mq-query ''%s''', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestRcSingleQuotedWithComment() abort
  call s:detect_from_rc(['  set query_command=''mq-query "%s"''   # address book'])
  call s:check(g:muttquery_command ==# 'mq-query "%s"', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestRcTrailingBlank() abort
  call s:detect_from_rc(['set query_command="mq-query %s"  '])
  call s:check(g:muttquery_command ==# 'mq-query %s', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestStartInOtherAddressHeaders() abort
  for header in ['From:', 'Reply-To:', 'Mail-Followup-To:']
    let line = header . ' a@b.c, Foo Ba'
    call s:check(s:start(line) == len(header) + 8, header . ' start ' . s:start(line))
  endfor
endfunction

function! s:TestFailingMuttFallsBackToRc() abort
  let home = s:tmp . '/home'
  call mkdir(home, 'p')
  call writefile(['set query_command = "mq-query %s"'], home . '/.muttrc')
  let homedir = $HOME
  let $HOME = home
  try
    let err = s:detect_from_mutt([])
  finally
    let $HOME = homedir
  endtry
  call s:check(err ==# '', 'error ' . string(err))
  call s:check(g:muttquery_command ==# 'mq-query %s', 'cmd ' . string(g:muttquery_command))
endfunction

function! s:TestNothingFoundMessage() abort
  let g:muttquery_command = ''
  let err = s:detect()
  call s:check(err =~# 'No mutt query_command found\.', 'error ' . string(err))
endfunction

function! s:TestNoFileTypesDefinesNoAutocommand() abort
  let g:muttquery_filetypes = []
  execute 'source' fnameescape(s:root . '/plugin/muttquery.vim')
  call s:check(!exists('#muttquery#FileType'), execute('autocmd muttquery FileType'))
  unlet g:muttquery_filetypes g:loaded_muttquery
endfunction

for s:f in sort(filter(map(split(execute('function /_Test'), "\n"),
      \ 'matchstr(v:val, ''<SNR>\d\+_Test\w\+'')'), '!empty(v:val)'))
  call s:Run(matchstr(s:f, 'Test\w\+'), function(s:f))
endfor

call delete(s:tmp, 'rf')
if !empty(s:failures)
  call writefile(s:failures, $MQ_OUT)
  cquit!
endif
call writefile(['PASS'], $MQ_OUT)
qa!
