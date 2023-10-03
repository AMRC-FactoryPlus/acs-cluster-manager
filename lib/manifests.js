/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * Manifest creation functions
 * Copyright 2023 AMRC
 */

export const README = `
This repo is managed by the Edge Deployment Operator.
As such some conventions need to be observed.

* All manifests must be 1-per-file.
* All manifests must be YAML, but any comments or formatting are likely
    to be removed by the operator.
* Namespaced objects go in \`NAMESPACE/KIND/NAME.yaml\`,
    e.g. \`fplus-edge/Deployment/edge-agent.yaml\`.
* Cluster-wide object go in \`_cluster/KIND/NAME.yaml\`.
`;

const FPLUS = "factoryplus.app.amrc.co.uk";
export const EDO = `edo.${FPLUS}`;

export const LABELS = {
    managed_by: `app.kubernetes.io/managed-by`,
    key_owner:  `${EDO}/key-owner`,
    key_usage:  `${EDO}/key-usage`,
};

/* The namespace here needs to be kept in sync with the flux system as
 * installed by the shared/flux-system repo. */
export const FLUX = {
    ns:         "flux-system",
    secret:     "op1flux-secrets",
    secretkey:  "password",
    keytype:    "Password",
    username:   "op1flux/%s",
    branch:     "main",
};

export const KRB = {
    group:      FPLUS,
    version:    "v1",
    kind:       "KerberosKey",
    plural:     "kerberos-keys",
};

/* Manifest to be teleported via flux should not have LABELS.managed_by
 * as they are not being actively managed on the target cluster. */

export function git_repo (name, url, spec) {
    return {
        apiVersion: "source.toolkit.fluxcd.io/v1",
        kind: "GitRepository",
        metadata: { namespace: FLUX.ns, name },
        spec: {
          interval: spec.interval,
          ref: { branch: spec.branch },
          secretRef: { name: FLUX.secret },
          url,
    }, };
}

export function flux_kust (name, spec) {
    return {
        apiVersion: "kustomize.toolkit.fluxcd.io/v1",
        kind: "Kustomization",
        metadata: { namespace: FLUX.ns, name },
        spec: {
            interval: spec.interval,
            path: "./",
            prune: true,
            sourceRef: {
                kind: "GitRepository",
                name: name,
    }, }, };
}

export function flux_helm (spec) {
    return {
        apiVersion: "helm.toolkit.fluxcd.io/v2beta1",
        kind: "HelmRelease",
        metadata: {
            namespace: FLUX.ns,
            name: `${spec.chart}-${spec.uuid}`,
        },
        spec: {
            chart: {
                spec: {
                    sourceRef: {
                        namespace: FLUX.ns,
                        kind: "GitRepository",
                        name: spec.repo,
                    },
                    chart: "edge-agent",
                    reconcileStrategy: "Revision",
                },
            },
            interval: "3m0s",
            values: spec.values,
        },
    };
}

export function sealed_secret (namespace, name) {
    return {
        apiVersion: "bitnami.com/v1alpha1",
        kind: "SealedSecret",
        metadata: { namespace, name },
        spec: {
            encryptedData: {},
            template: {
                data: null,
                metadata: { namespace, name },
                type: "Opaque",
    }, }, };
}

export function namespace (name) {
    return {
        apiVersion: "v1",
        kind: "Namespace",
        metadata: { name },
    };
}

/* Manifests to be installed locally should use LABELS.managed_by. */

export function krb_key (spec) {
    const kname = `edo.${spec.usage}.${spec.owner}`;
    return {
        apiVersion: `${KRB.group}/${KRB.version}`,
        kind: KRB.kind,
        metadata: {
            namespace: spec.local_namespace,
            name: kname,
            labels: {
                [LABELS.managed_by]:  EDO,
                [LABELS.key_owner]:   spec.owner,
                [LABELS.key_usage]:   spec.usage,
            },
        },
        spec: {
            principal:      spec.principal,
            type:           spec.type,
            secret:         spec.secret,
            cluster: {
                uuid:       spec.cluster,
                namespace:  spec.namespace,
    }, }, };
}

