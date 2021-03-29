export PATH=${PATH}:/usr/local/opt/qt5/bin:/opt/fsl/bin:/opt/ANTs/bin:/opt/mrtrix3/bin:/opt/freesurfer/bin:/usr/local/go/bin
export FSLDIR=/opt/fsl
export FREESURFER_HOME=/opt/freesurfer
export PATH=$PATH:/usr/local/go/bin
[[ -f ${FREESURFER_HOME}/SetUpFreeSurfer.sh ]] && source ${FREESURFER_HOME}/SetUpFreeSurfer.sh

alias ll='ls -l'
alias la='ls -a'
alias llt='ls -ltr'
alias lt='ls -lt'

. ${FSLDIR}/etc/fslconf/fsl.sh
export MECABRC=/usr/local/etc/mecabrc
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/13/bin
