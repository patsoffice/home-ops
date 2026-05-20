# Reproduces the mise environment (.mise.toml) as a nix-shell.
# Usage:  nix-shell        (from the repo root)
#
# Provides the same CLI tools, the [env] variables, and an auto-created
# Python virtualenv at ./.venv — the equivalent of mise's
#   _.python.venv = { path = ".venv", create = true }
{ pkgs ? import <nixpkgs> { } }:

let
  python = pkgs.python314;
in
pkgs.mkShell {
  name = "home-ops";

  packages = with pkgs; [
    python

    # [tools] from .mise.toml — nixpkgs equivalents
    makejinja # pipx:makejinja
    talhelper # aqua:budimanjojo/talhelper
    cilium-cli # aqua:cilium/cilium-cli
    gh # aqua:cli/cli
    cloudflared # aqua:cloudflare/cloudflared
    cue # aqua:cue-lang/cue
    age # aqua:FiloSottile/age
    fluxcd # aqua:fluxcd/flux2
    sops # aqua:getsops/sops
    go-task # aqua:go-task/task  (binary: task)
    kubernetes-helm # aqua:helm/helm
    helmfile # aqua:helmfile/helmfile
    jq # aqua:jqlang/jq
    kustomize # aqua:kubernetes-sigs/kustomize
    kubectl # aqua:kubernetes/kubectl
    yq-go # aqua:mikefarah/yq  (binary: yq)
    talosctl # aqua:siderolabs/talos
    kubeconform # aqua:yannh/kubeconform
    envsubst # envsubst
    krew # krew
    restic # restic
    trivy # trivy
  ];

  shellHook = ''
    # {{config_root}} == the repo root (where nix-shell is invoked)
    export ROOT_DIR="''${ROOT_DIR:-$PWD}"
    export KUBECONFIG="$ROOT_DIR/kubeconfig"
    export SOPS_AGE_KEY_FILE="$ROOT_DIR/age.key"
    export TALOSCONFIG="$ROOT_DIR/talos/clusterconfig/talosconfig"
    export BOOTSTRAP_DIR="$ROOT_DIR/bootstrap"
    export KUBERNETES_DIR="$ROOT_DIR/kubernetes"
    export SCRIPTS_DIR="$ROOT_DIR/scripts"
    export TALOS_DIR="$ROOT_DIR/talos"

    # Auto-create the venv if missing or stale (e.g. a copy synced from macOS,
    # whose python symlink points at a nonexistent /Users/... path).
    if [ ! -x "$ROOT_DIR/.venv/bin/python" ]; then
      echo "shell.nix: (re)creating Python venv at .venv ..."
      rm -rf "$ROOT_DIR/.venv"
      ${python}/bin/python -m venv "$ROOT_DIR/.venv"
      # flux-local is not packaged in nixpkgs; best-effort pip install.
      # (makejinja is provided by nixpkgs above, no pip needed.)
      "$ROOT_DIR/.venv/bin/pip" install --quiet --upgrade pip \
        && "$ROOT_DIR/.venv/bin/pip" install --quiet flux-local==8.2.0 \
        || echo "shell.nix: warning — 'flux-local' pip install failed (enable programs.nix-ld if you need it)."
    fi
    source "$ROOT_DIR/.venv/bin/activate"
  '';
}
