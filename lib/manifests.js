/*
 * Factory+ / AMRC Connectivity Stack (ACS) Edge Deployment operator
 * YAML handling
 * Copyright 2023 AMRC
 */

import fs from "fs";
import fs_p from "fs/promises";
import path from "path";
import util from "util";

import yaml from "yaml";

async function _handle_enoent (file, cb) {
    try {
        return await cb(file);
    }
    catch (e) {
        if (e.code == "ENOENT")
            return;
        throw e;
    }
}

function read_file (file) {
    return _handle_enoent(file, f => fs_p.readFile(f, "utf-8"));
}

async function write_file (file, content) {
    const abs = path.join(this.dir, file);
    await fs_p.mkdir(path.dirname(abs), { recursive: true });
    await fs_p.writeFile(abs, content);
}

function unlink_file (file) {
    return _handle_enoent(file, f => fs_p.unlink(f) ?? true);
}

/* Path must be absolute */
export async function read (file) {
    const content = await read_file(file);
    if (content == undefined) return;

    const docs = yaml.parseAllDocuments(content);
    if (docs.some(d => d.errors.length > 0)) {
        const rel = path.relative(this.dir, file);
        throw `Bad YAML in '${rel}' in repo '${this.url}'`;
    }

    return docs.map(d => d.toJS());
}

export async function write (file, docs) {
    const content = docs.map(d => yaml.stringify(d))
        .join("...\n");
    await write_file(file, content);
}
