" chezmoi templates: vim maps *.tmpl to the bare "template" filetype (HTML syntax), and setf can't
" override it within the same BufRead, so re-detect from the name without .tmpl once it's loaded.
au BufWinEnter *.tmpl ++nested if &ft ==# 'template' | exe 'doau filetypedetect BufRead ' . fnameescape(expand('<afile>:r')) | endif
