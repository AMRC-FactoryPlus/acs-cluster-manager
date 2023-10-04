/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * Reconciliation operator
 * Copyright 2023 AMRC
 */

import rx from "rxjs";
import { merge } from "json-merge-patch";

import { Debug, UUIDs } from "@amrc-factoryplus/utilities";

import { Checkout }         from "./checkout.js";
import { Clusters }         from "./clusters.js";
import { flux_helm }        from "./templates.js";
import { SealedSecrets }    from "./secrets.js";
import { Edge }             from "./uuids.js";

import { rxx } from "./rxx.js";

const debug = new Debug();

export class Reconciler {
    constructor (opts) {
        this.fplus = opts.fplus;
        this.log = this.fplus.debug.log.bind(this.fplus.debug, "reconcile");

        rx.config.onUnhandledError = e => this.log("Rx error: %o", e);
    }

    async init () {
        const cdb = this.fplus.ConfigDB;
        const watch = await cdb.watcher();

        const app = Edge.App.Deployments;
        //const global = await cdb.get_config(app, app);
        
        const cdb_lookup = (uuid$, app) =>
            uuid$.pipe(rx.mergeMap(uuid => cdb.get_config(app, uuid)));

        watch.application(app)
            .pipe(
                rx.startWith(undefined),
                /* Currently the ConfigDB watcher doesn't tell us which
                 * object changed, just that there was a change. This is
                 * a limitation of the underlying MQTT interface and
                 * can't easily be changed. So we need to fetch the
                 * whole list again every time. */
                rx.mergeMap(() => cdb.list_configs(app)),
                rx.mergeMap(list => rx.from(list ?? []).pipe(
                    rx.filter(obj => obj != app),
                    rx.connect(agent$ => rx.zip(
                        agent$,
                        cdb_lookup(agent$, app),
                        cdb_lookup(agent$, UUIDs.App.SparkplugAddress),
                        (u, c, a) => ({uuid: u, config: c, address: a})
                    )),
                    rx.toArray()),
                ),
            )
            .subscribe(this.deployment.bind(this));
    }

    async deployment (entries) {
        this.log("Change: %o", entries);

        const clusters = new Map();
        for (const entry of entries) {
            const cl = entry.config.cluster;
            if (!cl) {
                this.log("Deployment %s has no cluster", entry.uuid);
                continue;
            }
            if (!clusters.has(cl)) clusters.set(cl, []);
            clusters.get(cl).push(entry);
        }

        for (const [cluster, entries] of clusters.entries()) {
            const manifests = entries.flatMap(e =>
                e.config.charts.map(chart =>
                    flux_helm({
                        uuid: e.uuid,
                        chart: chart,
                        repo: "shared-helm-charts",
                        values: {
                            name: `${e.address.group_id}.${e.address.node_id}`,
                            uuid: e.uuid,
                            hostname: e.config.hostname,
                        },
                    })));
            this.log("Manifests for %s: %o", cluster, manifests);
        }
    }
}
