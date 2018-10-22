function! s:noqa(...)
  return '# flake8: noqa'
endfunction

function! ale_silence#flake8#GetSilenceDirectives() abort
  return {
        \ 'inline': funcref('s:noqa')
        \ 'file':   funcref('s:noqa')
        \}
endfun
