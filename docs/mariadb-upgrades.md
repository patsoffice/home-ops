# MariaDB major upgrades (Galera)

The two WordPress clusters (`mariadb-wordpress-gds`, `mariadb-wordpress-poc`)
are 3-node Galera clusters run by mariadb-operator. Renovate bumps their
`spec.image` in `kubernetes/apps/database/mariadb-operator/cluster/`. Every
bump across a major or minor version (12.2 → 12.3 → 13.0) needs
`mariadb-upgrade` on every pod.

Since 2026-11-01 this is automatic: both `MariaDB` resources set
`MARIADB_AUTO_UPGRADE=1` (see [Automatic upgrade](#automatic-upgrade)). The
manual steps below are for checking, and for when the automatic path fails.

## Why it bites

- mariadb-operator does not run `mariadb-upgrade` on an image change.
- The image entrypoint does it, but only when `MARIADB_AUTO_UPGRADE` is set.
  Without it, a pod with stale tables logs this on start and carries on:
  `[Entrypoint]: MariaDB upgrade (mariadb-upgrade or creating healthcheck users) required, but skipped due to $MARIADB_AUTO_UPGRADE setting`
- The `mysql.*` system tables are Aria/MyISAM, which Galera does not
  replicate. Upgrading one node fixes only that node.
- Scheduled backups connect to the primary only. A cluster can back up
  fine while the other replicas are stale, and it only shows on failover.
  It has already happened twice: 2026-06-07 (dumps failing with `Column
  count of mysql.proc is wrong`) and 2026-11-01 (13.0.2 binaries,
  12.3.2 tables on all six pods).

## Check

`mariadb_upgrade_info` holds the version the tables were last upgraded to.
It should match the image tag on every pod:

```sh
export KUBECONFIG=$PWD/kubeconfig
for c in gds poc; do for i in 0 1 2; do
  p=mariadb-wordpress-$c-$i
  printf '%s: ' "$p"
  kubectl exec -n database "$p" -c mariadb -- \
    dd if=/var/lib/mysql/mariadb_upgrade_info status=none | tr -d '\0'; echo
done; done
```

Or ask MariaDB itself. Exit 0 means an upgrade is needed, exit 1 means it's
current:

```sh
kubectl exec -n database mariadb-wordpress-gds-0 -c mariadb -- sh -c \
  'mariadb-upgrade -uroot -p"$MARIADB_ROOT_PASSWORD" --check-if-upgrade-is-needed'
```

## Alerts

- **`MariaDBUpgradeSkipped`** (Loki rule, `cluster/lokirule.yaml`): fires on
  the entrypoint's "required, but skipped" line. With auto-upgrade on, that
  line only appears if `MARIADB_AUTO_UPGRADE` has gone missing from a
  `MariaDB`.
- **A failed auto-upgrade** makes the entrypoint exit, so the pod
  crash-loops and the standard `KubePodCrashLooping` / `KubePodNotReady`
  alerts fire. Read the `mariadb` container log, then fall back to the
  manual steps.

## Upgrade (manual)

Run it after the new image has rolled out to all three pods. The root
password comes from the pod's own environment, so it never appears on the
command line or in output.

1. Find the primary. Do the other two pods first:

   ```sh
   sak k8s get mariadb -n database \
     --columns 'NAME=.metadata.name,PRIMARY=.status.currentPrimary'
   ```

2. For each pod, one at a time:

   ```sh
   p=mariadb-wordpress-poc-1
   kubectl exec -n database "$p" -c mariadb -- sh -c \
     'mariadb-upgrade -uroot -p"$MARIADB_ROOT_PASSWORD" --skip-write-binlog; echo "exit=$?"'
   ```

   Expect `Phase 8/8 ... OK` and `exit=0`. Table names like
   `sys.statements_with_errors_or_warnings ... OK` are not errors.

3. Before moving on, check that the node rejoined Galera:

   ```sh
   kubectl exec -n database "$p" -c mariadb -- sh -c \
     'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e \
       "SHOW STATUS LIKE \"wsrep_local_state_comment\"; SHOW STATUS LIKE \"wsrep_cluster_size\";"'
   ```

   Expect `Synced` and `3`.

4. When all six are done, re-run the check above. A schema-only dump from a
   non-primary should also exit 0:

   ```sh
   kubectl exec -n database mariadb-wordpress-gds-2 -c mariadb -- sh -c \
     'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases --no-data --routines --events >/dev/null; echo "exit=$?"'
   ```

## Automatic upgrade

Both `MariaDB` resources set `MARIADB_AUTO_UPGRADE=1` in `spec.env`. On
start, the image entrypoint compares `mariadb_upgrade_info` with the server
version. If the major or minor version is older, it:

1. starts a private temporary server (`--skip-networking --wsrep_on=OFF
   --skip-grant-tables`), so the node is out of the Galera cluster while it
   works;
2. saves the system database to `system_mysql_backup_<old>.sql.zst` in the
   datadir;
3. runs `mariadb-upgrade --upgrade-system-tables`;
4. stops the temporary server and starts normally, rejoining Galera.

Each pod does this on its own start. That covers Galera not replicating
`mysql.*`, because the operator's rolling update restarts every pod after
an image bump. The first start after a bump is slower by however long the
upgrade takes.

The entrypoint also uses this path once to create its healthcheck users
when `.my-healthcheck.cnf` is missing (the first restart after enabling it).

After a bump, run the check above once to confirm all six pods report the
new version.
