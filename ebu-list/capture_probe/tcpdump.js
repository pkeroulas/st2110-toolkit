/* This script should replace ebu:pi-list:apps/capture_probe/tcpdump.js */

const child_process = require('child_process');
const { StringDecoder } = require('string_decoder');
const _ = require('lodash');
const logger = require('./logger');

const buildTcpdumpInfo = (globalConfig, captureOptions) => {
    const tcpdumpProgram = 'dpdk-capture.sh';
    const tcpdumpFilter = captureOptions.endpoints
        ? `${captureOptions.endpoints.map(endpoint => {
              return endpoint.dstAddr ? 'dst ' + endpoint.dstAddr : '';
          })}`.replace(/,/g, ' or ')
        : '';
    var interfaces = _.get(globalConfig, ['tcpdump', 'interfaces']).split(',');

    if (interfaces.length == 0) {
        logger('live').info('no interface for capure');
        return;
    }
    var pos = 0;
    while (pos < interfaces.length) {
        interfaces.splice(pos, 0, '-i');
        pos += 2;
    }

    const tcpdumpArguments = interfaces.concat( [
        '-w',
        captureOptions.file,
        '-G',
        (captureOptions.durationMs/1000).toString(),
        '-W',
        '1',
        tcpdumpFilter,
    ]);
    console.log(tcpdumpArguments);

    return {
        program: tcpdumpProgram,
        arguments: tcpdumpArguments,
        options: {},
    };
};

const buildSubscriberInfo = (globalConfig, captureOptions) => {
    const binPath = _.get(globalConfig, ['list', 'bin']);

    if (!binPath) {
        throw new Error(
            `Invalid global configuration. list.bin not found: ${JSON.stringify(globalConfig)}`
        );
    }

    const program = `${binPath}/subscribe_to`;

    const interfaceName = _.get(globalConfig, ['tcpdump', 'interface']);

    const addresses = captureOptions.endpoints.map(endpoint => endpoint.dstAddr);
    const groups = addresses.map(a => ["-g", a.toString()]);
    const gargs = groups.reduce((acc, val) => acc.concat(val), []); // TODO: flat() in node.js 11
    console.log("gargs");
    console.dir(gargs);

    const arguments = [
        interfaceName,
        ...gargs
    ];

    return {
        program: program,
        arguments: arguments,
        options: {},
    };
};

// Returns a promise
const runTcpdump = async (globalConfig, captureOptions) => {

    const tcpdump = buildTcpdumpInfo(globalConfig, captureOptions);

    return new Promise((resolve, reject) => {
        logger('live').info(
            `command line: ${tcpdump.program} ${tcpdump.arguments.join(' ')}`
        );

        const tcpdumpProcess = child_process.spawn(
            tcpdump.program,
            tcpdump.arguments,
            tcpdump.options
        );

        const tcpdumpOutput = [];
        const decoder = new StringDecoder('utf8');
        const appendToOutput = data => {
            tcpdumpOutput.push(decoder.write(data));
        };

        tcpdumpProcess.on('error', err => {
            logger('live').error(`error during capture:, ${err}`);
        });

        tcpdumpProcess.stdout.on('data', appendToOutput);
        tcpdumpProcess.stderr.on('data', appendToOutput);

        let timer = null;

        tcpdumpProcess.on('close', code => {
            logger('live').info(`child process exited with code ${code}`);

            const stdout = tcpdumpOutput.join('\n');

            logger('live').info(stdout);

            if (timer) {
                clearTimeout(timer);
            }

            if (killed) {
                logger('live').error('killed');
                resolve(0);
                return;
            }

            if (code == null || code !== 0) {
                const message = `dpdk-capture failed with code: ${code}`;
                logger('live').error(message);
                if (code == 2) { /* retry */
                    resolve(code);
                } else {
                    reject(new Error(message));
                }
                return;
            }

            resolve(0);
        });

        let killed = false;
        const onTimeout = () => {
            killed = true;
            //tcpdumpProcess.kill();
        };

        timer = setTimeout(onTimeout, captureOptions.durationMs * 2);
    });
};

module.exports = {
    runTcpdump,
};
