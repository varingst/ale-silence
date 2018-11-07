" -- Interface -- {{{1

function! ale#silence#(bang, line1, line2, ...) abort " {{{2
  " a:000 : errors to silence. if none given, silence all in range
  let bufnr = winbufnr('.')
  let open = a:line1
  let close = a:line2

  if a:bang
    let [remainder, open, close] = s:disable_file(bufnr, open, close, a:000)

    if !s:getopt('ale_silence_filewise_fallback', 0)
      return remainder
    endif
  endif

  let errors = a:bang ?
             \ remainder :
             \ s:filter_errors(s:filter_range(bufnr, open, close), a:000)

  if open == close
    return s:getopt('ale_silence_prefer_inline', 0) ?
         \ s:disable_next_line(s:disable_inline(errors)) :
         \ s:disable_inline(s:disable_next_line(errors))
  else
    return s:getopt('ale_silence_range_fallback', 1) ?
         \ s:disable_range_linewise(s:disable_range(errors, open, close)) :
         \ s:disable_range(errors, open, close)
  endif
endfunction

function! ale#silence#List(...) abort " {{{2
  let lines = []
  " NOTE: as of now, only list the listers for which there are currently errors
  " need some other place to get 'currently active linters' from
  for linter in map(s:partition(s:get_buffer_info(a:0 ? a:1 : s:winbufnr('')),
                 \              'linter_name'),
                 \ 'v:val[0].linter_name')

    call add(lines, printf("==== %s ====", linter))
    let directives = s:get_directives(linter)
    for name in s:directive_order
      if !has_key(directives, name)
        continue
      endif
      let Format = type(directives[name]) is v:t_string ?
            \ ale#silence#Format(directives[name]) :
            \ directives[name]
      call add(lines, printf("%-10s %s",
                           \ name,
                           \ Format(['<err1>', '<err2>', '...'])))
    endfor
  endfor
  return lines
endfunction

function! ale#silence#complete(arg_lead, cmd_line, cursor_pos) abort " {{{2
   return s:complete_errors_in_range(s:parse_cmd_line(a:cmd_line,
                                                   \ [s:winbufnr('.')]))
endfunction

function! ale#silence#complete_lookup(arg_lead, cmd_line, cursor_pos) abort " {{{ {{{2
  let bufnr = s:winbufnr('.')
  let line = line('.')
  let compl = s:complete_errors_in_range([bufnr, line, line])
  return strlen(compl) > 0 ? compl : s:complete_errors_in_range([bufnr])
endfunction

function! ale#silence#Format(format, ...) abort " {{{2
  let separator = a:0 ? a:1 : ' '
  function! DirFormatter(codes) closure
    return printf(a:format, join(a:codes, separator))
  endfunction
  return funcref('DirFormatter')
endfunction

function! ale#silence#LookupError(error_id) abort " {{{2
  let info = s:from_error_id(a:error_id)
  let optname = s:code_search_prefix. info.linter_name
  let search = s:getopt(optname, '')

  if !len(search)
    try
      let docs = call('ale_silence#'. info.linter_name .'#GetDocInfo', [])
    catch /E117/
      echoerr printf("No means to look up error code for linter '%s'",
                   \ info.linter_name)
      return
    endtry
    let g:[optname] = docs.code_search
    let search = docs.code_search
  endif
  call s:browse(printf(search, info.code))
endfunction

function! ale#silence#BrowseDocs(linter_name) abort " {{{2
  let optname = s:linter_docs_prefix.a:linter_name

  let url = s:getopt(optname, '')
  if !len(url)
    try
      let docs = call('ale_silence#'.a:linter_name.'#GetDocInfo', [])
    catch /E117/
      echoerr printf("No means to look up docs for linter '%s'",
                   \ info.linter_name)
      return
    endtry
    let g:[optname] = docs.docs
    let url = docs.docs
  endif
  call s:browse(url)
endfunction

" -- Disablers -- {{{1

function! s:disable_next_line(errors) abort " {{{2
  " disable-next-line: error-code
  " <line with error>
  if empty(a:errors)
    return []
  endif

  let lnum = a:errors[0].lnum
  let line = []
  let remainder = []

  for per_linter in s:filter_supported(s:partition(a:errors, 'linter_name'))
    let Format = s:get_formatter(per_linter[0], 'nextline')
    if type(Format) isnot v:t_func
      call extend(remainder, per_linter)
      continue
    endif
    let codes = uniq(sort(map(per_linter, 'v:val.code')))
    call add(line, Format(codes))
  endfor

  if !empty(line)
    call append(lnum - 1, s:indent(getline(lnum)) . join(line, ' '))
    call s:offset_lnum(remainder, lnum)
  endif

  return remainder
endfunction

function! s:disable_inline(errors) abort " {{{2
  " <line with error> disable-this-line: error-code
  if empty(a:errors)
    return []
  endif

  let lnum = a:errors[0].lnum
  let line = [getline(lnum)]
  let remainder = []

  for per_linter in s:filter_supported(s:partition(a:errors, 'linter_name'))
    let Format = s:get_formatter(per_linter[0], 'inline')
    if type(Format) isnot v:t_func
      call extend(remainder, per_linter)
      continue
    endif
    let codes = uniq(sort(map(per_linter, 'v:val.code')))
    call add(line, Format(codes))
  endfor

  if len(line) > 1
    call setline(lnum, join(line, ' '))
  endif

  return remainder
endfunction

function! s:disable_range(errors, open, close) abort " {{{2
  " disable-from-this-line: error-code
  " ...
  " <line with error>
  " ...
  " enable-from-this-line: error-code
  if empty(a:errors)
    return []
  endif

  let open_line = []
  let close_line = []
  let remainder = []

  for per_linter in s:filter_supported(s:partition(a:errors, 'linter_name'))
    let Start = s:get_formatter(per_linter[0], 'start')
    let End   = s:get_formatter(per_linter[0], 'end')
    if type(Start) isnot v:t_func || type(End) isnot v:t_func
      call extend(remainder, per_linter)
      continue
    endif
    let codes = uniq(sort(map(per_linter, 'v:val.code')))
    call add(open_line, Start(codes))
    call add(close_line, End(codes))
  endfor

  if !empty(open_line)
    call append(a:close,       s:indent(getline(a:close)) . join(close_line))
    call append(a:open - 1, s:indent(getline(a:open)) . join(open_line))
    call s:offset_lnum(remainder, a:open)
  endif

  return remainder
endfunction

function! s:disable_file(bufnr, open, close, codes) abort " {{{2
  let open  = a:open == a:close ? 1 : a:open
  let close = a:open == a:close ? line('$') : a:close

  let l:errors = s:filter_errors(s:filter_range(a:bufnr, open, close), a:codes)

  if empty(l:errors)
    return [[], a:open, a:close]
  endif

  let lines = []
  let remainder = []

  for per_linter in s:filter_supported(s:partition(l:errors, 'linter_name'))
    let Format = s:get_formatter(per_linter[0], 'file')
    if type(Format) isnot v:t_func
      call extend(remainder, per_linter)
      continue
    endif
    let codes = uniq(sort(map(per_linter, 'v:val.code')))
    call add(lines, Format(codes))
  endfor

  if !empty(lines)
    call append(a:open - 1, lines)
    let open += 1
    let close += 1
  endif

  return [remainder, open, close]
endfunction

function! s:disable_range_linewise(errors) abort " {{{2
  if empty(a:errors)
    return []
  endif
  " range fallback: silence each line in range with
  " next_line/inline
  let remainder = []
  let lnum_offset = 0
  for per_line in s:filter_supported(s:partition(a:errors, 'lnum'))
    call s:offset_lnum(per_line, per_line[0].lnum, lnum_offset)

    let next_line_remainder = s:disable_next_line(per_line)
    call extend(remainder, s:disable_inline(next_line_remainder))
    " if s:disable_next_line consumed a line, a line was added to the file
    if len(next_line_remainder) < len(per_line)
      let lnum_offset += 1
    endif
  endfor

  return remainder
endfunction

" -- Util -- {{{1
"
function! s:getopt(key, default) " {{{2
  return s:get(a:key.'_'.&filetype,
             \ s:get(a:key, a:default, b:, g:, s:),
             \ b:, g:)
endfunction

function! s:get(key, default, ...) " {{{2
  for scope in a:000
    if has_key(scope, a:key)
      return scope[a:key]
    endif
  endfor
  return a:default
endfunction

function! s:offset_lnum(errors, start, ...) abort " {{{2
  " a:errors: list of errors
  " a:start:  start line number
  " a:1:      offset (default 1)
  let offset = a:0 ? a:1 : 1
  for error in a:errors
    if error.lnum >= a:start
      let error.lnum += offset
    endif
  endfor
endfunction

function! s:partition(list, key) abort " {{{2
  " a:list: list of dictionaries
  " a:key:  dictionary key to group on
  " returns a list of lists, where all dictionaries in the nested lists
  " have a common value for a:key.
  if empty(a:list)
    return []
  endif

  let partitions = {}
  for e in a:list
    let group_key = e[a:key]
    if !has_key(partitions, group_key)
      let partitions[group_key] = []
    endif
    call add(partitions[group_key], e)
  endfor

  return map(sort(keys(partitions)), 'partitions[v:val]')
endfunction

function! s:indent(line) abort " {{{2
  " returns indent of a line
  let first_char = match(a:line, '\S')
  if first_char <= 0
    return ""
  else
    return a:line[:(first_char - 1)]
  endif
endfunction

function! s:get_nested(dict, default, ...) abort " {{{2
  if !a:0
    return default
  endif

  let dict = a:dict
  for i in range(a:0 - 1)
    if !has_key(dict, a:000[i])
      return a:default
    endif
    let dict = dict[a:000[i]]
  endfor

  return get(dict, a:000[-1], a:default)
endfunction

function! s:set_nested(dict, item, ...) abort " {{{2
  if !a:0
    throw "No keys given"
  endif

  let dict = a:dict
  for i in range(a:0 - 1)
    if !has_key(dict, a:000[i])
      let dict[a:000[i]] = {}
    endif
    let dict = dict[a:000[i]]
  endfor

  let dict[a:000[-1]] = a:item
endfunction

function! s:get_formatter(error, type) abort " {{{2
  let directives = s:get_nested(g:, '', s:directives, a:error.linter_name)

  if type(directives) isnot v:t_dict
    let directives = s:get_directives(a:error.linter_name)
    call s:set_nested(g:, directives, s:directives, a:error.linter_name)
  endif

  let Format = get(directives, a:type, '')
  if Format == ''
    return
  elseif type(Format) is v:t_string
    let Format = ale#silence#Format(Format, get(directives, 'separator', ' '))
    call s:set_nested(g:, Format,
                    \ s:directives,
                    \ a:error.linter_name,
                    \ a:type)
  elseif type(Format) isnot v:t_func
    throw a:error.linter_name.' : directive "'.a:type.'"is not string or funcref'
  endif

  return Format
endfunction

function! s:get_directives(linter) " {{{2
  try
    return call('ale_silence#'.a:linter.'#GetSilenceDirectives', [])
  catch /E117/
    let s:[s:unsupported][a:linter] = v:true
    return {}
  endtry
endfunction

function! s:get_buffer_info(bufnr) abort " {{{2
  return copy(s:get_nested(g:, [], 'ale_buffer_info', a:bufnr, 'loclist'))
endfunction

function! s:filter_range(bufnr, ...) abort " {{{2
  if a:0 == 0
    return filter(s:get_buffer_info(a:bufnr),
                \ 'v:val.bufnr == '.a:bufnr)
  elseif a:0 == 1
    return filter(s:get_buffer_info(a:bufnr),
                \ 'v:val.bufnr == '.a:bufnr.
                \ '&& v:val.lnum == '.a:1)
  elseif a:0 == 2
    return filter(s:get_buffer_info(a:bufnr),
                \ 'v:val.bufnr == '.a:bufnr.
                \ '&& v:val.lnum >= '.a:1.' && v:val.lnum <= '.a:2)
  endif
endfunction

function! s:filter_supported(errors) abort " {{{2
  let supported = []
  for per_linter in a:errors
    if s:get_nested(s:, v:false, s:unsupported, per_linter[0].linter_name)
      continue
    endif
    call add(supported, per_linter)
  endfor
  return supported
endfun

function! s:filter_errors(errors, error_ids) abort " {{{2
  if empty(a:error_ids)
    return a:errors
  endif

  let filtered = []
  let error_ids = {}
  for error_id in a:error_ids
    let error_ids[error_id] = v:true
  endfor

  for error in a:errors
    if !has_key(error, 'code')
      continue
    endif
    if has_key(error_ids, s:error_id(0, error))
      call add(filtered, error)
    endif
  endfor

  return filtered
endfunction

function! s:error_id(key, error) abort " {{{2
  return a:error.linter_name . ':' . a:error.code
endfunction

function! s:from_error_id(error_id) abort " {{{2
  let parts = split(a:error_id, ':')
  return { 'linter_name': parts[0], 'code': join(parts[1:], ':') }
endfunction

function! s:complete_errors_in_range(range_args) abort " {{{2
  return join(uniq(sort(map(filter(call('s:filter_range', a:range_args),
                      \           'has_key(v:val, "code")'),
                      \     funcref('s:error_id')))),
            \ "\n")
endfun


function! s:parse_cmd_line(cmd_line, args) abort " {{{2
  " cmd_line: command line in the form of M,MCmd, N,NCmd, NCmd or Cmd
  "           where N is a line number and M is a mark
  " args:     argument list for adding parsed range/count
  let cmd_start = match(a:cmd_line, '\u')
  let cmd_last = match(a:cmd_line, '\(\s\|$\)') - 1
  if cmd_start == 0
    if cmd_last >= 0 && a:cmd_line[cmd_last] != '!'
      return add(a:args, line('.'))
    endif
    return a:args
  elseif cmd_start > 0
    return extend(a:args,
                \ map(split(a:cmd_line[:cmd_start-1], ','),
                    \ "v:val =~# '^\\d\\+$' ? str2nr(v:val) : line(v:val)"))
  endif
endfunction

" -- Options -- {{{1

let s:ale_silence_filewise_fallback = 0
let s:ale_silence_prefer_inline = 0
let s:ale_silence_range_fallback = 1

let s:directive_order = [
      \ 'file',
      \ 'nextline',
      \ 'inline',
      \ 'start',
      \ 'end'
      \]

let s:directives = 'ale_linter_silence_directive'
let s:unsupported = 'ale_linter_silence_unsupported'
let s:code_search_prefix = 'ale_docs_code_search_'
let s:linter_docs_prefix = 'ale_docs_'
let s:[s:unsupported] = {}


" -- Testing -- {{{1

if get(g:, 'ale_silence_TESTING')
  function! s:winbufnr(arg) abort
    return get(g:, 'ale_silence_TESTING_winbufnr')
  endfunction

  function! s:browse(url) abort
    call add(get(g:, 'ale_silence_TESTING_browser', []), a:url)
  endfunction

  nnoremap <SID> <SID>
  let s:sid = maparg('<SID>', 'n')

  function! S(func, ...) abort
    return call(s:sid.a:func, a:000)
  endfunction
else
  function! s:winbufnr(arg) abort
    return winbufnr(a:arg)
  endfunction

  function! s:browse(url) abort
    call netrw#BrowseX(a:url, netrw#CheckIfRemote())
  endfunction
endif
