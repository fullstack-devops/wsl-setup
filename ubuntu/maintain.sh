#!/bin/bash

set -e
set -u
set -o pipefail

#################################################################################
# Pre checks
#################################################################################

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ]; then 
    echo "Please set your current user"
    exit 1
fi

if [ ! id "$1" &>/dev/null ]; then
    echo 'not a valid User!'
    exit 1
fi

debug_level=0
if [ ! -z ${2+x} ]; then 
    echo "!Debug enabled!"
    debug_level=1
fi

#################################################################################
# VARIABLES
#################################################################################

standard_user=$1
need_restart=false
PACKAGES="apt-transport-https daemonize dotnet-runtime-5.0 systemd-container ansible python3-pip jq direnv maven net-tools podman"

GENIE_VERSION=1.44
kubectx_version=0.9.4
gh_cli_version=2.8.0
kind_version=0.11.1
golang_version=1.17.6
nvm_version=0.39.1

#################################################################################
# HELPER FUNCTIONS
#################################################################################

log() {
	local type="${1}"     # ok, warn or err
	local message="${2}"  # msg to print
	local debug="${3-0}"    # 0: only warn and error, >0: ok and info

	local clr_ok="\033[0;32m"
	local clr_info="\033[0;36m"
	local clr_warn="\033[0;33m"
	local clr_err="\033[0;31m"
	local clr_rst="\033[0m"

	if [ "${type}" = "trace" ]; then
		if [ "${debug}" -gt "0" ]; then
			printf "${clr_ok}[TRACE]   %s${clr_rst}\n" "${message}"
		fi
	elif [ "${type}" = "info" ]; then
		printf "${clr_info}[INFO] %s${clr_rst}\n" "${message}"
	elif [ "${type}" = "warn" ]; then
		printf "${clr_warn}[WARN] %s${clr_rst}\n" "${message}"
	elif [ "${type}" = "err" ]; then
		printf "${clr_err}[ERR]  %s${clr_rst}\n" "${message}"
	else
		printf "${clr_err}[???]  %s${clr_rst}\n" "${message}"
	fi
}

upgrade() {
    log "info" "Upgrade WSL"
    if ! { apt-get -y upgrade 2>&1 || echo E: update failed; } | grep -e '^[WE]:'; then
        log "info" "Updated successfully"
    else
        log "warn" "not updated successfully"
    fi
}

update() {
    log "info" "update packages"
    if ! { apt-get update 2>&1 || echo E: update failed; } | grep -e '^[WE]:'; then
        log "info" "Updated successfully"
    else
        log "warn" "not updated successfully"
    fi
}

apt-install() {
    local packages="${@}"
    log "info" "installing $packages"
    if ! { apt-get install -y $packages 2>&1 || echo E: update failed; } | grep -e '^[WE]:'; then
        log "info" "Installation of $packages successful"
    else
        log "err" "Installation of $packages not successful"
    fi
}

apt-update-repo() {
    # local packages="${1}"
    log "info" "Update apt-repository: $1"
    if ! { add-apt-repository --yes --update $1 2>&1 || echo dpkg: error; } | grep -e '^[WE]:'; then
        log "info" "Update apt-repository $1 successful"
    else
        log "err" "Update apt-repository $1 not successful"
    fi
}

dpkg-install() {
    # local packages="${@}"
    log "info" "installing $1"
    if ! { dpkg -i $1 2>&1 || echo dpkg: error; } | grep -e '^[WE]:'; then
        log "info" "Installation of packages successful"
    else
        log "err" "Installation of packages not successful"
    fi
}

#################################################################################
# Install Script
#################################################################################

update

upgrade

log "info" "checking if using distrod"
if [ ! -d /run/systemd/system ] && [ ! -d /opt/distrod ]; then
    log "warn" "systemd with distrod not yet installed, perform now setup"
    need_restart=true

    cd /tmp/ && curl -fsSL https://raw.githubusercontent.com/nullpo-head/wsl-distrod/main/install.sh | bash -s install && cd - 

    /opt/distrod/bin/distrod enable
    
    if grep -q "$standard_user ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers; then
        log "info" "user already in sudoers"
    else
        log "info" "add user $standard_user to sudoers"
        echo "$standard_user ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
    fi

else
    log "info" "update systemd with distrod"
    cd /tmp/ && curl -fsSL https://raw.githubusercontent.com/nullpo-head/wsl-distrod/main/install.sh | bash -s update && cd -
    /opt/distrod/bin/distrod enable
    need_restart=true
fi

# Vars needed for podman and ubuntu package
. /etc/os-release

log "info" "Download Windows package for Ubuntu"
curl -fsSL -o /tmp/packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
log "info" "Download github cli package for Ubuntu"
curl -fsSL -o /tmp/gh_${gh_cli_version}_linux_amd64.deb "https://github.com/cli/cli/releases/download/v${gh_cli_version}/gh_${gh_cli_version}_linux_amd64.deb"

log "info" "Update key with podman"
sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x${NAME}_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
curl -fsSLk https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x${NAME}_${VERSION_ID}/Release.key | apt-key add -

## Update ansible repository ppa
apt-update-repo ppa:ansible/ansible

update
dpkg-install /tmp/packages-microsoft-prod.deb
apt-install apt-transport-https

update
apt-install $PACKAGES
dpkg-install /tmp/gh_${gh_cli_version}_linux_amd64.deb

rm /tmp/packages-microsoft-prod.deb
rm /tmp/gh_${gh_cli_version}_linux_amd64.deb

# add registries to file
log "info" "Add harbor to podman registries"
mkdir -p /etc/containers
echo -e "[registries.search]\nregistries = ['docker.io', 'quay.io']" > /etc/containers/registries.conf

# make podman at home
mount --make-rshared /
mount -o remount,rw /sys/fs/cgroup

# disable windows bell on tab end completion
log "info" "Disabling bell-style at input"
sed -i 's/# set bell-style none/set bell-style none/g' /etc/inputrc

# rm old bins
rm -f /usr/local/bin/kubectl
rm -f /usr/local/bin/kubectx
rm -f /usr/local/bin/kubens
rm -f /usr/local/bin/kind

## Installing Kubectl
log "info" "Installing kubectl"
curl -fsSLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
mv kubectl /usr/local/src/kubectl
chmod 711 /usr/local/src/kubectl
ln -s /usr/local/src/kubectl /usr/local/bin/kubectl

## Installing Kubectx
log "info" "Installing kubectx"
curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubectx_v${kubectx_version}_linux_x86_64.tar.gz" | tar -xz -C /usr/local/src
chmod 711 /usr/local/src/kubectx
ln -s /usr/local/src/kubectx /usr/local/bin/kubectx

## Installing Kubens
log "info" "Installing kubens"
curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubens_v${kubectx_version}_linux_x86_64.tar.gz" | tar -xz -C /usr/local/src
chmod 711 /usr/local/src/kubens
ln -s /usr/local/src/kubens /usr/local/bin/kubens

## Installing kind
log "info" "Installing kind"
curl -fsSL https://kind.sigs.k8s.io/dl/v${kind_version}/kind-linux-amd64 > /usr/local/src/kind
chmod 711 /usr/local/src/kind
ln -s /usr/local/src/kind /usr/local/bin/kind

## Installing Helm
log "info" "Installing helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -

## Installing GO
log "info" "Installing golang"
curl -fsSL https://golang.org/dl/go${golang_version}.linux-amd64.tar.gz | tar -xz -C /usr/local

initWorkspace(){
    log "info" "Home directory: $HOME"
    log "info" "Installing nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v${nvm_version}/install.sh | bash -
    
    log "info" "Adding node lts"
    . "$HOME/.nvm/nvm.sh"
    nvm install --lts # Latest stable LTS release (recommended)
    nvm install node # Current release

    ## Aufbauen des Workspaces nach schema F (oder eMST)
    log "info" "create workspace structure"
    mkdir -p ${HOME}/workspace/go
    mkdir -p ${HOME}/workspace/git
    mkdir -p ${HOME}/.kube/configs

cat <<EOF >${HOME}/.wsl-completions
_kube_contexts()
{
  local curr_arg;
  curr_arg=\${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( \$(compgen -W "- \$(kubectl config get-contexts --output='name')" -- \$curr_arg ) );
}
complete -F _kube_contexts kubectx kctx

_kube_namespaces()
{
  local curr_arg;
  curr_arg=\${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( \$(compgen -W "- \$(kubectl get namespaces -o=jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}')" -- \$curr_arg ) );
}
complete -F _kube_namespaces kubens kns


# The various escape codes that we can use to color our prompt.
       BLACK="\[\033[0;30m\]"
 LIGHT_BLACK="\[\033[1;30m\]"
         RED="\[\033[0;31m\]"
   LIGHT_RED="\[\033[1;31m\]"
       GREEN="\[\033[0;32m\]"
 LIGHT_GREEN="\[\033[1;32m\]"
      YELLOW="\[\033[0;33m\]"
LIGHT_YELLOW="\[\033[1;33m\]"
        BLUE="\[\033[0;34m\]"
  LIGHT_BLUE="\[\033[1;34m\]"
      PURPLE="\[\033[0;35m\]"
LIGHT_PURPLE="\[\033[1;35m\]"
        CYAN="\[\033[0;36m\]"
  LIGHT_CYAN="\[\033[1;36m\]"
       WHITE="\[\033[0;37m\]"
 LIGHT_WHITE="\[\033[1;37m\]"
  COLOR_NONE="\[\e[0m\]"

# determine git branch name
function parse_git_branch(){
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# determine mercurial branch name
function parse_hg_branch(){
  hg branch 2> /dev/null | awk '{print " (" \$1 ")"}'
}

# Determine the branch/state information for this git repository.
function set_git_branch() {
  # Get the name of the branch.
  branch=\$(parse_git_branch)
  # if not git then maybe mercurial
  if [ "\$branch" == "" ]
  then
    branch=\$(parse_hg_branch)
  fi

  # Set the final branch string.
  BRANCH="\${LIGHT_GREEN}\${branch}\${COLOR_NONE} "
}

function set_k8s_namespace() {
  kubectl config view --minify -o jsonpath="{.contexts[0].context.namespace}" 2> /dev/null
}

function set_k8s_context() {
  kubectl config current-context 2> /dev/null
}

function set_k8s_prompt () {
  CONTEXT=\$(set_k8s_context)
  NAMESPACE=\$(set_k8s_namespace)

  # context
  if [[ -z "\${CONTEXT:-}" ]]; then
      K8S=""
  else
      # namespace
      if [[ -z "\${NAMESPACE:-}" ]]; then
          K8S="\${LIGHT_BLACK}(\${LIGHT_BLUE}\${CONTEXT}\${LIGHT_BLACK}:\${LIGHT_BLUE}default\${LIGHT_BLACK})\${COLOR_NONE}"
      else
          K8S="\${LIGHT_BLACK}(\${LIGHT_BLUE}\${CONTEXT}\${LIGHT_BLACK}:\${LIGHT_BLUE}\${NAMESPACE}\${LIGHT_BLACK})\${COLOR_NONE}"
      fi
  fi
}

# Return the prompt symbol to use, colorized based on the return value of the
# previous command.
function set_prompt_symbol () {
  if test \$1 -eq 0 ; then
      PROMPT_SYMBOL="\\$"
  else
      PROMPT_SYMBOL="\${LIGHT_RED}\\$\${COLOR_NONE}"
  fi
}

# Determine active Python virtualenv details.
function set_virtualenv () {
  if test -z "\$VIRTUAL_ENV" ; then
      PYTHON_VIRTUALENV=""
  else
      PYTHON_VIRTUALENV="\${BLUE}[`basename \"\$VIRTUAL_ENV\"`]\${COLOR_NONE} "
  fi
}

# Set the full bash prompt.
function set_bash_prompt () {
  # Set the PROMPT_SYMBOL variable. We do this first so we don't lose the
  # return value of the last command.
  set_prompt_symbol \$?

  # Set the PYTHON_VIRTUALENV variable.
  set_virtualenv

  # Set the BRANCH variable.
  set_git_branch

  # set k8s prompt
  set_k8s_prompt

  # Set the bash prompt variable.
  PS1="
\${PYTHON_VIRTUALENV}\${GREEN}\u@\h\${COLOR_NONE}:\${LIGHT_YELLOW}\w\${COLOR_NONE}\${BRANCH}\${K8S}
\${PROMPT_SYMBOL} "
}

# Tell bash to execute this function just before displaying its prompt.
PROMPT_COMMAND=set_bash_prompt
EOF

    log "info" "Create .wsl-distrosrc, this must still be added manually to the .profile! (see Readme.md)"
    ## Erstelle .wsl-distrosrc
cat <<EOF >${HOME}/.wsl-distrosrc
## DO NOT edit this file!
## If functions are missing, please open an issue at https://github.com/fullstack-devops/wsl-setup/issues/new!
## Own commands, etc. can be added to ~/.profile

export KIND_EXPERIMENTAL_PROVIDER="podman"

## nessesary mounting for podman and kind
sudo mount --make-rshared /
sudo mount -o remount,rw /sys/fs/cgroup

# SSH-AGENT
SERVICE='ssh-agent'
WHOAMI=`whoami |awk '{print \$1}'`

if pgrep -u \$WHOAMI \$SERVICE >/dev/null
then
    echo \$SERVICE running.
else
    echo \$SERVICE not running.
    echo starting
    ssh-agent > ~/.ssh/agent_env
fi
. ~/.ssh/agent_env

eval "\$(direnv hook bash)"

set_kube_config() {
    # make ~/.kube/config empty
    echo "" > ~/.kube/config
    local configs=""

    for filename in ~/.kube/configs/*; do
        [ -e "\$filename" ] || continue
        # ... rest of the loop body
        configs="\${filename}:\$configs"
    done

    echo "Merge kube-configs -> \${configs::-1}" > /dev/tty

    KUBECONFIG=\${configs::-1} kubectl config view --raw > ~/.kube/config
}

apply_new_kind_cluster() {
    if [ "\$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
    
    if [ -f ~/.kube/kind-cluster.yml ]; then
        . ~/.bash_aliases
    fi
    # kind delete cluster
    
}

# custom aliase
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias kubemerge='\$(set_kube_config)'

# bash completions
source .wsl-completions

if command -v helm &> /dev/null; then
    source <(helm completion bash)
fi

if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

if command -v kind &> /dev/null; then
    source <(kind completion bash)
fi

if command -v gh &> /dev/null; then
    source <(gh completion bash)
fi

export PATH="/usr/local/go/bin:\$PATH"

EOF

    ## podman fix
    podman info &> /dev/null

    echo ""
    echo ""
    log "info" "List installed tools and their versions"
    log "info" "Version - nodejs"
    echo "$(node -v)"
    log "info" "Version - npm"
    echo "$(npm -v)"
    log "info" "Version - maven"
    echo "$(mvn --version)"
    log "info" "Version - ansible"
    echo "$(ansible --version)"
    log "info" "Version - helm"
    echo "helm: $(helm version)"
    log "info" "Version - kubectl"
    echo "$(kubectl version --client=true)"
    log "info" "Version - kind"
    echo "$(kind version)"
    echo ""
}


log "info" "Installing now tools as user $standard_user"
export -f initWorkspace
export -f log
export nvm_version
su $standard_user -c "bash -c initWorkspace $standard_user"

if [ "$need_restart" = true ] ; then
    log "info" "!! please restart your WSL !!"
fi

unset initWorkspace
unset log
unset nvm_version
exit 0
