# The Linux dev shell — the counterpart to mise (.mise.toml), which handles
# macOS.
# Usage:  nix-shell        (from the repo root)
#
# Provides the same CLI tools, the same [env] variables, and an auto-created
# Python virtualenv at ./.venv — the equivalent of mise's
#   _.python.venv = { path = ".venv", create = true }
#
# It deliberately does NOT track mise's tool *versions*. Those come from aqua;
# these come from the nixpkgs pin below. Matching them per-tool would mean an
# overlay-with-its-own-hash for every entry, re-done on every Renovate bump,
# to buy patch-level parity on clients where it doesn't matter. The one
# exception is flux-local (see shellHook), pinned to match CI so that a local
# run predicts the PR check.
#
# nixpkgs is pinned in ./nix/nixpkgs.json (tracks nixpkgs-unstable) so the
# dev shell is reproducible and independent of the host's channels/registry.
# Bump the pin with:  task nix:update
{ pkgs ? import (
    let pin = builtins.fromJSON (builtins.readFile ./nix/nixpkgs.json);
    in fetchTarball { inherit (pin) url sha256; }
  ) { }
}:

let
  python = pkgs.python314;

  # topf is not in nixpkgs — install the pinned upstream release binary for
  # each supported system. The version lives in the release URLs below so
  # Renovate can bump it; after a bump, refresh each sha256 with:
  #   nix-prefetch-url --type sha256 <url> | xargs nix-hash --to-base32 --type sha256
  topf =
    let
      sources = {
        x86_64-linux = {
          # renovate: datasource=github-releases depName=postfinance/topf
          url = "https://github.com/postfinance/topf/releases/download/v0.6.2/topf_linux_amd64.tar.gz";
          sha256 = "01944xawyw0ldmiz4420j7kdji3661c3ab5q7pbmym56jxychgbr";
        };
        x86_64-darwin = {
          # renovate: datasource=github-releases depName=postfinance/topf
          url = "https://github.com/postfinance/topf/releases/download/v0.6.2/topf_darwin_amd64.tar.gz";
          sha256 = "1ac8590f9as2lx140j73cw0d3xfn3y1yg2wq5pa593aijh70ndqr";
        };
        aarch64-darwin = {
          # renovate: datasource=github-releases depName=postfinance/topf
          url = "https://github.com/postfinance/topf/releases/download/v0.6.2/topf_darwin_arm64.tar.gz";
          sha256 = "1dzqv6n83d6n42dm06dq60bbyfj9frxmpag359xb727bfqww2qy2";
        };
      };
      system = pkgs.stdenv.hostPlatform.system;
      source = sources.${system} or (throw "topf: unsupported system ${system}");
      version = builtins.head (builtins.match ".*/v([0-9.]+)/.*" source.url);
    in
    pkgs.stdenv.mkDerivation {
      pname = "topf";
      inherit version;
      src = pkgs.fetchurl { inherit (source) url sha256; };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        install -Dm755 topf -t $out/bin
        runHook postInstall
      '';
      meta = with pkgs.lib; {
        description = "Talos orchestrator by PostFinance";
        homepage = "https://github.com/postfinance/topf";
        platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      };
    };

  # deadvalues is not in nixpkgs — install the pinned upstream release binary
  # for each supported system. The version lives in the release URLs below so
  # Renovate can bump it; after a bump, refresh each sha256 with:
  #   nix-prefetch-url --type sha256 <url> | xargs nix-hash --to-base32 --type sha256
  deadvalues =
    let
      sources = {
        x86_64-linux = {
          # renovate: datasource=github-releases depName=guarnz/deadvalues
          url = "https://github.com/guarnz/deadvalues/releases/download/v0.1.9/deadvalues_linux_amd64.tar.gz";
          sha256 = "1q160fixfqpza9s0d29l354s2pbkw08qc07m4qzqpizmsw1xs18m";
        };
        x86_64-darwin = {
          # renovate: datasource=github-releases depName=guarnz/deadvalues
          url = "https://github.com/guarnz/deadvalues/releases/download/v0.1.9/deadvalues_darwin_amd64.tar.gz";
          sha256 = "0l34r3ij507g6cdz5afc4676wavwsixhsgv8wsha278nc0qr3a3a";
        };
        aarch64-darwin = {
          # renovate: datasource=github-releases depName=guarnz/deadvalues
          url = "https://github.com/guarnz/deadvalues/releases/download/v0.1.9/deadvalues_darwin_arm64.tar.gz";
          sha256 = "0mygckqpndx29r78vqjkldi0a6wsd827m1cx3r4vhkmqb0k8mpmj";
        };
      };
      system = pkgs.stdenv.hostPlatform.system;
      source = sources.${system} or (throw "deadvalues: unsupported system ${system}");
      version = builtins.head (builtins.match ".*/v([0-9.]+)/.*" source.url);
    in
    pkgs.stdenv.mkDerivation {
      pname = "deadvalues";
      inherit version;
      src = pkgs.fetchurl { inherit (source) url sha256; };
      sourceRoot = ".";
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        install -Dm755 deadvalues -t $out/bin
        runHook postInstall
      '';
      meta = with pkgs.lib; {
        description = "Helm values dead code detector";
        homepage = "https://github.com/guarnz/deadvalues";
        platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      };
    };
in
pkgs.mkShell {
  name = "home-ops";

  packages = with pkgs; [
    python

    # [tools] from .mise.toml — nixpkgs equivalents
    makejinja # pipx:makejinja
    topf # aqua:postfinance/topf
    talhelper # aqua:budimanjojo/talhelper (retire after the topf cutover)
    cilium-cli # aqua:cilium/cilium-cli
    gh # aqua:cli/cli
    cloudflared # aqua:cloudflare/cloudflared
    cue # aqua:cue-lang/cue
    deadvalues # custom derivation above (not in nixpkgs)
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
      #
      # Keep level with the flux-local image in
      # .github/workflows/flux-local.yaml — a local run only predicts the PR
      # check when the versions match. Renovate bumps both, plus .mise.toml.
      # renovate: datasource=pypi depName=flux-local
      flux_local_version=8.4.0
      "$ROOT_DIR/.venv/bin/pip" install --quiet --upgrade pip \
        && "$ROOT_DIR/.venv/bin/pip" install --quiet "flux-local==$flux_local_version" \
        || echo "shell.nix: warning — 'flux-local' pip install failed (enable programs.nix-ld if you need it)."
    fi
    source "$ROOT_DIR/.venv/bin/activate"
  '';
}
