" -- Interface -- {{{1

function! ale#silence#(bang, line1, line2, ...) abort " {{{2
  " a:000 : errors to silence. if none given, silence all in range
  let bufnr = winbufnr('.')

  if a:bang " silence filewise
    let remainder = s:disable_file(s:filter_errors(s:filter_range(bufnr), a:000), a:line1)
    return
  endif

  let errors = s:filter_errors(s:filter_range(bufnr, a:line1, a:line2), a:000)

  if a:line1 == a:line2
    if get(g:, 'ale_silence_prefer_inline', 0)
      call s:disable_next_line(s:disable_inline(errors))
    else
      call s:disable_inline(s:disable_next_line(errors))
    endif
  else " range of lines
    if get(g:, 'ale_silence_range_fallback_linewise', 1)
      call s:disable_range_linewise(s:disable_range(errors, a:line1, a:line2))
    else
      call s:disable_range(errors, a:line1, a:line2)
    endif
  endif
endfunction


function! ale#silence#complete(arg_lead, cmd_line, cursor_pos) abort " {{{2
  " creates completions
  " TODO: add handling of filewise bang!
  let args = s:parse_cmd_line(a:cmd_line, [s:winbufnr('.')])
  return join(uniq(sort(map(filter(call('s:filter_range', args),
                      \           'has_key(v:val, "code")'),
                      \     funcref('s:error_id')))),
            \ "\n")
endfunction

function! ale#silence#Format(format, ...) abort " {{{2
  let separator = a:0 ? a:1 : ' '
  function! DirFormatter(codes) closure
    return printf(a:format, join(a:codes, separator))
  endfunction
  return funcref('DirFormatter')
endfunction

" -- g: keys -- {{{1

let s:directives = 'ale_linter_silence_directive'
let s:unsupported = 'ale_linter_silence_unsupported'
let s:directive_order = [
      \ 'file',
      \ 'nextline',
      \ 'inline',
      \ 'start',
      \ 'end'
      \]
let s:[s:unsupported] = {}

" -- Disablers -- {{{1

function! s:disable_next_line(errors) abort " {{{2
  " disable-next-line: error-code
  " <line with error>
  if empty(a:errors)
    return
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
    return
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

function! s:disable_range(errors, l_start, l_end) abort " {{{2
  " disable-from-this-line: error-code
  " ...
  " <line with error>
  " ...
  " enable-from-this-line: error-code
  if empty(a:errors)
    return
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
    call append(a:l_end,       s:indent(getline(a:l_end)) . join(close_line))
    call append(a:l_start - 1, s:indent(getline(a:l_start)) . join(open_line))
    call s:offset_lnum(remainder, a:l_start)
  endif

  return remainder
endfunction

function! s:disable_file(errors, lnum) abort " {{{2
  if empty(a:errors)
    return
  endif

  let lines = []
  let remainder = []

  for per_linter in s:filter_supported(s:partition(a:errors, 'linter_name'))
    let Format = s:get_formatter(per_linter[0], 'file')
    if type(Format) isnot v:t_func
      call extend(remainder, per_linter)
      continue
    endif
    let codes = uniq(sort(map(per_linter, 'v:val.code')))
    call add(lines, Format(codes))
  endfor

  if !empty(lines)
    call append(a:lnum - 1, lines)
  endif

  return remainder
endfunction

function! s:disable_range_linewise(errors) abort " {{{2
  " range fallback: silence each line in range with
  " next_line/inline
  let remainder = []
  let lnum_offset = 0
  for per_line in s:filter_supported(s:partition(a:errors, 'lnum'))
    call s:offset_lnum(per_line, per_line[0].lnum, lnum_offset)

    let next_line_remainder = s:disable_next_line(per_line)
    call extend(remainder, s:disable_inline(next_line_remainder))
    if len(next_line_remainder) < len(per_line)
      let lnum_offset += 1
    endif
  endfor

  return remainder
endfunction

" -- Util -- {{{1

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

function! ale#silence#List(...) abort " {{{2
  let lines = []
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
      call add(lines, printf("%-10s %s", name, Format(['<err1>', '<err2>', '...'])))
    endfor
  endfor
  return lines
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

function! s:filter_supported(errors) abort
  let supported = []
  for per_linter in a:errors
    if s:get_nested(s:, v:false, s:unsupported, per_linter[0].linter_name)
      continue
    endif
    call add(supported, per_linter)
  endfor
  return supported
endfun

function! s:filter_errors(errors, error_ids) abort
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

function! s:error_id(key, error) abort
  return a:error.linter_name . ':' . a:error.code
endfunction


" cmd_line: command line in the form on N,NCmd, NCmd or Cmd
" args:     argument list for adding parsed range/count
function! s:parse_cmd_line(cmd_line, args) abort
  " find start of command by first uppercase letter
  let cmd_start = match(a:cmd_line, '\u')
  let cmd_last = match(a:cmd_line, '\(\s\|$\)') - 1
  if cmd_start == 0
    if cmd_last >= 0 && a:cmd_line[cmd_last] != '!'
      return add(a:args, line('.'))
    endif
    return a:args
  elseif cmd_start > 0
    return extend(a:args, map(split(a:cmd_line[:cmd_start-1], ','),
                           \ "v:val =~# '^\\d\\+$' ? str2nr(v:val) : line(v:val)"))
  endif
endfunction

" -- TESTING -- {{{2

if get(g:, 'ale_silence_TESTING')
  function! s:winbufnr(arg) abort
    return get(g:, 'ale_silence_TESTING_winbufnr')
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
endif
