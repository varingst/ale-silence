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

command! -nargs=0
       \ ALESilenceShow
       \ echo join(ale#silence#List(), "\n")

command! -nargs=1
       \ -complete=custom,ale#silence#complete_lookup
       \ ALESilenceLookup
       \ call ale#silence#LookupError(<f-args>)

" TODO: completion for active linters
command! -nargs=1
       \ ALEBrowseDocs
       \ call ale#silence#BrowseDocs(<f-args>)
