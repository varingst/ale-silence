" if !get(g:, 'ale_loaded')
  " finish
" endif

if get(g:, 'ale_silence_loaded')
  finish
endif

let g:ale_silence_loaded = 1

command!  -nargs=*
        \ -bang
        \ -range
        \ -complete=custom,ale#silence#complete
        \ ALESilence
        \ call ale#silence#(<bang>0,
        \                   <line1>,
        \                   <line2>,
        \                   <f-args>)

command! -nargs=0 ALESilenceShow echo join(ale#silence#List(), "\n")
