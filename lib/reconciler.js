/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * Reconciliation operator
 * Copyright 2023 AMRC
 */

import fs_p from "fs/promises";
import path from "path";

import rx from "rxjs";
import { merge } from "json-merge-patch";

import { Debug, UUIDs } from "@amrc-factoryplus/utilities";

import { Checkout }         from "./checkout.js";
import { Clusters }         from "./clusters.js";
import * as Manifests       from "./manifests.js";
import { flux_helm }        from "./templates.js";
import { SealedSecrets }    from "./secrets.js";
import { Edge }             from "./uuids.js";

import { rxx } from "./rxx.js";

const debug = new Debug();

export class Reconciler {
    constructor (opts) {
        this.fplus = opts.fplus;
        this.cdb = this.fplus.ConfigDB;
        this.log = this.fplus.debug.log.bind(this.fplus.debug, "reconcile");

        rx.config.onUnhandledError = e => this.log("Rx error: %o", e);
    }

    async init () {
        const watch = await this.cdb.watcher();

        const app = Edge.App.Deployments;
        //const global = await cdb.get_config(app, app);
        
        watch.application(app)
            .pipe(
                rx.startWith(undefined),
                rx.mergeMap(() => this.cdb.list_configs(app)),
                rx.mergeMap(list => this.lookup_deployments(list)),
            )
            .subscribe(this.handle_deployments.bind(this));
    }

    lookup_deployments (list) {
        const app = Edge.App.Deployments;

        if (!list) return rx.of([]);

        return rx.from(list).pipe(
            rx.filter(obj => obj != app),
            rx.mergeMap(agent => Promise.all([
                agent,
                this.cdb.get_config(app, agent),
                this.cdb.get_config(UUIDs.App.SparkplugAddress, agent),
            ])),
            rx.map(([u, c, a]) => ({uuid: u, config: c, address: a})),
            rx.toArray());
    }

    async handle_deployments (entries) {
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

        /* Update changed deployments */
        for (const [cluster, entries] of clusters.entries()) {
            await this.handle_cluster(cluster, entries);
        }

        /* Clear clusters with no deployments */
        const all_clusters = await this.cdb.list_configs(Edge.App.Cluster);
        for (const cl of all_clusters) {
            if (clusters.has(cl)) continue;
            await this.handle_cluster(cl, []);
        }
    }

    manifests_for_deployments (deployments) {
        return deployments.flatMap(dep =>
            dep.config.charts.map(chart => {
                const name = dep.address
                    ? `${dep.address.group_id}.${dep.address.node_id}`
                    : dep.uuid;
                return flux_helm({
                    uuid: dep.uuid,
                    chart: chart,
                    repo: "shared-helm-charts",
                    values: {
                        name,
                        uuid: dep.uuid,
                        hostname: dep.config.hostname,
                    },
                });
            }));
    }

    async handle_cluster (uuid, deployments) {
        /* XXX This would be better in Rx, but I'm not sure it's
         * staying. Do these calls serially for now. */
        const repo = await this.cdb.get_config(Edge.App.Cluster, uuid);
        if (!repo) {
            this.log("No repo configuration for %s", uuid);
            return;
        }
        const url = repo.flux;

        this.log("Deploying to %s: %s", repo.name, 
            deployments.map(d => d.uuid).join(", "));
        const manifests = this.manifests_for_deployments(deployments);

        const co = await Checkout.clone({ fplus: this.fplus, url });
        const dir = co.path_for(uuid, "deployment");
        await fs_p.rm(dir, { force: true, recursive: true });
        for (const mani of manifests) {
            const name = mani.metadata.name;
            const file = path.join(dir, `${name}.yaml`);
            await Manifests.write(file, [mani]);
        }
        await co.push("Update deployments");
    }
}
