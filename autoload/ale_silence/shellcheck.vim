function! ale_silence#shellcheck#GetSilenceDirectives() abort
  return {
        \ 'nextline': '# shellcheck disable=%s'
        \}
endfunction
