" no error code for filewise disable
function! s:noqa(...)
  return '# flake8: noqa'
endfunction

function! ale_silence#flake8#GetSilenceDirectives() abort
  return {
        \ 'inline': ' # noqa: %s',
        \ 'file':   funcref('s:noqa'),
        \ 'separator': ','
        \}
endfun
