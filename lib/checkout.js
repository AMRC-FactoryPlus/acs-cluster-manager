/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * Git checkout
 * Copyright 2023 AMRC
 */

import fs from "fs";
import fs_p from "fs/promises";
import path from "path";
import util from "util";

import git from "isomorphic-git";
import http from "isomorphic-git/http/node/index.js";

import { Debug, UUIDs } from "@amrc-factoryplus/utilities";

import { Git } from "./uuids.js";
import * as manifests from "./manifests.js";

const debug = new Debug();

function manifest_path (namespace, kind, name) {
    return path.join(
        namespace ?? "_cluster",
        kind, `${name}.json`);
}

export class Checkout {
    constructor (opts) {
        this.fplus = opts.fplus;
        this.url = opts.url;

        this.prefix = path.join(this.fplus.opts.git_checkouts, "wd-");
        this.git_email = this.fplus.opts.git_email;
        this.log = debug.log.bind(debug, "git");
    }

    /* Assume we only attempt our repo */
    async git_auth (url, auth) {
        const bad = auth?.headers?.Authorization
            ?.match(/^Bearer\s+(\S+)$/)?.[1];
        const fp = this.fplus;
        const base = await fp.Discovery.service_url(Git.Service.Git);
        const tok = await fp.Fetch._service_token(base, bad);
        return {
            headers: {
                "Authorization": `Bearer ${tok}`,
            },
        };
    }

    async _setup () {
        this.dir = await fs_p.mkdtemp(this.prefix);
        this.log("Cloning %s into %s", this.url, this.dir);

        const git_auth = this.git_auth.bind(this);
        this.gitopts = {
            fs, http,
            dir:            this.dir,
            onAuth:         git_auth,
            onAuthFailure:  git_auth,
        };
    }

    async _set_config () {
        await git.setConfig({
           ...this.gitopts, 
            path:   "user.name",
            value:  "Edge deployment operator",
        });
        await git.setConfig({
            ...this.gitopts,
            path: "user.email",
            value: this.git_email,
        });
    }

    async clone () {
        await this._setup();
        await git.clone({
            ...this.gitopts,
            url:            this.url,
            singleBranch:   true,
            noTags:         true,
            depth:          1,
        });
        await this._set_config();

        return this;
    }

    static clone (opts) {
        return new Checkout(opts).clone();
    }

    async init () {
        await this._setup();
        await git.init({
            ...this.gitopts,
            defaultBranch:  "main",
        });
        await this._set_config();
        return this;
    }

    static init (opts) {
        return new Checkout(opts).init();
    }

    async commit (message, ...args) {
        if (args.length)
            message = util.format(message, ...args);

        this.log("Committing in %s: %s", this.dir, message);
        await git.add({ ...this.gitopts, filepath: "." });
        /* git.add doesn't remove files deleted from the wd */
        await git.listFiles(this.gitopts)
            .then(files => Promise.all(files.map(f => 
                git.status({ ...this.gitopts, filepath: f })
                    .then(s => s == "*deleted" ? f : null))))
            .then(fs => fs.filter(f => f != null))
            .then(fs => Promise.all(fs.map(f => 
                git.remove({ ...this.gitopts, filepath: f }))));

        const sha = await git.commit({ ...this.gitopts, message });
        this.log("Committed: %s", sha);
    }

    async push (...commit) {
        if (commit.length)
            await this.commit(...commit);

        this.log("Pushing to %s", this.url);
        const res = await git.push({ ...this.gitopts, url: this.url });
        this.log("Pushed: %o", res);
        await this.dispose();
    }

    async dispose () {
        this.log("Removing checkout %s", this.dir);
        await fs_p.rm(this.dir, { force: true, recursive: true });
    }

    async write_file (file, content) {
        const abs = path.join(this.dir, file);
        await fs_p.mkdir(path.dirname(abs), { recursive: true });
        await fs_p.writeFile(abs, content);
        this.log("Written file %s", abs);
    }

    async _handle_enoent (file, cb) {
        const abs = path.join(this.dir, file);
        try {
            return await cb(abs);
        }
        catch (e) {
            if (e.code == "ENOENT")
                return;
            throw e;
        }
    }

    read_file (file) {
        return this._handle_enoent(file, f => fs_p.readFile(f));
    }

    unlink_file (file) {
        return this._handle_enoent(file, f => fs_p.unlink(f) ?? true);
    }

    async write_manifest (manifest) {
        const meta = manifest.metadata;
        const file = manifest_path(meta.namespace, manifest.kind, meta.name);
        const json = JSON.stringify(manifest, null, 4);

        await this.write_file(file, json);
    }

    async read_manifest (namespace, kind, name) {
        const file = manifest_path(namespace, kind, name);
        const content = await this.read_file(file);
        if (content == undefined) return;

        const json = JSON.parse(content);
        const meta = json.metadata;
        if (meta.namespace != namespace || meta.name != name
            || json.kind != kind
        )
            throw `Misplaced manifest ${this.url}/${file}`;

        return json;
    }

    unlink_manifest (namespace, kind, name) {
        return this.unlink_file(manifest_path(namespace, kind, name));
    }

    async list_manifests (namespace, kind) {
        const rel = path.dirname(manifest_path(namespace, kind, "any"));
        const abs = path.join(this.dir, rel);
        const files = await fs_p.readdir(abs);
        return files
            .filter(f => f.endsWith(".json"))
            .map(f => [namespace, kind, f.slice(0, -5)]);
    }
}