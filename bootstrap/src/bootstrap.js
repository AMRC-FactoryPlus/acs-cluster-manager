require('dotenv-defaults').config();

const axios     = require('axios').default;
const os        = require('os');
const fs        = require('fs');
const { Agent } = require('https');

const GSS = require('gssapi.js');

run();

async function run () {
    // Read the kubeseal cert from the file
    console.log('Reading kubeseal cert from file...');
    let kubesealCert = null;
    fs.readFile(`${process.env.KUBESEAL_FILE}`, 'utf8', async (err, data) => {
        // If there is an error reading the file, log it and exit
        if (err) {
            console.log('Error reading kubeseal cert from file');
            console.error(err);
            return;
        }
        // Otherwise, continue the bootstrap
        kubesealCert = data;

        console.log('Kubeseal cert read successfully.', kubesealCert);

        // Holds the UUID of the cluster returned by the API
        let uuid = null;

        // Holds the full URL to the cluster's Flux repo returned by the API
        let flux = null;

        // Create an Axios instance with the https agent set to reject unauthorized certificates if the scheme is https
        const instance = axios.create({
            httpsAgent: new Agent({
                rejectUnauthorized: process.env.SCHEME === 'https'
            })
        });

        // Register the cluster with the API
        console.log('Registering cluster with API...');
        const edge = process.env.EDGE_URL;
        console.log(`Contacting Edge Deployment at ${edge}`);

        // Make the request to the API to register the cluster
        let e = await instance.post(`${edge}/v1/cluster`, {
            name: os.hostname(),
            kubeseal_cert: kubesealCert,
            sources: ['shared/flux-system']
        }, {
            headers: {
                'Authorization': `Negotiate ${await getSingleUseToken(edge)}`
            }
        });

        console.log("Cluster create response: %o", e);

        // Set the UUID and flux URL
        process.uuid = e.data.uuid;
        flux = e.data.flux;

        if (!uuid) {
            throw new Error('UUID not set');
        }

        if (!flux) {
            throw new Error('flux not set');
        }

        // Poll the API to check if the cluster has been registered
        return poll(async () => instance.get(`${edge}/v1/cluster/${uuid}/status`, {
            headers: {
                'Authorization': `Negotiate ${await getSingleUseToken(edge)}`
            }
        }).then(validateResponse));

    });
}

/**
 * Poll the API to check if the cluster has been registered
 * @param fn
 * @returns {Promise<void | unknown>}
 */
function poll (fn) {
    console.log('Waiting for confirmation that cluster has been registered...');

    return Promise.resolve()
                  .then(fn)
                  .catch(function retry () {
                      return sleep(5000).then(fn).catch(retry);
                  });
}

/**
 * Validates the response from the API
 * @param res
 */
function validateResponse (res) {
    // If the response is not 200 or the ready flag is not true then fail
    if (!res.data || res.data.content.status !== 200 || res.data.ready !== true) throw res;
}

/**
 * A helper function to sleep for a given number of milliseconds
 * @param ms
 * @returns {Promise<unknown>}
 */
function sleep (ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function getSingleUseToken (url) {
    const host = new URL(url).hostname;
    const ctx = GSS.createClientContext({ server: `HTTP@${host}` });
    const tok = await GSS.initSecContext(ctx);
    const tok64 = tok.toString('base64');
    console.log(`Got GSSAPI token: ${tok64}`);
    return tok64;
}
