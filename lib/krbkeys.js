/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * KrbKeys / Kubernetes interaction
 * Copyright 2023 AMRC
 */

import k8s          from "@kubernetes/client-node";

import { Debug }    from "@amrc-factoryplus/utilities";

import { KRB, FLUX, krb_key }  from "./templates.js";

const debug = new Debug();

export class KrbKeys {
    constructor (opts) {
        this.fplus      = opts.fplus;

        this.log = debug.log.bind(debug, "krbkeys");

        const kc = this.kc = new k8s.KubeConfig();
        kc.loadFromCluster();
        this.namespace = kc.getContextObject(kc.currentContext).namespace;
    }

    async sync_krbkey (spec) {
        this.log("Creating KerberosKey for %s", spec.principal);
        const krb = krb_key({
            ...spec,
            local_namespace: this.namespace,
        });
        this.log("Built KrbKey object: %o", krb);

        const api = this.kc.makeApiClient(k8s.CustomObjectsApi);
        const res = await api.createNamespacedCustomObject(
            KRB.group, KRB.version, this.namespace, KRB.plural, krb);
    }
}
