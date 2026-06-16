" VimTeX requirements (Vimscript)
filetype plugin indent on
syntax enable

" VimTeX settings
let g:vimtex_view_method = 'zathura'
let g:vimtex_view_general_viewer = 'okular'
let g:vimtex_view_general_options = '--unique file:@pdf\#src:@line@tex'
let g:vimtex_compiler_method = 'latexmk'

" Local leader for VimTeX
let maplocalleader = ","

" Enable VimTeX quickfix (clickable errors)
let g:vimtex_quickfix_mode = 1

let g:vimtex_compiler_latexmk = {
      \ 'options' : [
      \   '-pdf',
      \   '-interaction=nonstopmode',
      \   '-synctex=1',
      \   '-file-line-error',
      \ ],
      \}

