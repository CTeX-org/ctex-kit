# From latex3
# https://github.com/latex3/latex3/blob/master/support/texlive.profile

# We use relative paths since the environment variables may not be resolved.

selected_scheme     scheme-infraonly
TEXDIR              ../tmp/texlive
TEXMFSYSCONFIG      ../tmp/texlive/texmf-config
TEXMFSYSVAR         ../tmp/texlive/texmf-var
TEXMFLOCAL          ../tmp/texlive/texmf-local
TEXMFHOME           ../texmf
TEXMFCONFIG         ../.texlive/texmf-config
TEXMFVAR            ../.texlive/texmf-var
option_doc          0
option_src          0
tlpdbopt_autobackup 0
